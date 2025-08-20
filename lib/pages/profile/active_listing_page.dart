import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:basobaas_map/provider/post_provider.dart';
import 'package:basobaas_map/provider/auth_provider.dart';
import '../../shared_widgets/post_card.dart';

class ActiveListingPage extends StatefulWidget {
  const ActiveListingPage({super.key});

  @override
  State<ActiveListingPage> createState() => _ActiveListingPageState();
}

class _ActiveListingPageState extends State<ActiveListingPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchActiveListings();
  }

  Future<void> _fetchActiveListings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    final uid = authProvider.user?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    await postProvider.fetchActiveListings(uid);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Active Listings"), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<PostProvider>(
        builder: (context, postProvider, _) {
          if (postProvider.activeListings.isEmpty) {
            return const Center(child: Text("No active listings yet."));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: postProvider.activeListings.length,
            itemBuilder: (context, index) {
              final post = postProvider.activeListings[index];

              return PostCard(
                post: post,
                onToggle: () async {
                  final filled = post['filledDate'] == null;
                  await postProvider.toggleFilled(post['id'], filled);

                  // refresh listings immediately
                  await _fetchActiveListings();
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchActiveListings,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
