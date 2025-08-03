import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Profile picture
              CircleAvatar(
                radius: 60,
                backgroundImage: NetworkImage(
                  'https://i.pravatar.cc/150?img=3', // sample avatar image
                ),
              ),
              const SizedBox(height: 16),
        
              // User name
              const Text(
                'Ashim Sapkota',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
        
              const SizedBox(height: 8),
        
              // Email
              const Text(
                'ashim.sapkota@example.com',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
        
              const SizedBox(height: 24),
        
              // Editable info fields example
              TextFormField(
                initialValue: 'Bachelor of Information Technology',
                decoration: const InputDecoration(
                  labelText: 'Course',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school),
                ),
              ),
        
              const SizedBox(height: 16),
        
              TextFormField(
                initialValue: '+977 98XXXXXXXX',
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
        
              const Spacer(),
        
              // Logout button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Add logout logic
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
