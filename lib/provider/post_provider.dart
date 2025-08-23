import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

class PostProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient supabaseClient;

  PostProvider(this.supabaseClient) {
    _listenToPosts(); // Start real-time marker listener
  }

  // =========================
  // Loading & Core Data
  // =========================
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

  // =========================
  // Search & Filters
  // =========================
  String _searchQuery = "";
  String get searchQuery => _searchQuery;
  //getters
  String? get typeFilter => _typeFilter;
  double? get minPrice => _minPrice;
  double? get maxPrice => _maxPrice;

  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get locationKeyword => _locationKeyword;


  String? _typeFilter; // Room, Flat, Hostel, or null (off)

  double? _minPrice;
  double? _maxPrice;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _locationKeyword;

  Set<String> _amenitiesFilter = {};
  Set<String> get amenitiesFilter => _amenitiesFilter;

  String? _parkingFilter;
  String? get parkingFilter => _parkingFilter;

  Set<String> _nearbyFilter = {};
  Set<String> get nearbyFilter => _nearbyFilter;

// Setter methods
  void setAmenitiesFilter(Set<String> amenities) {
    _amenitiesFilter = amenities;
    notifyListeners();
  }

  void setParkingFilter(String? parking) {
    _parkingFilter = parking;
    notifyListeners();
  }

  void setNearbyFilter(Set<String> nearby) {
    _nearbyFilter = nearby;
    notifyListeners();
  }

  /// Sorting
  bool? isPriceAsc; // true = low->high, false = high->low, null = off
  bool sortByRecent = false;

  /// Update search query
  void updateSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setTypeFilter(String? type) {
    _typeFilter = type;
    notifyListeners();
  }



  void setPriceRange(double? min, double? max) {
    _minPrice = min;
    _maxPrice = max;
    notifyListeners();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  void setLocationKeyword(String? keyword) {
    _locationKeyword = keyword;
    notifyListeners();
  }

  void togglePriceSort() {
    if (isPriceAsc == null) {
      isPriceAsc = true;
    } else if (isPriceAsc == true) {
      isPriceAsc = false;
    } else {
      isPriceAsc = null;
    }
    notifyListeners();
  }

  void toggleRecentSort() {
    sortByRecent = !sortByRecent;
    notifyListeners();
  }

  List<Map<String, dynamic>> get filteredPosts {
    var posts = [..._allPosts];

    // -------------------
    // Search filter
    // -------------------
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      posts = posts.where((p) {
        final title = (p['title'] ?? "").toString().toLowerCase();
        final desc = (p['description'] ?? "").toString().toLowerCase();
        final addr = (p['address'] ?? "").toString().toLowerCase();

        final titleScore = ratio(title, query);
        final descScore = ratio(desc, query);
        final addrScore = ratio(addr, query);

        return titleScore > 30 || descScore > 30 || addrScore > 30;
      }).toList();
    }

    // -------------------
    // Price filter
    // -------------------
    if (_minPrice != null) posts = posts.where((p) => (p['price'] ?? 0) >= _minPrice!).toList();
    if (_maxPrice != null) posts = posts.where((p) => (p['price'] ?? 0) <= _maxPrice!).toList();

    // -------------------
    // Post date filter
    // -------------------
    if (startDate != null || endDate != null) {
      posts = posts.where((p) {
        final createdAt = p['createdAt'];
        DateTime? postDate;
        if (createdAt is Timestamp) postDate = createdAt.toDate();
        else if (createdAt is DateTime) postDate = createdAt;
        if (postDate == null) return false;
        if (startDate != null && postDate.isBefore(startDate!)) return false;
        if (endDate != null && postDate.isAfter(endDate!)) return false;
        return true;
      }).toList();
    }

    // -------------------
    // Location filter
    // -------------------
    if (_locationKeyword != null && _locationKeyword!.isNotEmpty) {
      posts = posts.where((p) {
        final addr = (p['address'] ?? "").toString().toLowerCase();
        final landmark = (p['landmark'] ?? "").toString().toLowerCase();
        return addr.contains(_locationKeyword!.toLowerCase()) ||
            landmark.contains(_locationKeyword!.toLowerCase());
      }).toList();
    }

    // -------------------
    // Amenities filter
    // -------------------
    if (_amenitiesFilter.isNotEmpty) {
      posts = posts.where((p) {
        final postAmenities = List<String>.from(p['amenities'] ?? []);
        return _amenitiesFilter.every((amenity) => postAmenities.contains(amenity));
      }).toList();
    }

    // -------------------s
    // Type filter
    // -------------------
    if (_typeFilter != null && _typeFilter!.isNotEmpty) {
      posts = posts.where((p) {
        final type = (p['propertyType'] ?? "").toString().toLowerCase();
        return type == _typeFilter!.toLowerCase();
      }).toList();
    }


    // -------------------
    // Parking filter
    // -------------------
    if (_parkingFilter != null) {
      posts = posts.where((p) {
        final parking = (p['parking'] ?? "").toString();
        if (_parkingFilter == "Both") {
          return parking == "Bike & Car"; // exact match
        } else {
          return parking == _parkingFilter;
        }
      }).toList();
    }

    // -------------------
    // Nearby places filter
    // -------------------
    if (_nearbyFilter.isNotEmpty) {
      posts = posts.where((p) {
        final postNearby = List<String>.from(p['nearby'] ?? []);
        return _nearbyFilter.every((place) => postNearby.contains(place));
      }).toList();
    }

    // -------------------
    // Sort by recent
    // -------------------
    if (sortByRecent) {
      posts.sort((a, b) {
        final aDate = a['createdAt'] is DateTime ? a['createdAt'] : (a['createdAt'] as Timestamp).toDate();
        final bDate = b['createdAt'] is DateTime ? b['createdAt'] : (b['createdAt'] as Timestamp).toDate();
        return bDate.compareTo(aDate);
      });
    }

    // -------------------
    // Sort by price
    // -------------------
    if (isPriceAsc != null) {
      posts.sort((a, b) {
        final aPrice = a['price'] ?? 0;
        final bPrice = b['price'] ?? 0;
        return isPriceAsc! ? aPrice.compareTo(bPrice) : bPrice.compareTo(aPrice);
      });
    }

    return posts;
  }
  ///--------reset filters----------
  void resetFilters() {
    _searchQuery = "";
    _typeFilter = null;
    _minPrice = null;
    _maxPrice = null;
    _startDate = null;
    _endDate = null;
    _locationKeyword = null;
    _amenitiesFilter.clear();
    _parkingFilter = null;
    _nearbyFilter.clear();
    isPriceAsc = null;
    sortByRecent = false;

    notifyListeners();
  }
  bool get isFilterActive {
    return (_minPrice != null) ||
        (_maxPrice != null) ||
        (_startDate != null) ||
        (_endDate != null) ||
        (_locationKeyword != null && _locationKeyword!.isNotEmpty) ||
        (_amenitiesFilter.isNotEmpty) ||
        (_parkingFilter != null) ||
        (_nearbyFilter.isNotEmpty);
  }



  // =========================
  // Posting & Updating Rentals
  // =========================
  Future<void> postRental({
    required Map<String, dynamic> metadata,
    required List<XFile> images,
    required String userId,
  }) async {
    _loading = true;
    notifyListeners();

    List<String> uploadedImageUrls = [];
    const defaultImageUrl = 'https://cccljhxlvmizkugxgoxi.supabase.co/storage/v1/object/public/Basobas/Home.png';

    try {
      // Ensure price is numeric
      metadata['price'] = metadata['price'] is num
          ? metadata['price']
          : double.tryParse(metadata['price']?.toString() ?? '0') ?? 0;

      // Upload images to Supabase
      for (var img in images) {
        final fileBytes = await img.readAsBytes();
        final fileName =
            'rentals/$userId/${DateTime.now().millisecondsSinceEpoch}_${img.name}';
        await supabaseClient.storage
            .from('rental-images')
            .uploadBinary(fileName, fileBytes);
        final url =
        supabaseClient.storage.from('rental-images').getPublicUrl(fileName);
        uploadedImageUrls.add(url);
      }
      //default image if non added
      if (uploadedImageUrls.isEmpty) {
        uploadedImageUrls.add(defaultImageUrl);
      }

      // Save rental post
      final docRef = await _firestore.collection('rentals').add({
        ...metadata,
        'images': uploadedImageUrls,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'rentedSince': metadata['rentedSince'] ?? null,
      });

      // Add map marker
      final loc = metadata['location'];
      if (loc != null && loc['latitude'] != null && loc['longitude'] != null) {
        final color = _getMarkerColor(metadata);
        _markers.add(Marker(
          key: ValueKey(docRef.id),
          point: LatLng(loc['latitude'], loc['longitude']),
          width: 40,
          height: 40,
          child: Icon(Icons.location_on, color: color, size: 40),
        ));
        notifyListeners();
      }

      _loading = false;
      notifyListeners();
    } catch (e) {
      // Rollback uploaded images if failed
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

  Future<void> updateRental({
    required String postId,
    required Map<String, dynamic> metadata,
    List<String>? newImages,
  }) async {
    try {
      // Merge new images
      if (newImages != null && newImages.isNotEmpty) {
        final currentImages = List<String>.from(metadata['images'] ?? []);
        metadata['images'] = [...currentImages, ...newImages];
      }

      // Ensure price is numeric
      metadata['price'] = metadata['price'] is num
          ? metadata['price']
          : double.tryParse(metadata['price']?.toString() ?? '0') ?? 0;

      await _firestore.collection('rentals').doc(postId).update(metadata);

      // Update local copies
      final activeIndex = _activeListings.indexWhere((p) => p['id'] == postId);
      if (activeIndex != -1) {
        _activeListings[activeIndex] = {..._activeListings[activeIndex], ...metadata};
      }

      final allIndex = _allPosts.indexWhere((p) => p['id'] == postId);
      if (allIndex != -1) {
        _allPosts[allIndex] = {..._allPosts[allIndex], ...metadata};
      }

      // Update marker color
      final loc = _activeListings[activeIndex]['location'];
      if (loc != null) {
        final markerIndex =
        _markers.indexWhere((m) => (m.key as ValueKey).value == postId);
        if (markerIndex != -1) {
          _markers[markerIndex] = Marker(
            key: ValueKey(postId),
            point: LatLng(loc['latitude'], loc['longitude']),
            width: 40,
            height: 40,
            child: Icon(
              Icons.location_on,
              color: _getMarkerColor(_activeListings[activeIndex]),
              size: 40,
            ),
          );
        }
      }

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update post: $e');
    }
  }



  Future<void> toggleStatus(String postId, String newStatus) async {
    final index = _activeListings.indexWhere((p) => p['id'] == postId);
    if (index == -1) return;

    Map<String, dynamic> updateData = {'status': newStatus};
    if (newStatus == 'Rented') {
      updateData['rentedSince'] = DateTime.now().toIso8601String();
    } else if (newStatus == 'Vacant') {
      updateData['rentedSince'] = null;
    }

    await _firestore.collection('rentals').doc(postId).update(updateData);
    _activeListings[index] = {..._activeListings[index], ...updateData};

    final loc = _activeListings[index]['location'];
    if (loc != null) {
      final markerIndex =
      _markers.indexWhere((m) => (m.key as ValueKey).value == postId);
      final color = _getMarkerColor(_activeListings[index]);
      if (markerIndex != -1) {
        _markers[markerIndex] = Marker(
          key: ValueKey(postId),
          point: LatLng(loc['latitude'], loc['longitude']),
          width: 40,
          height: 40,
          child: Icon(Icons.location_on, color: color, size: 40),
        );
      }
    }

    notifyListeners();
  }

  Future<void> refreshStatuses() async {
    final now = DateTime.now();
    final snapshot = await _firestore
        .collection('rentals')
        .where('status', isEqualTo: 'To Be Vacant')
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['availableFrom'] != null) {
        final availableFrom = DateTime.parse(data['availableFrom']);
        if (availableFrom.isBefore(now)) {
          await _firestore.collection('rentals').doc(doc.id).update({
            'status': 'Vacant',
            'availableFrom': null,
          });

          final index = _activeListings.indexWhere((p) => p['id'] == doc.id);
          if (index != -1) {
            _activeListings[index]['status'] = 'Vacant';
            _activeListings[index]['availableFrom'] = null;

            final markerIndex =
            _markers.indexWhere((m) => (m.key as ValueKey).value == doc.id);
            if (markerIndex != -1) {
              final loc = _activeListings[index]['location'];
              _markers[markerIndex] = Marker(
                key: ValueKey(doc.id),
                point: LatLng(loc['latitude'], loc['longitude']),
                width: 40,
                height: 40,
                child: Icon(Icons.location_on, color: Colors.green, size: 40),
              );
            }
          }
        }
      }
    }
    notifyListeners();
  }

  Color _getMarkerColor(Map<String, dynamic> rental) {
    final status = rental['status'];
    switch (status) {
      case 'To Be Vacant':
        return Colors.orange;
      case 'Rented':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  // =========================
  // Fetching Posts & Saved Rentals
  // =========================
  Future<void> fetchAllPosts(String userId) async {
    try {
      final snapshot = await _firestore.collection('rentals').get();

      _allPosts = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        // Ensure 'price' is always a number (or 0 if missing)
        if (data['price'] != null && data['price'] is! num) {
          data['price'] = num.tryParse(data['price'].toString()) ?? 0;
        }

        return data;
      }).toList();

      // Fetch saved rentals safely
      await fetchSavedRentals(userId);
    } catch (e, st) {
      debugPrint('Error fetching posts: $e\n$st');
    } finally {
      notifyListeners(); // always notify listeners
    }
  }


  Future<void> toggleSavePost(String postId, String userId) async {
    final savedRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('savedRentals')
        .doc(postId);

    final savedDoc = await savedRef.get();
    if (savedDoc.exists) {
      await savedRef.delete();
    } else {
      await savedRef.set({'savedAt': FieldValue.serverTimestamp()});
    }

    final index = _allPosts.indexWhere((p) => p['id'] == postId);

    await fetchSavedRentals(userId);
    notifyListeners();
  }

  Future<void> fetchSavedRentals(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('savedRentals')
        .get();
    final savedIds = snapshot.docs.map((d) => d.id).toSet();

    for (var post in _allPosts) {
      post['isSaved'] = savedIds.contains(post['id']);
    }

    _savedRentals = _allPosts.where((p) => p['isSaved'] == true).toList();
    notifyListeners();
  }
  ///---------Active Listings-----------

  Future<void> fetchActiveListings(String userId) async {
    final snapshot = await _firestore
        .collection('rentals')
        .where('userId', isEqualTo: userId)
        .get();

    _activeListings = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;

      // Parse availableFrom if present
      DateTime? availableFrom;
      if (data['availableFrom'] != null) {
        availableFrom = data['availableFrom'] is Timestamp
            ? (data['availableFrom'] as Timestamp).toDate()
            : DateTime.parse(data['availableFrom']);
      }

      // Parse rentedSince if present
      DateTime? rentedSince;
      if (data['rentedSince'] != null) {
        rentedSince = data['rentedSince'] is Timestamp
            ? (data['rentedSince'] as Timestamp).toDate()
            : DateTime.parse(data['rentedSince']);
      }

      // Determine current status
      if (rentedSince != null) {
        data['status'] = 'Rented';
      } else if (availableFrom != null && DateTime.now().isBefore(availableFrom)) {
        data['status'] = 'To Be Vacant';
        data['rentedSince'] = null; // ensure toggle won't show
      } else {
        data['status'] = 'Vacant';
        data['rentedSince'] = null; // ensure toggle won't show
      }

      return data;
    }).toList();

    notifyListeners();
  }



  // =========================
  // Markers & Real-Time Listener
  // =========================
  Future<void> refreshMarkers() async {
    final posts = await fetchPostLocations();
    _markers = posts
        .where((p) => p['location'] != null)
        .map((post) {
      final loc = post['location'];
      return Marker(
        key: ValueKey(post['id']), // unique key
        point: LatLng(loc['latitude'], loc['longitude']),
        width: 40,
        height: 40,
        child: Icon(Icons.location_on, color: _getMarkerColor(post), size: 40),
      );
    }).toList();
    notifyListeners();
  }


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
      }).toList();
      _markers = markers;
      notifyListeners();
    });
  }

  Future<List<Map<String, dynamic>>> fetchPostLocations() async {
    final snapshot = await _firestore.collection('rentals').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  @override
  void dispose() {
    _postSub?.cancel();
    super.dispose();
  }
}
