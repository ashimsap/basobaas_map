import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? user;
  bool isLoading = false;

  AuthProvider() {
    user = _auth.currentUser;
    _auth.authStateChanges().listen((event) {
      user = event;
      notifyListeners();
    });
  }

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

  /* Uncomment if you want Google login
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _setLoading(false);
        return; // Canceled
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Google Sign-in error: $e");
    }
    _setLoading(false);
  }
  */

  Future<void> signOut() async {
    await _auth.signOut();
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
