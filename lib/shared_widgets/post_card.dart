import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:basobaas_map/provider/post_provider.dart';

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onToggle;

  const PostCard({super.key, required this.post, this.onToggle});

  DateTime? _toDateTime(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final images = post['images'] as List<dynamic>? ?? [];
    final imageUrl = images.isNotEmpty ? images[0] : null;

    final title = post['title'] ?? 'No Title';
    final price = post['price'] ?? '';

    final filledDate = _toDateTime(post['filledDate']);
    final dueDate = _toDateTime(post['dueDate']);

    String statusLabel;
    Color statusColor;

    if (filledDate != null) {
      statusLabel = 'Rented';
      statusColor = Colors.red;
    } else if (dueDate != null && DateTime.now().isBefore(dueDate)) {
      statusLabel = 'To be available from ${DateFormat('yyyy-MM-dd').format(dueDate)}';
      statusColor = Colors.yellow;
    } else {
      statusLabel = 'Vacant';
      statusColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: imageUrl != null
            ? Image.network(
          imageUrl,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 80,
            height: 80,
            color: Colors.grey[300],
            child: const Center(
              child: Text('Image not found', style: TextStyle(color: Colors.black54)),
            ),
          ),
        )
            : Container(
          width: 80,
          height: 80,
          color: Colors.grey[300],
          child: const Icon(Icons.home, size: 40),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Price: $price"),
            const SizedBox(height: 4),
            Text("Status: $statusLabel", style: TextStyle(color: statusColor)),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            filledDate != null ? Icons.check_circle : Icons.radio_button_unchecked,
            color: statusColor,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
