import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  User? user;
  bool isLoading = false;
  String? avatarUrl;

  // Contact info
  String? secondaryEmail;
  List<String> phones = [];
  Map<String, String> socialMedia = {};
  String? about;

  AuthProvider() {
    user = _auth.currentUser;
    _auth.authStateChanges().listen((event) async {
      user = event;
      if (user != null) {
        await _loadAvatarFromFirestore();
        await loadContactsFromFirestore();
      }
      notifyListeners();
    });
  }

  String? get displayName => user?.displayName;
  String? get email => user?.email;
  String? get photoURL => avatarUrl ?? user?.photoURL;

  // --- Contacts management ---
  Future<void> loadContactsFromFirestore() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (doc.exists) {
      final data = doc.data();
      secondaryEmail = data?['secondaryEmail'];
      phones = List<String>.from(data?['phones'] ?? []);
      socialMedia = Map<String, String>.from(data?['socialMedia'] ?? {});
      about = data?['about'];
    }
    notifyListeners();
  }

  Future<void> setSecondaryEmail(String email) async {
    secondaryEmail = email;
    await _saveContactsToFirestore();
    notifyListeners();
  }

  Future<void> addPhone(String phone) async {
    if (!phones.contains(phone)) {
      phones.add(phone);
      await _saveContactsToFirestore();
      notifyListeners();
    }
  }

  Future<void> updatePhone(int index, String phone) async {
    if (index >= 0 && index < phones.length) {
      phones[index] = phone;
      await _saveContactsToFirestore();
      notifyListeners();
    }
  }

  Future<void> removePhone(int index) async {
    if (index >= 0 && index < phones.length) {
      phones.removeAt(index);
      await _saveContactsToFirestore();
      notifyListeners();
    }
  }

  Future<void> setSocialMedia(String type, String url) async {
    socialMedia[type] = url;
    await _saveContactsToFirestore();
    notifyListeners();
  }

  Future<void> removeSocialMedia(String type) async {
    socialMedia.remove(type);
    await _saveContactsToFirestore();
    notifyListeners();
  }

  Future<void> setAbout(String text) async {
    about = text;
    await _saveContactsToFirestore();
    notifyListeners();
  }

  Future<void> setPhones(List<String> newPhones) async {
    phones = newPhones;
    await _saveContactsToFirestore();
    notifyListeners();
  }

  Future<void> _saveContactsToFirestore() async {
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'secondaryEmail': secondaryEmail,
      'phones': phones,
      'socialMedia': socialMedia,
      'about': about,
    }, SetOptions(merge: true));
  }

  void _clearContacts() {
    secondaryEmail = null;
    phones = [];
    socialMedia = {};
    about = null;
  }

  // --- Authentication ---
  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _loadAvatarFromFirestore();
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint("Error: ${e.message}");
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signUpWithEmail(String email, String password, String name) async {
    _setLoading(true);
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        _setLoading(false);
        return false;
      }

      await firebaseUser.updateDisplayName(name);
      await firebaseUser.reload();
      user =firebaseUser;
      user = _auth.currentUser;

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'avatarUrl': null,
        'secondaryEmail': null,
        'phones': [],
        'socialMedia': {},
        'about': null,
      }, SetOptions(merge: true));

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Register Error: $e");
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      debugPrint("Password Reset Error: $e");
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      await _googleSignIn.initialize(
        serverClientId: '935421872654-kjp95hn8tvqu0rt1gedrc3773f6rqq63.apps.googleusercontent.com',
      );

      GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) {
        _setLoading(false);
        return false; // user canceled
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      user = userCredential.user;
      await _loadAvatarFromFirestore();
      await loadContactsFromFirestore();

      _setLoading(false);
      notifyListeners();
      return user != null;
    } catch (e) {
      debugPrint("Google Sign-in error: $e");
    }
    _setLoading(false);
    notifyListeners();
    return false;
  }

  bool get isEmailVerified => user?.emailVerified ?? false;

  Future<bool> sendEmailVerification() async {
    if (user != null && !user!.emailVerified) {
      try {
        await user!.sendEmailVerification();
        return true;
      } catch (e) {
        debugPrint("Email verification error: $e");
        return false;
      }
    }
    return false;
  }

  Future<void> reloadUser() async {
    if (user != null) {
      await user!.reload();
      user = _auth.currentUser;
      await _loadAvatarFromFirestore();
      notifyListeners();
    }
  }

  // --- Avatar handling ---
  Future<String?> uploadAvatar(XFile file, String userId) async {
    try {
      final supabaseServiceClient = supabase.SupabaseClient(
        'https://cccljhxlvmizkugxgoxi.supabase.co',
        'YOUR_SUPABASE_SERVICE_ROLE_KEY',
      );

      final path = 'avatars/$userId.jpg';

      await supabaseServiceClient.storage
          .from('user-avatars')
          .upload(path, File(file.path), fileOptions: supabase.FileOptions(upsert: true));

      final publicUrl = supabaseServiceClient.storage.from('user-avatars').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      return null;
    }
  }

  Future<bool> setAvatar(XFile file) async {
    if (user == null) return false;

    final url = await uploadAvatar(file, user!.uid);
    if (url != null) {
      try {
        await user!.updatePhotoURL(url);
        await user!.reload();
        user = _auth.currentUser;
        avatarUrl = url;

        await FirebaseFirestore.instance.collection('users').doc(user!.uid).set(
          {'avatarUrl': url}, SetOptions(merge: true),
        );

        notifyListeners();
        return true;
      } catch (e) {
        debugPrint('Failed to set photoURL: $e');
      }
    }
    return false;
  }

  Future<void> _loadAvatarFromFirestore() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (doc.exists) {
      avatarUrl = doc.data()?['avatarUrl'];
    }
  }

  bool isVerified() => user != null && user!.emailVerified;

  Future<void> signOut() async {
    _clearContacts();
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
    await _auth.signOut();
    notifyListeners();
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
