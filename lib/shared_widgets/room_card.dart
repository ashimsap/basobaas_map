import 'package:flutter/material.dart';

class RoomCard extends StatelessWidget {
  final Map<String, dynamic> room;

  const RoomCard({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    // Use the first image from the post images array
    final images = room['images'] as List<dynamic>? ?? [];
    final imageUrl = images.isNotEmpty ? images[0] : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: imageUrl != null
                ? Image.network(
              imageUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 160,
                  color: Colors.grey[300],
                  child: const Center(child: Icon(Icons.image, size: 40)),
                );
              },
            )
                : Container(
              height: 160,
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.image, size: 40)),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room['title'] ?? 'No Title',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${room['location'] ?? 'Unknown'} • Rs ${room['price'] ?? '-'} / mo',
                ),
                const SizedBox(height: 6),
                if (room['verified'] == true)
                  const Chip(
                    label: Text("Verified Owner", style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.green,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
