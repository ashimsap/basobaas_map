import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:supabase_flutter/supabase_flutter.dart'; // Uncomment after connecting Supabase

class PostProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final supabase = Supabase.instance.client; // Uncomment after setup

  bool _loading = false;
  bool get loading => _loading;

  List<Map<String, dynamic>> _activeListings = [];
  List<Map<String, dynamic>> get activeListings => _activeListings;

  List<Map<String, dynamic>> _savedRentals = [];
  List<Map<String, dynamic>> get savedRentals => _savedRentals;

  /// ---------- Post a new rental ----------
  Future<void> postRental({
    required Map<String, dynamic> metadata,
    required List<XFile> images,
    required String userId,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      // 1️⃣ Upload images to Supabase (commented for now)
      List<String> imageUrls = [];
      // for (var img in images) {
      //   final fileBytes = await img.readAsBytes();
      //   final fileName = 'rentals/$userId/${DateTime.now().millisecondsSinceEpoch}_${img.name}';
      //   final response = await supabase.storage.from('rental-images').uploadBinary(fileName, fileBytes);
      //   final url = supabase.storage.from('rental-images').getPublicUrl(fileName);
      //   imageUrls.add(url);
      // }

      // 2️⃣ Add post metadata to Firestore
      final docRef = await _firestore.collection('rentals').add({
        ...metadata,
        'images': imageUrls, // For now empty if Supabase not connected
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'filledDate': null, // initially null
      });

      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// ---------- Fetch user's active listings ----------
  Future<void> fetchActiveListings(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('rentals')
          .where('userId', isEqualTo: userId)
          .get();

      _activeListings = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// ---------- Toggle Filled status ----------
  Future<void> toggleFilled(String postId, bool filled) async {
    try {
      final updateData = {
        'filledDate': filled ? FieldValue.serverTimestamp() : null,
      };
      await _firestore.collection('rentals').doc(postId).update(updateData);

      // Update local copy
      final index = _activeListings.indexWhere((p) => p['id'] == postId);
      if (index != -1) {
        _activeListings[index]['filledDate'] = filled ? Timestamp.now() : null;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// ---------- Auto-remove filled posts older than 5 days ----------
  Future<void> removeExpiredFilledPosts() async {
    final now = DateTime.now();
    final snapshot = await _firestore
        .collection('rentals')
        .where('filledDate', isLessThanOrEqualTo: Timestamp.fromDate(now.subtract(const Duration(days: 5))))
        .get();

    for (var doc in snapshot.docs) {
      await _firestore.collection('rentals').doc(doc.id).delete();
    }
  }

  /// ---------- Fetch saved rentals (bookmarked by user) ----------
  Future<void> fetchSavedRentals(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('rentals')
          .where('savedBy', arrayContains: userId)
          .get();

      _savedRentals = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// ---------- Save or unsave a rental ----------
  Future<void> toggleSaveRental(String postId, String userId, bool save) async {
    try {
      final docRef = _firestore.collection('rentals').doc(postId);
      if (save) {
        await docRef.update({
          'savedBy': FieldValue.arrayUnion([userId])
        });
      } else {
        await docRef.update({
          'savedBy': FieldValue.arrayRemove([userId])
        });
      }

      // Update local copy
      final index = _savedRentals.indexWhere((p) => p['id'] == postId);
      if (index != -1) {
        if (save) {
          if (!(_savedRentals[index]['savedBy'] as List).contains(userId)) {
            (_savedRentals[index]['savedBy'] as List).add(userId);
          }
        } else {
          (_savedRentals[index]['savedBy'] as List).remove(userId);
        }
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }
}
