import 'package:basobaas_map/pages/home_page.dart';
import 'package:basobaas_map/pages/map_page.dart';
import 'package:basobaas_map/pages/post_page.dart';
import 'package:basobaas_map/pages/profile/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/auth_provider.dart';


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
  void _showVerifyDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Verification Required"),
        content: const Text(
          "You need to verify your account before posting a rental.\n\n"
              "Go to your profile page and complete verification.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 3); // redirect to Profile tab
            },
            child: const Text("Go to Profile"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == 2 && !authProvider.isVerified()) {
            // Trying to go to PostPage while unverified
            _showVerifyDialog();
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
}