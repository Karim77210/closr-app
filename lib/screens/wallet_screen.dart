import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/stripe_service.dart';
import 'package:closr_app/services/firestore_service.dart';
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

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _autoPayoutEnabled = false;
  bool _stripeConnectOnboarded = false;
  String? _stripeConnectAccountId;

  bool _payoutLoading = false;
  bool _connectLoading = false;

  @override
  void initState() {
    super.initState();
    _autoPayoutEnabled = widget.creator.autoPayoutEnabled;
    _stripeConnectOnboarded = widget.creator.stripeConnectOnboarded;
    _stripeConnectAccountId = widget.creator.stripeConnectAccountId;
    _loadEarnings();
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
      setState(() { _allEntries = entries; _loadingEarnings = false; });
    } catch (e) {
      setState(() { _earningsError = e.toString().replaceFirst('Exception: ', ''); _loadingEarnings = false; });
    }
  }

  List<_SubscriberEntry> get _monthEntries => _allEntries.where((e) =>
      e.date.year == _selectedMonth.year && e.date.month == _selectedMonth.month).toList();

  int get _grossCents => _monthEntries.fold(0, (sum, e) => sum + e.amountCents);
  int get _commissionCents => (_grossCents * 0.15).round();
  int get _netCents => _grossCents - _commissionCents;
  int get _totalNetAllTime => (_allEntries.fold(0, (s, e) => s + e.amountCents) * 0.85).round();

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

  Future<void> _handleChangeStripeAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Stripe account'),
        content: const Text('This will disconnect your current account and start a new Stripe onboarding. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
    if (confirmed != true) return;

    // Reset Connect fields in Firestore
    await _firestoreService.updateUser(widget.creator.uid, {
      'stripeConnectAccountId': null,
      'stripeConnectOnboarded': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    setState(() {
      _stripeConnectOnboarded = false;
      _stripeConnectAccountId = null;
    });
    await _handleConnectStripe();
  }

  Future<void> _handleRequestPayout() async {
    if (_totalNetAllTime <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No balance available to pay out')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request Payout'),
        content: Text('Transfer ${_fmt(_totalNetAllTime)} to your connected bank account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _payoutLoading = true);
    try {
      await _stripeService.requestPayout(_totalNetAllTime);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payout of ${_fmt(_totalNetAllTime)} initiated!')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadEarnings,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
    );
  }

  Widget _buildEarningsCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _prevMonth,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              Text(
                _monthLabel(_selectedMonth),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right,
                    color: _selectedMonth.month == DateTime.now().month && _selectedMonth.year == DateTime.now().year
                        ? Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(90)
                        : null),
                onPressed: _nextMonth,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const Divider(height: 20),
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
      return _Card(
        child: Center(
          child: Text('No payments this month', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        ),
      );
    }
    final visible = _showAllSubscribers ? entries : entries.take(3).toList();
    return _Card(
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
    final iban = widget.creator.iban;
    final maskedIban = iban.isNotEmpty && iban.length > 8
        ? '${iban.substring(0, 4)} •••• ${iban.substring(iban.length - 4)}'
        : iban.isNotEmpty ? iban : 'No IBAN registered';

    return _Card(
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
              Icon(Icons.account_balance_outlined, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(maskedIban, style: const TextStyle(fontSize: 13))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: (!_stripeConnectOnboarded || _payoutLoading)
                  ? null
                  : _handleRequestPayout,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: _stripeConnectOnboarded
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.outline,
                  width: 1.5,
                ),
              ),
              child: _payoutLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      _stripeConnectOnboarded
                          ? 'Request Payout · ${_fmt(_totalNetAllTime)}'
                          : 'Connect Stripe first',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _stripeConnectOnboarded
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStripeConnect() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stripe Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (_stripeConnectOnboarded) ...[
            Row(children: const [
              Icon(Icons.check_circle, color: ClosrColors.green, size: 20),
              SizedBox(width: 8),
              Text('Account connected', style: TextStyle(color: ClosrColors.green, fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _connectLoading ? null : _handleManageStripe,
                  child: const Text('Manage account'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _connectLoading ? null : _handleChangeStripeAccount,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1.5),
                    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  child: Text('Change account', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              ),
            ]),
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
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _connectLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ClosrColors.paper))
                    : const Text('Connect Stripe Account', style: TextStyle(color: ClosrColors.paper, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Reusable card ────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: ClosrColors.ink.withAlpha(12), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: child,
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

class WalletConnectSuccessScreen extends StatelessWidget {
  const WalletConnectSuccessScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: ClosrColors.green.withAlpha(30), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline, size: 48, color: ClosrColors.green),
              ),
              const SizedBox(height: 24),
              const Text('Stripe account connected!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'You can now request payouts directly to your bank account.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 15),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Back to Wallet', style: TextStyle(color: ClosrColors.paper, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
