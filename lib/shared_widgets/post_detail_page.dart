import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:carousel_slider/carousel_slider.dart';

import 'fullscreen_image_viewer.dart';

class PostDetailPage extends StatelessWidget {
  final Map<String, dynamic> post;
  const PostDetailPage({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final LatLng loc = LatLng(
      post['location']['latitude'],
      post['location']['longitude'],
    );
    final currentIndex = ValueNotifier<int>(0);


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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(post['title'] ?? '', style: const TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Images Carousel
              if (post['images'] != null && post['images'].isNotEmpty)
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    CarouselSlider.builder(
                      itemCount: post['images'].length,
                      itemBuilder: (context, index, realIndex) {
                        final img = post['images'][index];
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
                      },
                      options: CarouselOptions(
                        height: 220,
                        viewportFraction: 1.0,
                        enableInfiniteScroll: false,
                        onPageChanged: (index, reason) {
                          currentIndex.value = index;
                        },
                      ),
                    ),

                    // Dots Indicator
                    if (post['images'].length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ValueListenableBuilder(
                          valueListenable: currentIndex,
                          builder: (context, int index, _) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(post['images'].length, (i) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i == index ? Colors.white : Colors.white54,
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                  ],
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

              // Date
              if (post['availableFrom'] != null) ...[
                const Text('Available From:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(post['availableFrom'].toString()),
                const SizedBox(height: 12),
              ],
              if (post['filledSince'] != null) ...[
                Text(
                  "Filled Since: ${(post['filledSince'] is Timestamp)
                      ? (post['filledSince'] as Timestamp).toDate().toLocal().toString().split(' ').first
                      : post['filledSince'].toString()}",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 6),
              ],

              // Room/Hall/Kitchen sizes
              _sizesList('Rooms', post['roomSizes'] ?? []),
              _sizesList('Halls', post['hallSizes'] ?? []),
              _sizesList('Kitchens', post['kitchenSizes'] ?? []),

              // Bathroom & Parking
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Bathroom: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: post['bathroom'] ?? '-'),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Parking: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: post['parking'] ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Amenities
              if (post['amenities'] != null) ...[
                const Text('Amenities:', style: TextStyle(fontWeight: FontWeight.bold)),
                Builder(
                  builder: (_) {
                    final a = post['amenities'];
                    if (a is Map<String, dynamic>) {
                      // New posts: map
                      return _chipList(a.map((k, v) => MapEntry(k, v == true)));
                    } else if (a is List) {
                      // Old posts: list of strings
                      return _chipList(Map<String, bool>.fromIterable(
                        List<String>.from(a),
                        key: (v) => v.toString(),
                        value: (_) => true,
                      ));
                    } else {
                      return const SizedBox.shrink();
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],


              // Nearby (still list -> convert to map temporarily)
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

              // Address
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
                    interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
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
