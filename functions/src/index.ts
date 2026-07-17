import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';
import cors from 'cors';

const corsHandler = cors({ origin: true });

admin.initializeApp();

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
});

const db = admin.firestore();

// ─── Create Checkout Session ────────────────────────────────────────────────

export const createCheckoutSession = functions.https.onRequest((req, res) => {
  corsHandler(req, res, async () => {
    if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
    if (req.method !== 'POST') { res.status(405).json({ error: 'Method not allowed' }); return; }

    try {
      // Verify Firebase ID token
      const authHeader = req.headers.authorization ?? '';
      if (!authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Unauthorized' }); return;
      }
      const decoded = await admin.auth().verifyIdToken(authHeader.split('Bearer ')[1]);
      const subscriberUid = decoded.uid;
      const { creatorUid } = req.body as { creatorUid: string };

      if (!creatorUid) { res.status(400).json({ error: 'creatorUid is required' }); return; }
      if (creatorUid === subscriberUid) { res.status(400).json({ error: 'Cannot subscribe to yourself' }); return; }

      // Load creator
      const creatorDoc = await db.collection('users').doc(creatorUid).get();
      if (!creatorDoc.exists) { res.status(404).json({ error: 'Creator not found' }); return; }
      const creator = creatorDoc.data()!;

      if (creator.subscriberLimit > 0 && creator.subscriberCount >= creator.subscriberLimit) {
        res.status(400).json({ error: 'Creator has reached their subscriber limit' }); return;
      }

      // Payments are routed straight to the creator's Stripe Connect account
      // (destination charge) — there's nowhere to send the money otherwise.
      const connectAccountId = creator.stripeConnectAccountId as string | undefined;
      if (!connectAccountId || !creator.stripeConnectOnboarded) {
        res.status(400).json({ error: 'This creator has not finished setting up payments yet' }); return;
      }

      const existing = await db.collection('subscriptions')
        .where('subscriberUid', '==', subscriberUid)
        .where('creatorUid', '==', creatorUid)
        .where('status', '==', 'active')
        .limit(1).get();
      if (!existing.empty) { res.status(400).json({ error: 'Already subscribed' }); return; }

      // Get or create Stripe customer for subscriber
      const subscriberDoc = await db.collection('users').doc(subscriberUid).get();
      const subscriber = subscriberDoc.data()!;
      let stripeCustomerId = subscriber.stripeCustomerId as string | undefined;
      if (!stripeCustomerId) {
        const customer = await stripe.customers.create({
          email: subscriber.email,
          name: subscriber.displayName,
          metadata: { firebaseUid: subscriberUid },
        });
        stripeCustomerId = customer.id;
        await db.collection('users').doc(subscriberUid).update({ stripeCustomerId });
      }

      // Get or create Stripe Price for creator
      let stripePriceId = creator.stripePriceId as string | undefined;
      if (!stripePriceId) {
        const product = await stripe.products.create({
          name: `Chat with ${creator.displayName}`,
          metadata: { creatorUid },
        });
        const price = await stripe.prices.create({
          product: product.id,
          unit_amount: creator.subscriptionPriceCents as number,
          currency: 'eur',
          recurring: { interval: 'month' },
          metadata: { creatorUid },
        });
        stripePriceId = price.id;
        await db.collection('users').doc(creatorUid).update({ stripePriceId });
      }

      // Use the request's origin so any localhost port works in dev
      const appUrl = req.headers.origin || process.env.APP_URL || 'http://localhost:3000';
      const session = await stripe.checkout.sessions.create({
        mode: 'subscription',
        customer: stripeCustomerId,
        line_items: [{ price: stripePriceId, quantity: 1 }],
        success_url: `${appUrl}/#/subscription-success?session_id={CHECKOUT_SESSION_ID}&creator=${creator.username}`,
        cancel_url: `${appUrl}/#/${creator.username}`,
        metadata: { subscriberUid, creatorUid, type: 'direct_message' },
        subscription_data: {
          // Every recurring invoice is split automatically: 85% lands on the
          // creator's Connect balance immediately, 15% stays with the platform.
          application_fee_percent: 15,
          transfer_data: { destination: connectAccountId },
        },
      });

      res.json({ url: session.url });
    } catch (err) {
      console.error('createCheckoutSession error:', err);
      res.status(500).json({ error: String(err) });
    }
  });
});

// ─── Stripe Webhook ─────────────────────────────────────────────────────────

