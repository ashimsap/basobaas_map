  /*
      //Intro or instruction

      showDialog(
       context: context,
      builder: (context) => const PopupDialog(
      title: "Welcome!",
      message: "Thanks for installing our app. Here's how to get started...",
      confirmText: "Got it",
      ),
      );
*/

  /*

  ✅ How to integrate with PostPage

Wrap your app with ChangeNotifierProvider<PostProvider> (or MultiProvider).

In PostPage, call:

final postProvider = Provider.of<PostProvider>(context, listen: false);

await postProvider.postRental(
  metadata: postData, // Map from your UI
  images: _images,    // XFile list from image picker
  userId: auth.userId,
);


For active listings, fetch and display:

await postProvider.fetchActiveListings(auth.userId);

ListView.builder(
  itemCount: postProvider.activeListings.length,
  itemBuilder: (context, index) {
    final post = postProvider.activeListings[index];
    final filled = post['filledDate'] != null;
    return CheckboxListTile(
      value: filled,
      onChanged: (v) {
        postProvider.toggleFilled(post['id'], v!);
      },
      title: Text(post['title'] ?? ''),
      subtitle: filled
          ? Text('Filled on: ${(post['filledDate'] as Timestamp).toDate().toLocal().toString().split(' ').first}')
          : null,
    );
  },
);


For saved rentals, fetch and display similarly using fetchSavedRentals.
   */