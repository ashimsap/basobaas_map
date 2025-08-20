import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class PostProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient supabaseClient;

  PostProvider(this.supabaseClient) {
    _listenToPosts(); // start real-time marker listener
  }

  bool _loading = false;
  bool get loading => _loading;

  List<Marker> _markers = [];
  List<Marker> get markers => _markers;

  List<Map<String, dynamic>> _activeListings = [];
  List<Map<String, dynamic>> get activeListings => _activeListings;

  List<Map<String, dynamic>> _allPosts = [];
  List<Map<String, dynamic>> get allPosts => _allPosts;

  List<Map<String, dynamic>> _savedRentals = [];
  List<Map<String, dynamic>> get savedRentals => _savedRentals;


  StreamSubscription? _postSub;

  /// ---------- POST RENTAL ----------
  Future<void> postRental({
    required Map<String, dynamic> metadata,
    required List<XFile> images,
    required String userId,
  }) async {
    _loading = true;
    notifyListeners();

    List<String> uploadedImageUrls = [];

    try {
      // Upload images to Supabase
      for (var img in images) {
        final fileBytes = await img.readAsBytes();
        final fileName =
            'rentals/$userId/${DateTime.now().millisecondsSinceEpoch}_${img.name}';
        await supabaseClient.storage.from('rental-images').uploadBinary(fileName, fileBytes);
        final url = supabaseClient.storage.from('rental-images').getPublicUrl(fileName);
        uploadedImageUrls.add(url);
      }

      // Add post metadata to Firestore
      final docRef = await _firestore.collection('rentals').add({
        ...metadata,
        'images': uploadedImageUrls,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'filledDate': null,
      });

      // Add marker immediately
      final loc = metadata['location'];
      if (loc != null && loc['latitude'] != null && loc['longitude'] != null) {
        final color = _getMarkerColor({
          'filledDate': null,
          'dueDate': metadata['dueDate'],
        });
        _markers.add(
          Marker(
            key: ValueKey(docRef.id),
            point: LatLng(loc['latitude'], loc['longitude']),
            width: 40,
            height: 40,
            child: Icon(Icons.location_on, color: color, size: 40),
          ),
        );
        notifyListeners();
      }

      _loading = false;
      notifyListeners();
    } catch (e) {
      // Remove uploaded images if post fails
      for (var url in uploadedImageUrls) {
        final path = url.split('/').last;
        try {
          await supabaseClient.storage.from('rental-images').remove([path]);
        } catch (_) {}
      }
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// ---------- UPDATE POST ----------
  Future<void> updateRental({
    required String postId,
    required Map<String, dynamic> metadata,
    List<String>? newImages, // URLs of newly uploaded images
  }) async {
    try {
      // Merge new images if any
      if (newImages != null && newImages.isNotEmpty) {
        final currentImages = List<String>.from(metadata['images'] ?? []);
        metadata['images'] = [...currentImages, ...newImages];
      }

      await _firestore.collection('rentals').doc(postId).update(metadata);

      // Update local active listings
      final index = _activeListings.indexWhere((p) => p['id'] == postId);
      if (index != -1) {
        _activeListings[index] = {
          ..._activeListings[index],
          ...metadata,
        };
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to update post: $e');
    }
  }

  /// ---------- FETCH ALL POSTS ----------
  Future<void> fetchAllPosts() async {
    final snapshot = await _firestore.collection('rentals').get();
    _allPosts = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    _savedRentals = _allPosts.where((p) => p['isSaved'] == true).toList();

    notifyListeners();
  }

  /// Toggle the saved/starred status of a post
  Future<void> toggleSavePost(String postId) async {
    // Find the post in allPosts
    final index = _allPosts.indexWhere((p) => p['id'] == postId);
    if (index == -1) return; // Post not found

    final post = _allPosts[index];
    final currentlySaved = post['isSaved'] == true;

    // Update Firestore
    await _firestore.collection('rentals').doc(postId).update({
      'isSaved': !currentlySaved,
    });

    // Update local allPosts
    post['isSaved'] = !currentlySaved;

    // Update savedRentals list
    if (post['isSaved'] == true) {
      // Add if not already in savedRentals
      if (!_savedRentals.any((p) => p['id'] == postId)) _savedRentals.add(post);
    } else {
      // Remove if present
      _savedRentals.removeWhere((p) => p['id'] == postId);
    }

    notifyListeners();
  }


  /// ---------- FETCH ACTIVE LISTINGS ----------
  Future<void> fetchActiveListings(String userId) async {
    final snapshot = await _firestore
        .collection('rentals')
        .where('userId', isEqualTo: userId)
        .get();

    _activeListings = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;

      DateTime? dueDate;
      if (data['dueDate'] != null) {
        dueDate = data['dueDate'] is Timestamp
            ? (data['dueDate'] as Timestamp).toDate()
            : data['dueDate'] as DateTime;
      }

      DateTime? filledDate;
      if (data['filledDate'] != null) {
        filledDate = data['filledDate'] is Timestamp
            ? (data['filledDate'] as Timestamp).toDate()
            : data['filledDate'] as DateTime;
      }

      if (filledDate != null) {
        data['status'] = 'rented';
      } else if (dueDate != null && DateTime.now().isBefore(dueDate)) {
        data['status'] = 'toBeAvailable';
      } else {
        data['status'] = 'vacant';
      }

      return data;
    }).toList();

    notifyListeners();
  }

  /// ---------- TOGGLE FILLED STATUS ----------
  Future<void> toggleFilled(String postId, bool filled) async {
    final updateData = {
      'filledDate': filled ? FieldValue.serverTimestamp() : null,
    };

    // Update Firestore
    await _firestore.collection('rentals').doc(postId).update(updateData);

    // Update local activeListings
    final index = _activeListings.indexWhere((p) => p['id'] == postId);
    if (index != -1) {
      _activeListings[index]['filledDate'] = filled ? Timestamp.now() : null;
      _activeListings[index]['status'] = filled ? 'rented' : 'vacant';
      notifyListeners();
    }

    // Update marker immediately
    final markerIndex = _markers.indexWhere((m) => m.key == ValueKey(postId));
    if (markerIndex != -1) {
      final postData = _activeListings.firstWhere((p) => p['id'] == postId);
      final loc = postData['location'];
      if (loc != null && loc['latitude'] != null && loc['longitude'] != null) {
        _markers[markerIndex] = Marker(
          key: ValueKey(postId),
          point: LatLng(loc['latitude'], loc['longitude']),
          width: 40,
          height: 40,
          child: Icon(
            Icons.location_on,
            color: _getMarkerColor(postData),
            size: 40,
          ),
        );
        notifyListeners();
      }
    }
  }

  /// ---------- FETCH POST LOCATIONS ----------
  Future<List<Map<String, dynamic>>> fetchPostLocations() async {
    final snapshot = await _firestore.collection('rentals').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// ---------- REFRESH MARKERS ----------
  Future<void> refreshMarkers() async {
    final posts = await fetchPostLocations();
    _markers = posts
        .where((p) => p['location'] != null)
        .map((post) {
      final loc = post['location'];
      return Marker(
        key: ValueKey(post['id']),
        point: LatLng(loc['latitude'], loc['longitude']),
        width: 40,
        height: 40,
        child: Icon(Icons.location_on, color: _getMarkerColor(post), size: 40),
      );
    })
        .toList();
    notifyListeners();
  }

  /// ---------- REAL-TIME MARKERS ----------
  void _listenToPosts() {
    _postSub = _firestore.collection('rentals').snapshots().listen((snapshot) {
      final markers = snapshot.docs
          .where((doc) => doc.data()['location'] != null)
          .map((doc) {
        final data = doc.data();
        final loc = data['location'];
        return Marker(
          key: ValueKey(doc.id),
          point: LatLng(loc['latitude'], loc['longitude']),
          width: 40,
          height: 40,
          child: Icon(Icons.location_on, color: _getMarkerColor(data), size: 40),
        );
      })
          .toList();
      _markers = markers;
      notifyListeners();
    });
  }

  /// ---------- MARKER COLOR LOGIC ----------
  Color _getMarkerColor(Map<String, dynamic> post) {
    final filledDate = post['filledDate'] as Timestamp?;
    final dueDate = post['dueDate'] as Timestamp?;

    if (filledDate != null) {
      if (DateTime.now().difference(filledDate.toDate()).inDays > 5) return Colors.grey;
      return Colors.red;
    } else if (dueDate != null && DateTime.now().isBefore(dueDate.toDate())) {
      return Colors.yellow;
    } else {
      return Colors.green;
    }
  }

  @override
  void dispose() {
    _postSub?.cancel();
    super.dispose();
  }
}
