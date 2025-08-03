import 'package:flutter/material.dart';

import '../services/map.dart';

class MapPage extends StatelessWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const MapWidget(),
    );
  }
}
