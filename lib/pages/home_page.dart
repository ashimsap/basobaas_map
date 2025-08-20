import 'package:basobaas_map/shared_widgets/post_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:basobaas_map/provider/post_provider.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    setState(() => _isLoading = true);
    await postProvider.fetchAllPosts(); // fetch all posts from Firestore
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {_fetchPosts();},
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔍 Search Bar
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Room khojdai ho?...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              // 🏷️ Filter Chips
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: const [
                    Chip(label: Text("Room")),
                    Chip(label: Text("Flat")),
                    Chip(label: Text("Hostel")),
                    Chip(label: Text("Verified")),
                    Chip(label: Text("Low to High")),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 🏘️ Post Cards
              Expanded(
                child: Consumer<PostProvider>(
                  builder: (context, postProvider, _) {
                    if (_isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (postProvider.allPosts.isEmpty) {
                      return const Center(child: Text("No posts yet."));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: postProvider.allPosts.length,
                      itemBuilder: (context, index) {
                        final post = postProvider.allPosts[index];
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
                                  children:[
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    child: Image.network(
                                      firstImage,
                                      height: 160,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        height: 160,
                                        color: Colors.grey[300],
                                        child: const Center(child: Icon(Icons.image, size: 40)),
                                      ),
                                    ),
                                  ),

                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  backgroundColor: Colors.black45,
                                  child: IconButton(
                                    icon: Icon(
                                      post['isSaved'] == true ? Icons.favorite : Icons.favorite_border,
                                      color: post['isSaved'] == true ? Colors.red : Colors.white,
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
                              // post info
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
