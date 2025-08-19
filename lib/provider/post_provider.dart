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
      for (var img in images) {
        final fileBytes = await img.readAsBytes();
        final fileName =
            'rentals/$userId/${DateTime.now().millisecondsSinceEpoch}_${img.name}';
        await supabaseClient.storage.from('rental-images').uploadBinary(fileName, fileBytes);
        final url = supabaseClient.storage.from('rental-images').getPublicUrl(fileName);
        uploadedImageUrls.add(url);
      }

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
        if (color != null) {
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
      }

      _loading = false;
      notifyListeners();
    } catch (e) {
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

  /// Refresh all posts for HomePage
  Future<void> fetchAllPosts() async {
    final snapshot = await _firestore.collection('rentals').get();
    _allPosts = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
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


  /// ---------- TOGGLE FILLED ----------
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
      notifyListeners();
    }

    // Update the marker color immediately
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

  /// ---------- MARKER REFRESH LOGIC ----------
  Future<void> refreshMarkers() async {
    final posts = await fetchPostLocations(); // fetch latest post data

    final updatedMarkers = <Marker>[];

    for (var post in posts) {
      final loc = post['location'];
      if (loc != null && loc['latitude'] != null && loc['longitude'] != null) {
        updatedMarkers.add(
          Marker(
            key: ValueKey(post['id']),
            point: LatLng(loc['latitude'], loc['longitude']),
            width: 40,
            height: 40,
            child: Icon(
              Icons.location_on,
              color: _getMarkerColor(post),
              size: 40,
            ),
          ),
        );
      }
    }

    _markers = updatedMarkers;
    notifyListeners();
  }


  /// ---------- REAL-TIME MARKERS ----------
  void _listenToPosts() {
    _postSub = _firestore.collection('rentals').snapshots().listen((snapshot) {
      final markers = <Marker>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final loc = data['location'];
        if (loc != null && loc['latitude'] != null && loc['longitude'] != null) {
          final color = _getMarkerColor(data);
          if (color != null) {
            markers.add(
              Marker(
                key: ValueKey(doc.id),
                point: LatLng(loc['latitude'], loc['longitude']),
                width: 40,
                height: 40,
                child: Icon(Icons.location_on, color: color, size: 40),
              ),
            );
          }
        }
      }
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
