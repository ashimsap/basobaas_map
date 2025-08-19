import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:carousel_slider/carousel_slider.dart';

import '../shared_widgets/fullscreen_image_viewer.dart';

class PostDetailPage extends StatelessWidget {
  final Map<String, dynamic> post;
  const PostDetailPage({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final LatLng loc = LatLng(
      post['location']['latitude'],
      post['location']['longitude'],
    );

    Color statusColor() {
      switch (post['status']) {
        case 'ToBeVacant':
          return Colors.orange;
        case 'Filled':
          return Colors.red;
        default:
          return Colors.green;
      }
    }

    Widget _chipList(Map<String, bool> items) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: items.entries
            .where((e) => e.value == true)
            .map((e) => Chip(label: Text(e.key)))
            .toList(),
      );
    }

    Widget _sizesList(String label, List<dynamic> sizes) {
      if (sizes.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...sizes.map((s) {
            final width = s['width']?.toString() ?? '-';
            final length = s['length']?.toString() ?? '-';
            return Text('$width ft x $length ft');
          }).toList(),
          const SizedBox(height: 8),
        ],
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true, // images go behind app bar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(post['title'] ?? '', style: const TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14,0,14,14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Images Carousel
              if (post['images'] != null && post['images'].isNotEmpty)
                CarouselSlider(
                  items: List<Widget>.from(post['images'].map<Widget>((img) {
                    final index = post['images'].indexOf(img);
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenGallery(images: post['images'], initialIndex: index),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: img.toString().startsWith('http')
                            ? Image.network(img, fit: BoxFit.cover, width: double.infinity)
                            : Image.file(File(img), fit: BoxFit.cover, width: double.infinity),
                      ),
                    );
                  })),
                  options: CarouselOptions(
                    height: 220,
                    viewportFraction: 1.0,
                    enableInfiniteScroll: false,
                  ),
                ),

              const SizedBox(height: 12),

              // Title & Description
              Text(post['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(post['description'] ?? '', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),

              // Price & Status
              Text(
                'Price: Rs ${post['price'] ?? '-'} ${post['negotiable'] == true ? "(Negotiable)" : ""}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor(),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(post['status'] ?? '-', style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Room/Hall/Kitchen sizes
              _sizesList('Rooms', post['roomSizes'] ?? []),
              _sizesList('Halls', post['hallSizes'] ?? []),
              _sizesList('Kitchens', post['kitchenSizes'] ?? []),

              // Bathroom & Parking
              Text('Bathroom: ${post['bathroom'] ?? '-'}'),
              Text('Parking: ${post['parking'] ?? '-'}'),
              const SizedBox(height: 12),

              // Amenities
              if (post['amenities'] != null) ...[
                const Text('Amenities:', style: TextStyle(fontWeight: FontWeight.bold)),
                _chipList(Map<String, bool>.from(post['amenities'])),
                const SizedBox(height: 12),
              ],

              // Nearby
              if (post['nearby'] != null) ...[
                const Text('Nearby Areas:', style: TextStyle(fontWeight: FontWeight.bold)),
                _chipList(Map<String, bool>.fromIterable(
                  List<String>.from(post['nearby']),
                  key: (v) => v.toString(),
                  value: (_) => true,
                )),
                const SizedBox(height: 12),
              ],

              // Notes
              if ((post['notes'] ?? '').toString().isNotEmpty) ...[
                const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(post['notes']),
                const SizedBox(height: 12),
              ],

              // Contact
              if (post['contact'] != null) ...[
                const Text('Contact:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Name: ${post['contact']['name'] ?? '-'}'),
                Text('Email: ${post['contact']['email'] ?? '-'}'),
                const SizedBox(height: 12),
              ],

              // Location (static map)
              if ((post['typedAddress'] ?? '').isNotEmpty) ...[
                const Text('Address:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(post['typedAddress']),
                const SizedBox(height: 6),
              ],
              const Text('Location:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              SizedBox(
                height: 220,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: loc,
                    initialZoom: 15,
                    interactionOptions:  InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.basobaas',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: loc,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
