import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  User? user;
  bool isLoading = false;

  AuthProvider() {
    user = _auth.currentUser;
    _auth.authStateChanges().listen((event) {
      user = event;
      notifyListeners();
    });
  }
  String? get displayName => user?.displayName;
  String? get email => user?.email;
  String? get photoURL => user?.photoURL;

  // Returns true if login successful
  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _setLoading(false);
      return true; // Success
    } on FirebaseAuthException catch (e) {
      debugPrint("Error: ${e.message}");
      _setLoading(false);
      return false; // Failed
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      // Initialize once (optional, but safer)
      await _googleSignIn.initialize(
        serverClientId: '935421872654-kjp95hn8tvqu0rt1gedrc3773f6rqq63.apps.googleusercontent.com',
      );

      // Try lightweight auto sign-in (cached)
      GoogleSignInAccount? googleUser = await _googleSignIn.attemptLightweightAuthentication();

      // Ask user to sign in interactively
      if (googleUser == null) {
        googleUser = await _googleSignIn.authenticate();
      }

      if (googleUser == null) {
        _setLoading(false);
        return false; // Canceled by user
      }

      // Get OAuth tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      // Firebase credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );



      // Sign in to Firebase
    final userCredential = await _auth.signInWithCredential(credential);
    _setLoading(false);
    return userCredential.user != null;

    } catch (e) {
      debugPrint("Google Sign-in error: $e");
    }
    _setLoading(false);
    return false;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect(); // <-- disconnect Google session
    } catch (_) {}
    await _auth.signOut(); // <-- sign out Firebase session
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
