import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for handling Firebase Authentication operations.
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently signed in user, or null if unauthenticated.
  User? get currentUser => _auth.currentUser;

  /// Ensures the user is authenticated.
  /// If already signed in, returns the current user.
  /// Otherwise, attempts anonymous sign-in.
  Future<User?> ensureAuthenticated() async {
    try {
      if (_auth.currentUser != null) {
        return _auth.currentUser;
      }
      return await signInAnonymously();
    } catch (e) {
      debugPrint('AuthService: Exception in ensureAuthenticated: $e');
      return null;
    }
  }

  /// Signs in anonymously using Firebase Auth.
  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      debugPrint('AuthService: Error signing in anonymously: $e');
      return null;
    }
  }

  /// Signs out the current Firebase user.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('AuthService: Error signing out: $e');
    }
  }
}
