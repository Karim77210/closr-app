import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class StripeService {
  static const _base = 'https://us-central1-closr-ca31d.cloudfunctions.net';

  Future<String> _authToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return await user.getIdToken() ?? '';
  }

  Future<void> startCheckout(String creatorUid) async {
    final token = await _authToken();
    final response = await http.post(
      Uri.parse('$_base/createCheckoutSession'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'creatorUid': creatorUid}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) throw Exception(body['error'] ?? 'Checkout failed');
    await _redirect(body['url'] as String);
  }

  /// Fetch all invoice history for the creator (filters applied client-side)
  Future<Map<String, dynamic>> getCreatorEarnings() async {
    final token = await _authToken();
    final response = await http.get(
      Uri.parse('$_base/getCreatorEarnings'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) throw Exception(body['error'] ?? 'Failed to load earnings');
    return body;
  }

  /// Start Stripe Connect onboarding. Returns the URL or null if already onboarded.
  Future<String?> createConnectOnboarding() async {
    final token = await _authToken();
    final response = await http.post(
      Uri.parse('$_base/createConnectOnboarding'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) throw Exception(body['error'] ?? 'Connect onboarding failed');
    if (body['alreadyOnboarded'] == true) return null;
    return body['url'] as String;
  }

  /// Request a payout from the creator's Stripe Connect balance to their bank
  /// account (IBAN). Returns the amount actually paid out in cents.
  Future<int> requestPayout() async {
    final token = await _authToken();
    final response = await http.post(
      Uri.parse('$_base/requestPayout'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) throw Exception(body['error'] ?? 'Payout failed');
    return body['amountCents'] as int;
  }

  /// Open the Stripe Express dashboard for the connected account.
  Future<void> openStripeDashboard() async {
    final token = await _authToken();
    final response = await http.post(
      Uri.parse('$_base/createStripeLoginLink'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) throw Exception(body['error'] ?? 'Failed to open dashboard');
    await _redirect(body['url'] as String);
  }

  Future<void> _redirect(String url) async {
    final uri = Uri.parse(url);
    final mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
    if (!await launchUrl(uri, mode: mode)) throw Exception('Could not open page.');
  }
}
