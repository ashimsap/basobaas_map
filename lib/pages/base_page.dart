import 'package:basobaas_map/pages/home_page.dart';
import 'package:basobaas_map/pages/map_page.dart';
import 'package:basobaas_map/pages/post_page.dart';
import 'package:basobaas_map/pages/profile/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/post_provider.dart';


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
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (i) async{ setState(() => _currentIndex = i);
        /*if (i == 1) { // assuming index 0 is the map tab
          final postProvider = Provider.of<PostProvider>(context, listen: false);
          await postProvider.refreshMarkers(); // refresh markers on tab change
        }*/
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
