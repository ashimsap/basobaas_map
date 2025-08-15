import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final Location _locationService = Location();
  LocationData? _currentLocation;
  bool _permissionGranted = false;

  static final LatLng _defaultCenter = LatLng(27.7172, 85.3240); // Kathmandu
  late final MapController _mapController;
  final TextEditingController _searchController = TextEditingController();

  double _mapRotation = 0.0;
  List<CircleMarker> _searchMarkers = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initLocation();
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

  void _goToCurrentLocation() {
    if (_currentLocation == null) return;
    final latLng = LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!);
    _mapController.move(latLng, 16);
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
    );
    final response = await http.get(uri, headers: {'User-Agent': 'basobaas-app'});

    if (response.statusCode == 200) {
      final results = json.decode(response.body);
      if (results.isNotEmpty) {
        final lat = double.parse(results[0]['lat']);
        final lon = double.parse(results[0]['lon']);
        final searchedLatLng = LatLng(lat, lon);

        _mapController.move(searchedLatLng, 16);

        setState(() {
          _searchMarkers = [
            CircleMarker(
              point: searchedLatLng,
              radius: 200, // radius in meters
              color: Colors.blue.withOpacity(0.2),
              borderStrokeWidth: 2,
              borderColor: Colors.blue,
            ),
          ];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not found')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching location')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              initialRotation: _mapRotation,
              interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.basobaas',
              ),
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              if (_searchMarkers.isNotEmpty)
                CircleLayer(circles: _searchMarkers),
            ],
          ),

          // Search bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search location',
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchMarkers = []);
                      },
                    ),
                  ),
                  onSubmitted: _searchLocation,
                ),
              ),
            ),
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
              onPressed: (){
                _mapController.rotate(0);
              },
              child: const Icon(Icons.explore),
            ),
          ),
        ],
      ),
    );
  }
}
