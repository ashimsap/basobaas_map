import 'package:basobaas_map/pages/home_page.dart';
import 'package:basobaas_map/pages/map_page.dart';
import 'package:basobaas_map/pages/post_page.dart';
import 'package:basobaas_map/pages/profile/profile_page.dart';
import 'package:basobaas_map/provider/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomePage(),
    MapPage(),
    PostPage(),
    ProfilePage(),
  ];


  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (i) async {
          if (i == 2) {
            // Post tab
            await _handlePostTab(authProvider);
          } else {
            setState(() => _currentIndex = i);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Post'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Future<void> _handlePostTab(AuthProvider authProvider) async {
    bool emailVerified = authProvider.isEmailVerified;
    bool phoneAdded = authProvider.phones.isNotEmpty;

    if (emailVerified && phoneAdded) {
      setState(() => _currentIndex = 2); // allowed
      return;
    }

    // Build a simple message
    String message = '';
    if (!emailVerified && !phoneAdded) {
      message = "Please verify your account in the Profile page and add your contact details before posting a rental.";
    }
    // Show the alert dialog with a single Close button
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Account not Verified'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
