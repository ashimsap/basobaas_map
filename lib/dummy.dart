import 'package:flutter/material.dart';
final List<Map<String, dynamic>> dummyRooms = [
  {
    'title': 'Room in Koteshwor',
    'price': 6000,
    'location': 'Koteshwor',
    'image': 'assets/room1.jpg',
    'verified': true,
  },
  {
    'title': 'Flat in Pepsicola',
    'price': 8500,
    'location': 'Pepsicola',
    'image': 'assets/room2.jpg',
    'verified': false,
  },
];

class RoomCard extends StatelessWidget {
  final Map<String, dynamic> room;

  const RoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.asset(
              room['image'],
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${room['location']} • Rs ${room['price']} / mo'),
                const SizedBox(height: 6),
                if (room['verified'])
                  const Chip(
                    label: Text("Verified Owner", style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.green,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
