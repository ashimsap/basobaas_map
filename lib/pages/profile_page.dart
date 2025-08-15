import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'login/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage; // Holds picked image
  final ImagePicker _picker = ImagePicker();

  // Example user data (replace with your real data)
  final String fullName = "Ashim Sapkota";
  final String phoneNumber = "+977 9864073201";
  final bool isPhoneVerified = true;
  final String email = "ashimsap@gmail.com";
  final String verificationStatus = "Verified Owner";
  final int activeListings = 3;
  final int savedRentals = 5;

  Future<void> _pickImage() async {
    final XFile? pickedFile =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Customizable Profile Picture
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : const NetworkImage(
                      'https://scontent.fktm19-1.fna.fbcdn.net/v/t39.30808-6/328896197_580658850616398_4946101284792458931_n.jpg')
                  as ImageProvider,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Full Name
            Text(
              fullName,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Phone Number with verification badge
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  phoneNumber,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                if (isPhoneVerified)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.check_circle,
                            color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "Verified",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
              ],
            ),
            const SizedBox(height: 8),

            // Email
            Text(
              email,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),

            // Verification Status
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user, color: Colors.blue[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  verificationStatus,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Info Cards
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: Colors.orange.withOpacity(0.1),
              child: ListTile(
                leading: const Icon(Icons.home, color: Colors.orange),
                title: const Text("Active Listings",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("$activeListings Listings"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to Manage Listings page
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: Colors.redAccent.withOpacity(0.1),
              child: ListTile(
                leading: const Icon(Icons.favorite, color: Colors.redAccent),
                title: const Text("Saved Rentals",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("$savedRentals Rentals"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to Favorites page
                },
              ),
            ),

            const SizedBox(height: 24),

            // Contact Preferences Button
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.settings),
              label: const Text("Contact Preferences"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Edit Profile Button
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit),
              label: const Text("Edit Profile"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