export const stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'] as string;
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!;

  let event: Stripe.Event;
  try {
    // req.rawBody is available in Firebase Cloud Functions
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err);
    res.status(400).send(`Webhook Error: ${err}`);
    return;
  }

  try {
    switch (event.type) {
      case 'checkout.session.completed':
        await handleCheckoutCompleted(event.data.object as Stripe.Checkout.Session);
        break;
      case 'customer.subscription.deleted':
        await handleSubscriptionDeleted(event.data.object as Stripe.Subscription);
        break;
      case 'customer.subscription.updated':
        await handleSubscriptionUpdated(event.data.object as Stripe.Subscription);
        break;
      case 'invoice.payment_failed':
        await handlePaymentFailed(event.data.object as Stripe.Invoice);
        break;
    }
    res.json({ received: true });
  } catch (err) {
    console.error('Error processing webhook event:', err);
    res.status(500).send('Internal error.');
  }
});

// ─── Webhook handlers ────────────────────────────────────────────────────────

async function handleCheckoutCompleted(session: Stripe.Checkout.Session) {
  if (session.mode !== 'subscription' || !session.subscription) return;

  const { subscriberUid, creatorUid, type } = session.metadata ?? {};
  if (!subscriberUid || !creatorUid) return;

  const sub = await stripe.subscriptions.retrieve(session.subscription as string);

  await db.collection('subscriptions').add({
    subscriberUid,
    creatorUid,
    stripeSubscriptionId: sub.id,
    stripeCustomerId: session.customer as string,
    stripePriceId: sub.items.data[0].price.id,
    status: sub.status,
    currentPeriodEnd: admin.firestore.Timestamp.fromMillis(sub.current_period_end * 1000),
    type: type ?? 'direct_message',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.collection('users').doc(creatorUid).update({
    subscriberCount: admin.firestore.FieldValue.increment(1),
  });
}

async function handleSubscriptionDeleted(sub: Stripe.Subscription) {
  const subDoc = await findSubscriptionDoc(sub.id);
  if (!subDoc) return;

  await subDoc.ref.update({
    status: 'canceled',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const creatorUid = subDoc.data().creatorUid as string;
  await db.collection('users').doc(creatorUid).update({
    subscriberCount: admin.firestore.FieldValue.increment(-1),
  });
}

async function handleSubscriptionUpdated(sub: Stripe.Subscription) {
  const subDoc = await findSubscriptionDoc(sub.id);
  if (!subDoc) return;

  // The raw webhook payload's shape depends on the Stripe account's webhook
  // API version, which can drop/relocate fields like current_period_end.
  // Re-fetching with our pinned SDK version guarantees the shape we expect.
  const fresh = await stripe.subscriptions.retrieve(sub.id);

  await subDoc.ref.update({
    status: fresh.status,
    currentPeriodEnd: admin.firestore.Timestamp.fromMillis(fresh.current_period_end * 1000),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function handlePaymentFailed(invoice: Stripe.Invoice) {
  if (!invoice.subscription) return;
  const subDoc = await findSubscriptionDoc(invoice.subscription as string);
  if (!subDoc) return;

  await subDoc.ref.update({
    status: 'past_due',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function findSubscriptionDoc(stripeSubscriptionId: string) {
  const query = await db.collection('subscriptions')
    .where('stripeSubscriptionId', '==', stripeSubscriptionId)
    .limit(1)
    .get();

  return query.empty ? null : query.docs[0];
}

// ─── Creator Earnings ────────────────────────────────────────────────────────

export const getCreatorEarnings = functions.https.onRequest((req, res) => {
  corsHandler(req, res, async () => {
    if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
    if (req.method !== 'GET') { res.status(405).json({ error: 'Method not allowed' }); return; }

    try {
      const authHeader = req.headers.authorization ?? '';
      if (!authHeader.startsWith('Bearer ')) { res.status(401).json({ error: 'Unauthorized' }); return; }
      const decoded = await admin.auth().verifyIdToken(authHeader.split('Bearer ')[1]);
      const creatorUid = decoded.uid;

      const userDoc = await db.collection('users').doc(creatorUid).get();
      const connectAccountId = userDoc.data()?.stripeConnectAccountId as string | undefined;

      // What the creator has actually earned, straight from Stripe: money
      // already settled on their Connect balance (available for payout) plus
      // money still clearing from a recent payment (pending).
      let availableCents = 0;
      let pendingCents = 0;
      if (connectAccountId) {
        const balance = await stripe.balance.retrieve({ stripeAccount: connectAccountId });
        availableCents = balance.available.filter(b => b.currency === 'eur').reduce((s, b) => s + b.amount, 0);
        pendingCents = balance.pending.filter(b => b.currency === 'eur').reduce((s, b) => s + b.amount, 0);
      }

      // Get all subscriptions (active + canceled) for this creator
      const subsSnap = await db.collection('subscriptions')
        .where('creatorUid', '==', creatorUid)
        .get();

      // Fetch Stripe invoices for each subscription in parallel
      const subscriberData = await Promise.all(subsSnap.docs.map(async (doc) => {
        const sub = doc.data();
        let invoices: { amountPaid: number; date: string; status: string }[] = [];
        try {
          const stripeInvoices = await stripe.invoices.list({
            subscription: sub.stripeSubscriptionId,
            limit: 24,
          });
          invoices = stripeInvoices.data
            .filter(inv => inv.status === 'paid' && inv.amount_paid > 0)
            .map(inv => ({
              amountPaid: inv.amount_paid,
              date: new Date(inv.created * 1000).toISOString(),
              status: inv.status ?? 'unknown',
            }));
        } catch (_) { /* skip if subscription not found in Stripe */ }

        return {
          subscriberUid: sub.subscriberUid as string,
          stripeSubscriptionId: sub.stripeSubscriptionId as string,
          subscriptionStatus: sub.status as string,
          invoices,
        };
      }));

      res.json({ subscribers: subscriberData, availableCents, pendingCents });
    } catch (err) {
      console.error('getCreatorEarnings error:', err);
      res.status(500).json({ error: String(err) });
    }
  });
});

// ─── Stripe Connect Onboarding ───────────────────────────────────────────────

export const createConnectOnboarding = functions.https.onRequest((req, res) => {
  corsHandler(req, res, async () => {
    if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
    if (req.method !== 'POST') { res.status(405).json({ error: 'Method not allowed' }); return; }

    try {
      const authHeader = req.headers.authorization ?? '';
      if (!authHeader.startsWith('Bearer ')) { res.status(401).json({ error: 'Unauthorized' }); return; }
      const decoded = await admin.auth().verifyIdToken(authHeader.split('Bearer ')[1]);
      const creatorUid = decoded.uid;

      const userDoc = await db.collection('users').doc(creatorUid).get();
      const user = userDoc.data()!;

      let connectAccountId = user.stripeConnectAccountId as string | undefined;

      // Create Express account if not exists
      if (!connectAccountId) {
        const account = await stripe.accounts.create({
          type: 'express',
          country: 'FR',
          email: user.email as string,
          capabilities: { transfers: { requested: true } },
          metadata: { firebaseUid: creatorUid },
          // Money only leaves for the creator's bank when we explicitly
          // request a payout (button or monthly cron) — never on Stripe's
          // own automatic schedule.
          settings: { payouts: { schedule: { interval: 'manual' } } },
        });
        connectAccountId = account.id;
        await db.collection('users').doc(creatorUid).update({ stripeConnectAccountId: connectAccountId });
      }

      // Check if already fully onboarded
      const account = await stripe.accounts.retrieve(connectAccountId);
      if (account.details_submitted) {
        await db.collection('users').doc(creatorUid).update({ stripeConnectOnboarded: true });
        res.json({ alreadyOnboarded: true });
        return;
      }

      const appUrl = req.headers.origin || process.env.APP_URL || 'http://localhost:3000';
      const accountLink = await stripe.accountLinks.create({
        account: connectAccountId,
        type: 'account_onboarding',
        return_url: `${appUrl}/#/wallet-connect-success`,
        refresh_url: `${appUrl}/#/wallet`,
      });

      res.json({ url: accountLink.url });
    } catch (err) {
      console.error('createConnectOnboarding error:', err);
      res.status(500).json({ error: String(err) });
    }
  });
});

// ─── Stripe Express Dashboard Link ───────────────────────────────────────────

export const createStripeLoginLink = functions.https.onRequest((req, res) => {
  corsHandler(req, res, async () => {
    if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
    if (req.method !== 'POST') { res.status(405).json({ error: 'Method not allowed' }); return; }

    try {
      const authHeader = req.headers.authorization ?? '';
      if (!authHeader.startsWith('Bearer ')) { res.status(401).json({ error: 'Unauthorized' }); return; }
      const decoded = await admin.auth().verifyIdToken(authHeader.split('Bearer ')[1]);
      const userDoc = await db.collection('users').doc(decoded.uid).get();
      const connectAccountId = userDoc.data()?.stripeConnectAccountId as string | undefined;
      if (!connectAccountId) { res.status(400).json({ error: 'No Connect account found' }); return; }

      const loginLink = await stripe.accounts.createLoginLink(connectAccountId);
      res.json({ url: loginLink.url });
    } catch (err) {
      console.error('createStripeLoginLink error:', err);
      res.status(500).json({ error: String(err) });
    }
  });
});

// ─── Payout helpers ──────────────────────────────────────────────────────────

// The creator's real, current balance on Stripe — the single source of
// truth. Payments arrive here immediately via destination charges, so this
// number IS what the creator has earned, not a computed estimate.
async function getConnectAccountAvailableCents(connectAccountId: string): Promise<number> {
  const balance = await stripe.balance.retrieve({ stripeAccount: connectAccountId });
  return balance.available.filter(b => b.currency === 'eur').reduce((sum, b) => sum + b.amount, 0);
}

async function executePayout(
  creatorUid: string,
  connectAccountId: string,
  amountCents: number,
  trigger: 'manual' | 'auto',
): Promise<string> {
  const requestRef = await db.collection('payout_requests').add({
    creatorUid,
    amount: amountCents,
    status: 'pending',
    trigger,
    requestedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Sends money from the creator's Connect balance straight to the bank
  // account (IBAN) they registered during onboarding.
  const payout = await stripe.payouts.create(
    {
      amount: amountCents,
      currency: 'eur',
      metadata: { creatorUid, payoutRequestId: requestRef.id, trigger },
    },
    { stripeAccount: connectAccountId },
  );

  await requestRef.update({
    status: 'paid',
    stripePayoutId: payout.id,
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return payout.id;
}

// ─── Request Payout ──────────────────────────────────────────────────────────

export const requestPayout = functions.https.onRequest((req, res) => {
  corsHandler(req, res, async () => {
    if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
    if (req.method !== 'POST') { res.status(405).json({ error: 'Method not allowed' }); return; }

    try {
      const authHeader = req.headers.authorization ?? '';
      if (!authHeader.startsWith('Bearer ')) { res.status(401).json({ error: 'Unauthorized' }); return; }
      const decoded = await admin.auth().verifyIdToken(authHeader.split('Bearer ')[1]);
      const creatorUid = decoded.uid;

      const userDoc = await db.collection('users').doc(creatorUid).get();
      const user = userDoc.data()!;
      const connectAccountId = user.stripeConnectAccountId as string | undefined;

      if (!connectAccountId || !user.stripeConnectOnboarded) {
        res.status(400).json({ error: 'Stripe Connect account not configured' }); return;
      }

      const available = await getConnectAccountAvailableCents(connectAccountId);
      if (available <= 0) {
        res.status(400).json({ error: 'No balance available to pay out' }); return;
      }

      const payoutId = await executePayout(creatorUid, connectAccountId, available, 'manual');
      res.json({ success: true, payoutId, amountCents: available });
    } catch (err) {
      console.error('requestPayout error:', err);
      res.status(500).json({ error: String(err) });
    }
  });
});

// ─── Monthly Auto Payout (runs on the 1st of each month at 09:00 Paris time) ─

export const monthlyAutoPayout = functions.pubsub
  .schedule('0 9 1 * *')
  .timeZone('Europe/Paris')
  .onRun(async () => {
    const creatorsSnap = await db.collection('users')
      .where('autoPayoutEnabled', '==', true)
      .where('stripeConnectOnboarded', '==', true)
      .get();

    if (creatorsSnap.empty) {
      console.log('monthlyAutoPayout: no eligible creators');
      return;
    }

    const results = await Promise.allSettled(creatorsSnap.docs.map(async (doc) => {
      const creatorUid = doc.id;
      const connectAccountId = doc.data().stripeConnectAccountId as string;

      const available = await getConnectAccountAvailableCents(connectAccountId);
      if (available < 100) {
        console.log(`monthlyAutoPayout: skipping ${creatorUid} — available ${available}¢ below minimum`);
        return;
      }

      const payoutId = await executePayout(creatorUid, connectAccountId, available, 'auto');
      console.log(`monthlyAutoPayout: paid out ${available}¢ to ${creatorUid} (${payoutId})`);
    }));

    const failed = results.filter(r => r.status === 'rejected');
    if (failed.length > 0) {
      failed.forEach(r => console.error('monthlyAutoPayout error:', (r as PromiseRejectedResult).reason));
    }
  });
