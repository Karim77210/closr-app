import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/stripe_service.dart';
import 'package:closr_app/services/firestore_service.dart';
import 'package:closr_app/widgets/circle_icon_button.dart';
import 'package:closr_app/widgets/closr_card.dart';
import 'package:closr_app/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletScreen extends StatefulWidget {
  final AppUser creator;
  const WalletScreen({Key? key, required this.creator}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _stripeService = StripeService();
  final _firestoreService = FirestoreService();

  bool _loadingEarnings = true;
  String? _earningsError;
  List<_SubscriberEntry> _allEntries = [];
  bool _showAllSubscribers = false;

  // Real, live balance on the creator's Stripe Connect account — the source
  // of truth for "what the creator has earned" (money lands here immediately
  // on each subscription payment; see createCheckoutSession destination charge).
  int _availableCents = 0;
  int _pendingCents = 0;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _autoPayoutEnabled = false;
  bool _stripeConnectOnboarded = false;

  bool _payoutLoading = false;
  bool _connectLoading = false;

  StreamSubscription<AppUser?>? _userSub;

  @override
  void initState() {
    super.initState();
    _autoPayoutEnabled = widget.creator.autoPayoutEnabled;
    _stripeConnectOnboarded = widget.creator.stripeConnectOnboarded;
    _userSub = _firestoreService.streamUser(widget.creator.uid).listen((user) {
      if (user == null || !mounted) return;
      setState(() {
        _autoPayoutEnabled = user.autoPayoutEnabled;
        _stripeConnectOnboarded = user.stripeConnectOnboarded;
      });
    });
    _loadEarnings();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _loadEarnings() async {
    setState(() { _loadingEarnings = true; _earningsError = null; });
    try {
      final data = await _stripeService.getCreatorEarnings();
      final subs = (data['subscribers'] as List).cast<Map<String, dynamic>>();
      final entries = <_SubscriberEntry>[];
      for (final sub in subs) {
        final invoices = (sub['invoices'] as List).cast<Map<String, dynamic>>();
        if (invoices.isEmpty) continue;
        final user = await _firestoreService.getUser(sub['subscriberUid'] as String);
        for (final inv in invoices) {
          entries.add(_SubscriberEntry(
            subscriberName: user?.displayName ?? '@unknown',
            subscriberUsername: user?.username ?? '',
            amountCents: inv['amountPaid'] as int,
            date: DateTime.parse(inv['date'] as String),
          ));
        }
      }
      entries.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _allEntries = entries;
        _availableCents = data['availableCents'] as int? ?? 0;
        _pendingCents = data['pendingCents'] as int? ?? 0;
        _loadingEarnings = false;
      });
    } catch (e) {
      setState(() { _earningsError = e.toString().replaceFirst('Exception: ', ''); _loadingEarnings = false; });
    }
  }

  List<_SubscriberEntry> get _monthEntries => _allEntries.where((e) =>
      e.date.year == _selectedMonth.year && e.date.month == _selectedMonth.month).toList();

  int get _grossCents => _monthEntries.fold(0, (sum, e) => sum + e.amountCents);
  int get _commissionCents => (_grossCents * 0.15).round();
  int get _netCents => _grossCents - _commissionCents;

  String _fmt(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

  String _monthLabel(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.year}';
  }

  void _prevMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));
  void _nextMonth() {
    final now = DateTime.now();
    if (_selectedMonth.year == now.year && _selectedMonth.month == now.month) return;
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));
  }

  Future<void> _toggleAutoPayout(bool val) async {
    setState(() => _autoPayoutEnabled = val);
    await _firestoreService.updateUser(widget.creator.uid, {
      'autoPayoutEnabled': val,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _handleConnectStripe() async {
    setState(() => _connectLoading = true);
    try {
      final url = await _stripeService.createConnectOnboarding();
      if (url == null) {
        // Already onboarded
        setState(() => _stripeConnectOnboarded = true);
        return;
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _connectLoading = false);
    }
  }

  Future<void> _handleManageStripe() async {
    setState(() => _connectLoading = true);
    try {
      await _stripeService.openStripeDashboard();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _connectLoading = false);
    }
  }

  Future<void> _handleRequestPayout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request Payout'),
        content: const Text('Transfer your available balance to your connected bank account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _payoutLoading = true);
    try {
      final amountCents = await _stripeService.requestPayout();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payout of ${_fmt(amountCents)} initiated!')),
      );
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _payoutLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadEarnings,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // ─── Header: earnings figure + month selector ─────────────
                Text(
                  'Earnings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(102),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _loadingEarnings ? '€ …' : _fmt(_availableCents + _pendingCents),
                  style: theme.textTheme.headlineLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleIconButton(
                      icon: LucideIcons.chevronLeft,
                      size: 36,
                      onTap: _prevMonth,
                    ),
                    Expanded(
                      child: Text(
                        _monthLabel(_selectedMonth),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    CircleIconButton(
                      icon: LucideIcons.chevronRight,
                      size: 36,
                      onTap: _nextMonth,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildEarningsCard(),
                const SizedBox(height: 16),
                _buildSubscriberBreakdown(),
                const SizedBox(height: 16),
                _buildPayoutSettings(),
                const SizedBox(height: 16),
                _buildStripeConnect(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsCard() {
    return ClosrCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loadingEarnings)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_earningsError != null)
            Center(child: Column(children: [
              Text(_earningsError!, style: const TextStyle(color: ClosrColors.rose, fontSize: 13)),
              TextButton(onPressed: _loadEarnings, child: const Text('Retry')),
            ]))
          else ...[
            _earningsRow('Gross earnings', _fmt(_grossCents), isBold: false),
            const SizedBox(height: 8),
            _earningsRow('Commission (-15%)', '-${_fmt(_commissionCents)}', color: ClosrColors.rose),
            const Divider(height: 20),
            _earningsRow('Net balance', _fmt(_netCents), isBold: true, color: ClosrColors.ember),
          ],
        ],
      ),
    );
  }

  Widget _earningsRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriberBreakdown() {
    final entries = _monthEntries;
    if (entries.isEmpty && !_loadingEarnings) {
      return ClosrCard(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text('No payments this month', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        ),
      );
    }
    final visible = _showAllSubscribers ? entries : entries.take(3).toList();
    return ClosrCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Subscriber payments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          ...visible.map((e) => _subscriberTile(e)),
          if (entries.length > 3) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => setState(() => _showAllSubscribers = !_showAllSubscribers),
              child: Text(
                _showAllSubscribers
                    ? 'See less'
                    : '+ See ${entries.length - 3} more',
                style: const TextStyle(color: ClosrColors.ember, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _subscriberTile(_SubscriberEntry e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: ClosrColors.emberSoft,
            child: Text(
              e.subscriberName.isNotEmpty ? e.subscriberName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 12, color: ClosrColors.ink, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.subscriberName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  _formatDate(e.date),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(_fmt(e.amountCents), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _buildPayoutSettings() {
    return ClosrCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payout settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Automatic monthly payout', style: TextStyle(fontSize: 14)),
                  Text('Paid out on the 1st of each month', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
              Switch(value: _autoPayoutEnabled, onChanged: _toggleAutoPayout),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Icon(LucideIcons.landmark, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _stripeConnectOnboarded
                      ? 'Payouts are sent to your bank account (IBAN)'
                      : 'Connect your Stripe account to receive payouts',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: (!_stripeConnectOnboarded || _payoutLoading)
                  ? null
                  : _handleRequestPayout,
              child: _payoutLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      _stripeConnectOnboarded
                          ? 'Request Payout · ${_fmt(_availableCents)}'
                          : 'Connect Stripe first',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStripeConnect() {
    return ClosrCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stripe Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (_stripeConnectOnboarded) ...[
            Row(children: const [
              Icon(LucideIcons.circleCheck, color: ClosrColors.green, size: 20),
              SizedBox(width: 8),
              Text('Account connected', style: TextStyle(color: ClosrColors.green, fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _connectLoading ? null : _handleManageStripe,
                child: const Text('Manage account'),
              ),
            ),
          ]
          else ...[
            Text(
              'Connect your Stripe account to receive payouts directly to your bank.',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _connectLoading ? null : _handleConnectStripe,
                child: _connectLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Connect Stripe Account'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _SubscriberEntry {
  final String subscriberName;
  final String subscriberUsername;
  final int amountCents;
  final DateTime date;

  const _SubscriberEntry({
    required this.subscriberName,
    required this.subscriberUsername,
    required this.amountCents,
    required this.date,
  });
}

// ─── Connect success screen ───────────────────────────────────────────────────

class WalletConnectSuccessScreen extends StatefulWidget {
  const WalletConnectSuccessScreen({Key? key}) : super(key: key);

  @override
  State<WalletConnectSuccessScreen> createState() => _WalletConnectSuccessScreenState();
}

class _WalletConnectSuccessScreenState extends State<WalletConnectSuccessScreen> {
  final _stripeService = StripeService();
  bool _loading = true;
  bool _confirmed = false;
  String? _error;
  String? _resumeUrl;

  @override
  void initState() {
    super.initState();
    _confirmOnboarding();
  }

  // Stripe's redirect back here doesn't flip `stripeConnectOnboarded` on its
  // own — calling createConnectOnboarding again re-checks the account and
  // updates Firestore if it's now fully verified. Without this, the flag
  // only ever updates the next time someone taps "Connect Stripe Account".
  Future<void> _confirmOnboarding() async {
    setState(() { _loading = true; _error = null; });
    try {
      final url = await _stripeService.createConnectOnboarding();
      if (!mounted) return;
      setState(() {
        _confirmed = url == null; // null means Stripe reported fully onboarded
        _resumeUrl = url;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _resumeOnboarding() async {
    if (_resumeUrl == null) { _confirmOnboarding(); return; }
    await launchUrl(Uri.parse(_resumeUrl!), mode: LaunchMode.platformDefault);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: ClosrCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _loading
                    ? const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Confirming your Stripe account…'),
                      ]
                    : _error != null
                        ? [
                            const Icon(LucideIcons.circleAlert, size: 48, color: ClosrColors.rose),
                            const SizedBox(height: 16),
                            Text(_error!, textAlign: TextAlign.center,
                                style: const TextStyle(color: ClosrColors.rose, fontSize: 13)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _confirmOnboarding, child: const Text('Retry')),
                          ]
                        : _confirmed
                            ? [
                                Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(color: ClosrColors.green.withAlpha(30), shape: BoxShape.circle),
                                  child: const Icon(LucideIcons.circleCheck, size: 48, color: ClosrColors.green),
                                ),
                                const SizedBox(height: 24),
                                Text('Stripe account connected!',
                                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 20)),
                                const SizedBox(height: 12),
                                Text(
                                  'You can now request payouts directly to your bank account.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false),
                                    child: const Text('Back to Wallet'),
                                  ),
                                ),
                              ]
                            : [
                                const Icon(LucideIcons.circleAlert, size: 48, color: ClosrColors.rose),
                                const SizedBox(height: 16),
                                const Text(
                                  'Your Stripe setup isn\'t complete yet. Please finish onboarding to start receiving payouts.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(onPressed: _resumeOnboarding, child: const Text('Finish setup')),
                              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
