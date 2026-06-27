import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class StripeService {
  static const _functionUrl =
      'https://us-central1-closr-ca31d.cloudfunctions.net/createCheckoutSession';

  Future<void> startCheckout(String creatorUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final token = await user.getIdToken();

    final response = await http.post(
      Uri.parse(_functionUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'creatorUid': creatorUid}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(body['error'] ?? 'Checkout failed');
    }

    final url = body['url'] as String;
    await _redirect(url);
  }

  Future<void> _redirect(String url) async {
    final uri = Uri.parse(url);
    final mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
    if (!await launchUrl(uri, mode: mode)) {
      throw Exception('Could not open checkout page.');
    }
  }
}
