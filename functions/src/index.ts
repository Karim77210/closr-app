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

      const appUrl = process.env.APP_URL || 'http://localhost:3000';
      const session = await stripe.checkout.sessions.create({
        mode: 'subscription',
        customer: stripeCustomerId,
        line_items: [{ price: stripePriceId, quantity: 1 }],
        success_url: `${appUrl}/subscription-success?session_id={CHECKOUT_SESSION_ID}&creator=${creator.username}`,
        cancel_url: `${appUrl}/${creator.username}`,
        metadata: { subscriberUid, creatorUid, type: 'direct_message' },
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

  await subDoc.ref.update({
    status: sub.status,
    currentPeriodEnd: admin.firestore.Timestamp.fromMillis(sub.current_period_end * 1000),
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
