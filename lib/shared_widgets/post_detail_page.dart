import 'dart:io';
import 'package:basobaas_map/pages/profile/edit_post_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:carousel_slider/carousel_slider.dart';

import 'contact_section.dart';
import 'fullscreen_image_viewer.dart';

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool canEdit;
  final ScrollController? scrollController;

  const PostDetailPage({
    super.key,
    required this.post,
    this.canEdit = false,
    this.scrollController,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {

  late Map<String, dynamic> post;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    post = widget.post;
  }

  Future<void> _refreshPost() async {
    if (post['id'] == null) return;
    setState(() => isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(post['id'])
          .get();
      if (doc.exists) {
        setState(() {
          post = doc.data()!;
        });
      }
    } catch (e) {
      debugPrint("Error refreshing post: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }
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
      widget.post['location']['latitude'],
      widget.post['location']['longitude'],
    );
    final currentIndex = ValueNotifier<int>(0);

    Color statusColor() {
      switch (widget.post['status']) {
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

    return SafeArea(
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _refreshPost,
          child: ListView(
            controller: widget.scrollController ?? ScrollController(),
            padding: EdgeInsets.all(9),
            children: [
              // Images Carousel
              if (widget.post['images'] != null && widget.post['images'].isNotEmpty)
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    CarouselSlider.builder(
                      itemCount: widget.post['images'].length,
                      itemBuilder: (context, index, realIndex) {
                        final img = widget.post['images'][index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullScreenGallery(
                                  images: widget.post['images'],
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
                    if (widget.post['images'].length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ValueListenableBuilder(
                          valueListenable: currentIndex,
                          builder: (context, int index, _) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(widget.post['images'].length, (i) {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.post['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                  if (widget.canEdit)
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: (){
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditPostPage(postData: widget.post, postId: widget.post['id']),
                          ),
                        );
                      },
                    )

                ],
              ),
              const SizedBox(height: 6),
              Text(widget.post['description'] ?? '', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              ///--------status & date----------
              Row(
                children: [
                  const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor(), borderRadius: BorderRadius.circular(8)),
                    child: Text(widget.post['status'] ?? '-', style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),

              // Status-dependent dates
              if (widget.post['status'] == 'To Be Vacant' && widget.post['availableFrom'] != null) ...[
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'To Be Available From: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: _formatDate(widget.post['availableFrom']),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              if (widget.post['status'] == 'Rented' && widget.post['rentedSince'] != null) ...[
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Rented Since: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: _formatDate(widget.post['rentedSince']),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              SizedBox(height: 8,),


              // Property type
              if (widget.post['propertyType'] != null) ...[
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Property Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: '${widget.post['propertyType'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.normal)),
                    ],
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
              ],

              // Room/Hall/Kitchen sizes
              _sizesList('Rooms', widget.post['roomSizes'] ?? []),
              _sizesList('Halls', widget.post['hallSizes'] ?? []),
              _sizesList('Kitchens', widget.post['kitchenSizes'] ?? []),

              // Price & Status
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Price: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: 'Rs.${widget.post['price'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.normal)),
                    if (widget.post['negotiable'] == true) const TextSpan(text: ' (Negotiable)', style: TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 6),
              // Floor
              if (widget.post['floor'] != null)
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Floor: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: widget.post['floor'] ?? '-'),
                    ],
                  ),
                ),

              // Bathroom & Parking
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Bathroom: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: widget.post['bathroom'] ?? '-'),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Parking: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: widget.post['parking'] ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              //parking

              // Amenities
              if (widget.post['amenities'] != null) ...[
                const Text('Amenities:', style: TextStyle(fontWeight: FontWeight.bold)),
                Builder(
                  builder: (_) {
                    final a = widget.post['amenities'];
                    if (a is Map<String, dynamic>) return _chipList(a.map((k, v) => MapEntry(k, v == true)));
                    if (a is List) return _chipList(Map<String, bool>.fromIterable(List<String>.from(a), key: (v) => v.toString(), value: (_) => true));
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Nearby
              if (widget.post['nearby'] != null) ...[
                const Text('Nearby Areas:', style: TextStyle(fontWeight: FontWeight.bold)),
                _chipList(Map<String, bool>.fromIterable(List<String>.from(widget.post['nearby']), key: (v) => v.toString(), value: (_) => true)),
                const SizedBox(height: 12),
              ],

              // Notes
              if ((widget.post['notes'] ?? '').toString().isNotEmpty) ...[
                const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.post['notes']),
                const SizedBox(height: 12),
              ],

              // Contact section
              if (widget.post['contact'] != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: ContactSection(contact: widget.post['contact']),
                ),


              const SizedBox(height: 6),
              const Text('Posted On:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_formatDate(widget.post['createdAt'])),
              const SizedBox(height: 12),


              // Address
              if ((widget.post['typedAddress'] ?? '').isNotEmpty) ...[
                const Text('Address:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.post['typedAddress']),
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
      ),
    );
  }
}
