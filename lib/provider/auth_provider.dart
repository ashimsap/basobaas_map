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
  String? avatarUrl; // persistent avatar URL

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

  // load User contact info

  // inside AuthProvider class

  // Contact / User info section only
  String? secondaryEmail;
  List<String> phones = []; // multiple phone numbers
  Map<String, String> socialMedia = {}; // type -> url
  String? about;

// Load user contact info from Firestore
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

// Secondary email
  Future<void> setSecondaryEmail(String email) async {
    secondaryEmail = email;
    await _saveContactsToFirestore();
    notifyListeners();
  }

// Phones
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

// Social media
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

// About / description
  Future<void> setAbout(String text) async {
    about = text;
    await _saveContactsToFirestore();
    notifyListeners();
  }

// Save contacts info to Firestore
  Future<void> _saveContactsToFirestore() async {
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'secondaryEmail': secondaryEmail,
      'phones': phones,
      'socialMedia': socialMedia,
      'about': about,
    }, SetOptions(merge: true));
  }


  // Sign in with email/password
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

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      debugPrint("Password Reset Error: $e");
      return false;
    }
  }

  // Google Sign-in
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
      googleUser ??= await _googleSignIn.authenticate();

      // Get OAuth tokens
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
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

  // Sign up with email/password
  Future<bool> signUpWithEmail(String email, String password, String name) async {
    try {
      final userCredential =
      await _auth.createUserWithEmailAndPassword(email: email, password: password);

      await userCredential.user?.updateDisplayName(name);
      await userCredential.user?.reload();
      user = _auth.currentUser;

      // Initialize Firestore document for the user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set({'avatarUrl': null}, SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set({
        'avatarUrl': null,
        'secondaryEmail': null,
        'phones': [],
        'socialMedia': {},
        'about': null,
      }, SetOptions(merge: true));


      notifyListeners();
      return true;
    } catch (e) {
      print("Register Error: $e");
      return false;
    }
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

  // Upload avatar to Supabase
  Future<String?> uploadAvatar(XFile file, String userId) async {
    try {
      final supabaseServiceClient = supabase.SupabaseClient(
        'https://cccljhxlvmizkugxgoxi.supabase.co',
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNjY2xqaHhsdm1pemt1Z3hnb3hpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTQ0MTQ5NywiZXhwIjoyMDcxMDE3NDk3fQ.7On6QtM6GMg-g2ae2ift6OrJ0BkLy69TMWelaK82JEg', // <-- replace this with your service role key
      );

      final path = 'avatars/$userId.jpg';

      await supabaseServiceClient.storage
          .from('user-avatars')
          .upload(path, File(file.path), fileOptions: supabase.FileOptions(upsert: true));

      final publicUrl = supabaseServiceClient.storage
          .from('user-avatars')
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      print('Avatar upload error: $e');
      return null;
    }
  }


  // Set avatar: upload + save to Firebase + Firestore
  Future<bool> setAvatar(XFile file) async {
    if (user == null) return false;

    final userId = user!.uid;
    final url = await uploadAvatar(file, userId);

    if (url != null) {
      try {
        // Update Firebase Auth photoURL
        await user!.updatePhotoURL(url);
        await user!.reload();
        user = _auth.currentUser;
        avatarUrl = url;

        // Save in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set({'avatarUrl': url}, SetOptions(merge: true));

        notifyListeners();
        return true;
      } catch (e) {
        print('Failed to set photoURL: $e');
        return false;
      }
    }
    return false;
  }

  // Load avatar URL from Firestore
  Future<void> _loadAvatarFromFirestore() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (doc.exists) {
      avatarUrl = doc.data()?['avatarUrl'];
    }
  }

  bool isVerified() => user != null && user!.emailVerified;

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
    await _auth.signOut();
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
