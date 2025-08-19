import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:basobaas_map/provider/post_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final Location _locationService = Location();
  LocationData? _currentLocation;
  bool _permissionGranted = false;

  static final LatLng _defaultCenter = LatLng(27.6756, 85.3459);
  late final MapController _mapController;
  List<Marker> _postMarkers = [];
  String? _selectedPostId; // for marker click selection

  final Map<String, Map<String, dynamic>> _postsById = {};

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initLocation();
    _loadPostMarkers();
  }

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

    _permissionGranted = true;
    final location = await _locationService.getLocation();
    setState(() => _currentLocation = location);

    _locationService.onLocationChanged.listen((newLoc) {
      setState(() => _currentLocation = newLoc);
    });
  }

  Future<void> _loadPostMarkers() async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final posts = await postProvider.fetchPostLocations();

    final markers = <Marker>[];
    _postsById.clear();

    for (var post in posts) {
      final loc = post['location'];
      if (loc != null && loc['latitude'] != null && loc['longitude'] != null) {
        Color markerColor;

        // Handle filledDate
        if (post['filledDate'] != null) {
          final filledDate = post['filledDate'] is DateTime
              ? post['filledDate'] as DateTime
              : (post['filledDate'] as Timestamp).toDate();
          markerColor = DateTime.now().difference(filledDate).inDays > 5
              ? Colors.transparent
              : Colors.red;
        }
        // Handle dueDate
        else if (post['dueDate'] != null) {
          final dueDate = post['dueDate'] is DateTime
              ? post['dueDate'] as DateTime
              : (post['dueDate'] as Timestamp).toDate();
          markerColor = DateTime.now().isBefore(dueDate) ? Colors.yellow : Colors.green;
        }
        // Default vacant
        else {
          markerColor = Colors.green;
        }

        final marker = Marker(
          key: ValueKey(post['id']),
          point: LatLng(loc['latitude'], loc['longitude']),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedPostId = post['id']);
              // You can show bottom sheet or popup for the post here
            },
            child: Icon(
              Icons.location_on,
              color: markerColor,
              size: 40,
            ),
          ),
        );

        markers.add(marker);
        _postsById[post['id']] = post;
      }
    }

    setState(() => _postMarkers = markers);
  }

  void _goToCurrentLocation() {
    if (_currentLocation == null) return;
    final latLng = LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!);
    _mapController.move(latLng, 16);
  }

  void _resetMapRotation() {
    _mapController.rotate(0);
  }

  @override
  Widget build(BuildContext context) {
    final center = _currentLocation != null
        ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
        : _defaultCenter;

    final markers = <Marker>[
      if (_currentLocation != null)
        Marker(
          point: center,
          width: 40,
          height: 40,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
        ),
      ..._postMarkers,
    ];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              onPositionChanged: (pos, _) {},
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.basobaas',
              ),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
            ],
          ),
          // Current location button
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _goToCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          // Compass button
          Positioned(
            bottom: 90,
            right: 16,
            child: FloatingActionButton(
              onPressed: _resetMapRotation,
              child: const Icon(Icons.explore),
            ),
          ),
        ],
      ),
    );
  }
}
