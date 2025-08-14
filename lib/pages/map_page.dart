import 'package:flutter/material.dart';

import '../services/map.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const MapWidget(),
    );
  }
}
