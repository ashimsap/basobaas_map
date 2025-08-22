import 'package:basobaas_map/shared_widgets/post_detail_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:basobaas_map/provider/post_provider.dart';

import '../shared_widgets/advanced_filter_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    setState(() => _isLoading = true);
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await postProvider.fetchAllPosts(userId);
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchPosts,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 12),
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
                      itemCount: postProvider.filteredPosts.length,
                      itemBuilder: (context, index) {
                        final post = postProvider.filteredPosts[index];
                        return _buildPostCard(context, post);
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

  Widget _buildSearchBar() {
    final postProvider = context.watch<PostProvider>(); // watch for changes

    // Check if any filter is active for icon color
    bool isAnyFilterActive = postProvider.isFilterActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search + Filter row
        Row(
          children: [
            // Search field
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search, color: Colors.grey),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: "Room Khojdai Ho?",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onChanged: (val) {
                          postProvider.updateSearch(val);
                        },
                      ),
                    ),
                    // Clear button inside search
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          postProvider.updateSearch("");
                        },
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),

            // Advanced filter button outside search
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: Icon(
                  Icons.tune,
                  color: isAnyFilterActive ? Colors.blue : Colors.grey,
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const AdvancedFilterDrawer(),
                  );
                },
              ),
            ),
          ],
        ),

        // Horizontally scrollable filter chips
        SizedBox(
          height: 40,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Price filter
                FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Price"),
                      if (postProvider.isPriceAsc != null)
                        Icon(
                          postProvider.isPriceAsc! ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 16,
                        ),
                    ],
                  ),
                  selected: postProvider.isPriceAsc != null,
                  onSelected: (_) {
                    postProvider.togglePriceSort();
                  },
                ),
                const SizedBox(width: 8),

                // Recent filter
                FilterChip(
                  label: const Text("Recent"),
                  selected: postProvider.sortByRecent,
                  onSelected: (_) {
                    postProvider.toggleRecentSort();
                  },
                ),
                const SizedBox(width: 8),

                // Type filters: mutually exclusive
                ...["Room", "Flat", "Apartment", "Shared"].map((type) {
                  final isSelected = postProvider.typeFilter == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(type),
                      selected: isSelected,
                      onSelected: (_) {
                        postProvider.setTypeFilter(isSelected ? null : type);
                      },
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }




  Widget _buildPostCard(BuildContext context, Map<String, dynamic> post) {
    final images = post['images'] as List<dynamic>? ?? [];
    final firstImage = images.isNotEmpty ? images[0] : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          final userId = FirebaseAuth.instance.currentUser!.uid;
                          context.read<PostProvider>().toggleSavePost(post['id'], userId);
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  }
}
