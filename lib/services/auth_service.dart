import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:closr_app/models/user_model.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '872864001929-ohste7jvkcre50o2ib0bodisa7fdaj6j.apps.googleusercontent.com',
  );
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  /// Get current user stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => _firebaseAuth.currentUser != null;

  /// Sign up with email and password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String displayName = '',
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (displayName.isNotEmpty) {
        await userCredential.user?.updateDisplayName(displayName);
        await userCredential.user?.reload();
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        return await _firebaseAuth.signInWithPopup(provider);
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _firebaseAuth.signInWithCredential(credential);
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }

  /// Check if user is new (first time login)
  Future<bool> isNewUser(String uid) async {
    try {
      final userData = await _firestoreService.getUser(uid);
      return userData == null;
    } catch (e) {
      return true; // Assume new user if error
    }
  }

  /// Create user profile in Firestore
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String displayName,
    required UserRole role,
    String? username,
    String? bio,
    int? subscriptionPriceCents,
    int? subscriberLimit,
    String? iban,
    int? messageCharacterLimit,
    int? messageCooldownSeconds,
    int? maxMessagesPerDay,
    XFile? photoFile,
    String? photoUrl,
  }) async {
    final effectiveUsername = username?.trim().isNotEmpty == true
        ? username!.trim().toLowerCase()
        : await _generateUsername(displayName, email, uid);

    if (await _firestoreService.usernameExists(effectiveUsername)) {
      throw Exception('This username is already taken. Please choose another one.');
    }

    String? finalPhotoUrl = photoUrl;
    if (photoFile != null) {
      finalPhotoUrl = await _storageService.uploadProfileImage(uid, photoFile);
    }

    final user = AppUser(
      uid: uid,
      email: email,
      displayName: displayName,
      role: role,
      photoUrl: finalPhotoUrl,
      username: effectiveUsername,
      bio: bio ?? (role == UserRole.creator ? 'Create your first public page bio.' : ''),
      subscriptionPriceCents: subscriptionPriceCents ?? 0,
      subscriberLimit: subscriberLimit ?? 0,
      subscriberCount: 0,
      iban: iban ?? '',
      messageCharacterLimit: messageCharacterLimit ?? 300,
      messageCooldownSeconds: messageCooldownSeconds ?? 20,
      maxMessagesPerDay: maxMessagesPerDay ?? 10,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestoreService.createUser(user);
  }

  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? username,
    String? bio,
    int? subscriptionPriceCents,
    int? subscriberLimit,
    String? iban,
    int? messageCharacterLimit,
    int? messageCooldownSeconds,
    int? maxMessagesPerDay,
    XFile? photoFile,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': DateTime.now(),
    };

    if (displayName != null) updateData['displayName'] = displayName;
    if (bio != null) updateData['bio'] = bio;
    if (subscriptionPriceCents != null) updateData['subscriptionPriceCents'] = subscriptionPriceCents;
    if (subscriberLimit != null) updateData['subscriberLimit'] = subscriberLimit;
    if (iban != null) updateData['iban'] = iban;
    if (messageCharacterLimit != null) updateData['messageCharacterLimit'] = messageCharacterLimit;
    if (messageCooldownSeconds != null) updateData['messageCooldownSeconds'] = messageCooldownSeconds;
    if (maxMessagesPerDay != null) updateData['maxMessagesPerDay'] = maxMessagesPerDay;

    if (username != null && username.trim().isNotEmpty) {
      final normalizedUsername = username.trim().toLowerCase();
      if (await _firestoreService.usernameExists(normalizedUsername, excludeUid: uid)) {
        throw Exception('This username is already taken. Please choose another one.');
      }
      updateData['username'] = normalizedUsername;
    }

    if (photoFile != null) {
      final newPhotoUrl = await _storageService.uploadProfileImage(uid, photoFile);
      updateData['photoUrl'] = newPhotoUrl;
    }

    if (updateData.length > 1) {
      await _firestoreService.updateUser(uid, updateData);
    }
  }

  Future<String> _generateUsername(String displayName, String email, String uid) async {
    final sanitizedDisplayName = displayName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    final localPart = email.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final baseUsername = sanitizedDisplayName.isNotEmpty
        ? sanitizedDisplayName.length <= 20
            ? sanitizedDisplayName
            : sanitizedDisplayName.substring(0, 20)
        : localPart.isNotEmpty
            ? localPart
            : 'creator-${uid.substring(0, 6)}';

    var username = baseUsername;
    var suffix = 1;
    while (await _firestoreService.usernameExists(username)) {
      username = '$baseUsername$suffix';
      suffix += 1;
      if (suffix > 100) {
        break;
      }
    }

    return username;
  }

  /// Get user profile from Firestore
  Future<AppUser?> getUserProfile(String uid) async {
    return await _firestoreService.getUser(uid);
  }

  /// Update user role
  Future<void> updateUserRole({
    required String uid,
    required UserRole role,
  }) async {
    await _firestoreService.updateUser(
      uid,
      {'role': role.toString().split('.').last},
    );
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Firebase first (most important)
      await _firebaseAuth.signOut();
      
      // Try to sign out from Google (may fail, it's optional)
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        // Google sign-out is optional - Firebase sign-out is what matters
        print('Warning: Google sign-out skipped: $e');
      }
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  /// Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}
