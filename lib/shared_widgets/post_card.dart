import 'package:basobaas_map/shared_widgets/post_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onToggle;
  final Widget? trailing;

  const PostCard({
    super.key,
    required this.post,
    this.trailing,
    this.onToggle,
  });

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDate(dynamic value) {
    final date = _toDateTime(value);
    if (date == null) return '-';
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final images = post['images'] as List<dynamic>? ?? [];
    final imageUrl = images.isNotEmpty ? images[0] : null;

    final title = post['title'] ?? 'No Title';
    final price = post['price'] ?? '';

    final postStatus = post['status'] ?? 'Vacant';
    final rentedSince = postStatus == 'Rented' ? _toDateTime(post['rentedSince']) : null;
    final availableFrom = postStatus == 'To Be Vacant' ? _toDateTime(post['availableFrom']) : null;

    // Status color & toggle logic
    late Color statusColor;
    late bool showToggle;

    switch (postStatus) {
      case 'Rented':
        statusColor = Colors.red;
        showToggle = true;
        break;
      case 'To Be Vacant':
        statusColor = Colors.orange;
        showToggle = false;
        break;
      case 'Vacant':
      default:
        statusColor = Colors.green;
        showToggle = true;
        break;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailPage(post: post, canEdit: true),
          ),
        );
      },
      child: Card(
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
                child: Text(
                  'Image not found',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
          )
              : Container(
            width: 80,
            height: 80,
            color: Colors.grey[300],
            child: const Icon(Icons.home, size: 40),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Price: $price"),
              const SizedBox(height: 4),
              Text(
                "Status: $postStatus",
                style: TextStyle(color: statusColor),
              ),
              if (postStatus == 'To Be Vacant' && availableFrom != null) ...[
                const SizedBox(height: 4),
                Text(
                  "Available From: ${_formatDate(availableFrom)}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
              if (rentedSince != null) ...[
                const SizedBox(height: 4),
                Text(
                  "Rented Since: ${_formatDate(rentedSince)}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ],
          ),
          trailing: trailing ??
              (showToggle
                  ? IconButton(
                icon: Icon(
                  Icons.check_circle,
                  color: statusColor,
                ),
                onPressed: onToggle,
              )
                  : null),

        ),
      ),
    );
  }
}
