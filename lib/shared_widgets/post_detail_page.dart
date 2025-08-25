import 'dart:io';
import 'package:basobaas_map/pages/profile/edit_post_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:carousel_slider/carousel_slider.dart';

import 'fullscreen_image_viewer.dart';

class PostDetailPage extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool canEdit;
  final ScrollController? scrollController;
  final bool showAppBar;
  const PostDetailPage({
    super.key,
    required this.post,
    this.canEdit = false,
    this.scrollController,
    this.showAppBar=true,
  });

  // =========================
  // Date formatting
  // =========================
  String _formatDate(dynamic value) {
    if (value == null) return '-';
    DateTime dt;

    if (value is Timestamp) {
      dt = value.toDate();
    } else if (value is DateTime) {
      dt = value;
    } else if (value is String) {
      dt = DateTime.tryParse(value) ?? DateTime.now();
    } else {
      return '-';
    }

    return "${_monthName(dt.month)} ${dt.day}, ${dt.year}";
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final LatLng loc = LatLng(
      post['location']['latitude'],
      post['location']['longitude'],
    );
    final currentIndex = ValueNotifier<int>(0);

    Color statusColor() {
      switch (post['status']) {
        case 'To Be Vacant':
          return Colors.orange;
        case 'Rented':
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
          Text(
            "$label (${sizes.length})",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
      appBar: showAppBar? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(post['title'] ?? '', style: const TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (canEdit) // only show edit button if allowed
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () {
                // Navigate to EditPostPage
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_)=>EditPostPage(post: post),
                    ),
                );
              },
            ),
        ],
      ): null,
      body: SafeArea(
        child: ListView(
          controller: scrollController ?? ScrollController(),
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
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
                              builder: (_) => FullScreenGallery(
                                images: post['images'],
                                initialIndex: index,
                              ),
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
                      onPageChanged: (index, reason) => currentIndex.value = index,
                    ),
                  ),
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

            // Property type
            if (post['propertyType'] != null) ...[
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Property Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: '${post['propertyType'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.normal)),
                  ],
                ),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
            ],

            // Price & Status
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Price: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: 'RS ${post['price'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.normal)),
                  if (post['negotiable'] == true) const TextSpan(text: ' (Negotiable)', style: TextStyle(fontStyle: FontStyle.italic)),
                ],
              ),
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor(), borderRadius: BorderRadius.circular(8)),
                  child: Text(post['status'] ?? '-', style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),

            // Status-dependent dates
            if (post['status'] == 'To Be Vacant' && post['availableFrom'] != null) ...[
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'To Be Available From: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: _formatDate(post['availableFrom']),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ],
            if (post['status'] == 'Rented' && post['rentedSince'] != null) ...[
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Rented Since: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: _formatDate(post['rentedSince']),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ],


            // Room/Hall/Kitchen sizes
            _sizesList('Rooms', post['roomSizes'] ?? []),
            _sizesList('Halls', post['hallSizes'] ?? []),
            _sizesList('Kitchens', post['kitchenSizes'] ?? []),

            // Floor
            if (post['floor'] != null)
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Floor: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: post['floor'] ?? '-'),
                  ],
                ),
              ),

            // Bathroom & Parking
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Bathroom: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: post['bathroom'] ?? '-'),
                ],
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Parking: ', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  if (a is Map<String, dynamic>) return _chipList(a.map((k, v) => MapEntry(k, v == true)));
                  if (a is List) return _chipList(Map<String, bool>.fromIterable(List<String>.from(a), key: (v) => v.toString(), value: (_) => true));
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 12),
            ],

            // Nearby
            if (post['nearby'] != null) ...[
              const Text('Nearby Areas:', style: TextStyle(fontWeight: FontWeight.bold)),
              _chipList(Map<String, bool>.fromIterable(List<String>.from(post['nearby']), key: (v) => v.toString(), value: (_) => true)),
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
              const SizedBox(height: 6),
              const Text('Posted On:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_formatDate(post['createdAt'])),
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
                      urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName: "com.basobaas_map",
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
    );
  }
}
