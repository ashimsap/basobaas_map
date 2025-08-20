import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:basobaas_map/provider/post_provider.dart';
import 'package:basobaas_map/shared_widgets/post_detail_page.dart';

class SavedRentalsPage extends StatelessWidget {
  const SavedRentalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Saved Rentals"),
      centerTitle: true,),
      body: Consumer<PostProvider>(
        builder: (context, postProvider, _) {
          final saved = postProvider.savedRentals;
          if (saved.isEmpty) {
            return const Center(child: Text("No saved rentals yet."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: saved.length,
            itemBuilder: (context, index) {
              final post = saved[index];
              final images = post['images'] as List<dynamic>? ?? [];
              final firstImage = images.isNotEmpty ? images[0] : null;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailPage(post: post),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (firstImage != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: Image.network(
                                firstImage,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black45,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.favorite,
                                    color: Colors.red,
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    context.read<PostProvider>().toggleSavePost(post['id']);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(post['title'] ?? "No Title",
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(post['description'] ?? ""),
                            const SizedBox(height: 6),
                            Text("Rs ${post['price'] ?? 'N/A'} / mo",
                                style: const TextStyle(fontWeight: FontWeight.bold)),

                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
