import 'package:flutter/material.dart';
import 'package:basobaas_map/dummy.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
                  Chip(label: Text("Flat") ),
                  Chip(label: Text("Hostel")),
                  Chip(label: Text("Verified")),
                  Chip(label: Text("Low to High")),
                ],
              ),
            ),
        
            const SizedBox(height: 12),
        
            // 🏘️ Room Cards
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: dummyRooms.length,
                itemBuilder: (context, index) {
                  final room = dummyRooms[index];
                  return RoomCard(room: room);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
