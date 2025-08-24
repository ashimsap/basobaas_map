import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:basobaas_map/provider/post_provider.dart';
import '../shared_widgets/post_detail_page.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final Location _locationService = Location();
  LocationData? _currentLocation;
  static final LatLng _defaultCenter = LatLng(27.6756, 85.3459);

  late final MapController _mapController;
  final PopupController _popupController = PopupController();
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic>? _selectedPost;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initLocation();

    // Refresh markers after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PostProvider>(context, listen: false).refreshMarkers();
    });
  }

  /// Initialize user location and listen to changes
  Future<void> _initLocation() async {
    bool serviceEnabled = await _locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationService.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _locationService.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationService.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    final location = await _locationService.getLocation();
    setState(() => _currentLocation = location);

    _locationService.onLocationChanged.listen((newLoc) {
      setState(() => _currentLocation = newLoc);
    });
  }

  /// Move map to current location
  void _goToCurrentLocation() {
    if (_currentLocation == null) return;
    final latLng =
    LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!);
    _mapController.move(latLng, 16);
  }

  /// Reset map rotation to north
  void _resetMapRotation() {
    _mapController.rotate(0);
  }

  /// Show information popup about the map
  void _showInfoPopup() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Center(child: const Text("Map Information")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This map shows rental posts in your area.\n"
                  "Use the search bar to find locations.\n"
                  "Tap markers to see rental details.\n"
                  "Current location centers the map on you.\n",
            ),
            const SizedBox(height: 8),
            Row(
              children: const [
                Icon(Icons.location_on, color: Colors.green),
                SizedBox(width: 8),
                Text("Vacant"),
              ],
            ),
            Row(
              children: const [
                Icon(Icons.location_on, color: Colors.red),
                SizedBox(width: 8),
                Text("Rented"),
              ],
            ),
            Row(
              children: const [
                Icon(Icons.location_on, color: Colors.orange),
                SizedBox(width: 8),
                Text("To be available soon"),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }



  /// Search location by query
  void _searchLocation(String query) async {
    if (query.isEmpty) return;

    try {
      final locations = await geo.locationFromAddress(query);
      if (locations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No locations found.")),
        );
        return;
      }

      final loc = locations.first;
      final target = LatLng(loc.latitude, loc.longitude);
      _mapController.move(target, 15);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error searching location.")),
      );
    }
  }

  /// Open bottom sheet with post details
  void _openBottomSheet(Map<String, dynamic> post) {
    _selectedPost = post;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withAlpha(50),
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.37,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          snap: false,
          snapSizes: const [0.37, 0.8],
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  // Pill indicator
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    width: 80,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // PostDetailPage uses scrollController for smooth scrolling
                  Expanded(
                    child: PostDetailPage(
                      post: _selectedPost!,
                      scrollController: scrollController,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Build markers safely with unique keys
  List<Marker> _buildMarkers(PostProvider postProvider) {
    final center = _currentLocation != null
        ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
        : _defaultCenter;

    return [
      // Current user location marker
      if (_currentLocation != null)
        Marker(
          key: const ValueKey('current_location'),
          point: center,
          width: 40,
          height: 40,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
        ),

      // Markers from provider, safely filtered
      ...postProvider.markers.map((marker) {
        final postId = (marker.key as ValueKey).value.toString();
        final post = postProvider.allPosts.firstWhere(
              (p) => p['id'] == postId,
          orElse: () => {},
        );

        return Marker(
          key: ValueKey(post['id']),
          point: marker.point,
          width: marker.width,
          height: marker.height,
          child: GestureDetector(
            onTap: () => _openBottomSheet(post),
            child: marker.child,
          ),
        );
      }).whereType<Marker>(), // remove nulls safely
    ];
  }

  @override
  Widget build(BuildContext context) {
    final postProvider = Provider.of<PostProvider>(context);
    final center = _currentLocation != null
        ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
        : _defaultCenter;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              minZoom: 2,
              maxZoom: 18,
              onTap: (_, __) => _popupController.hideAllPopups(),
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.basobaas_map",
              ),
              PopupMarkerLayer(
                options: PopupMarkerLayerOptions(
                  markers: _buildMarkers(postProvider),
                  popupController: _popupController,
                  markerTapBehavior: MarkerTapBehavior.none(
                        (popupSpec, popupState, controller) {},
                  ),
                  selectedMarkerBuilder: (context, marker) =>
                  const SizedBox.shrink(),
                ),
              ),
            ],
          ),

          // Search bar
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search location...',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: _searchLocation,
            ),
          ),

          // Compass button
          Positioned(
            top: 100,
            right: 16,
            child: ClipOval(
              child: Material(
                color: Colors.white,
                child: InkWell(
                  onTap: _resetMapRotation,
                  child: const SizedBox(
                    width: 50,
                    height: 50,
                    child: Icon(Icons.explore, color: Colors.black),
                  ),
                ),
              ),
            ),
          ),

          // Info button
          Positioned(
            top: 100,
            left: 16,
            child: ClipOval(
              child: Material(
                color: Colors.white,
                child: InkWell(
                  onTap: _showInfoPopup,
                  child: const SizedBox(
                    width: 50,
                    height: 50,
                    child: Icon(Icons.info_outline, color: Colors.black),
                  ),
                ),
              ),
            ),
          ),

          // Current location button
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              shape: const CircleBorder(),
              heroTag: 'current_location',
              onPressed: _goToCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
