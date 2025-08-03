import 'package:flutter/material.dart';

import 'login_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Example user data (replace with your real data)
    final String fullName = "Ashim Sapkota";
    final String phoneNumber = "+977 9800000000";
    final bool isPhoneVerified = true;
    final String email = "ashim@example.com";
    final String verificationStatus = "Verified Owner";
    final int activeListings = 3;
    final int savedRentals = 5;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[300],
              backgroundImage: NetworkImage('https://scontent.fktm8-1.fna.fbcdn.net/v/t39.30808-6/328896197_580658850616398_4946101284792458931_n.jpg?_nc_cat=102&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=GGcL4LDsA_8Q7kNvwHxYOcy&_nc_oc=AdmJKkleJTQXuRYlnab74NOWHEo8k7Ik6JCJeIR7XAv6mACAMNwOiQCozPGizwDX5VN8yMcKLSACKDZuzNTx5QK4&_nc_zt=23&_nc_ht=scontent.fktm8-1.fna&_nc_gid=vH20_mJlC_TknlsRqA7n5A&oh=00_AfS6aJS42ZmicNJNBLbsI7kuGjVN-KZsrxTk7LRIlrLEAw&oe=6895275D'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
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

            // Info Cards - alternative
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.orange.withOpacity(0.1),
              child: ListTile(
                leading: const Icon(Icons.home, color: Colors.orange),
                title: const Text("Active Listings", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("$activeListings Listings"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to Manage Listings page
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.redAccent.withOpacity(0.1),
              child: ListTile(
                leading: const Icon(Icons.favorite, color: Colors.redAccent),
                title: const Text("Saved Rentals", style: TextStyle(fontWeight: FontWeight.bold)),
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
              onPressed: () {
                // Open contact preferences/settings
              },
              icon: const Icon(Icons.settings),
              label: const Text("Contact Preferences"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Edit Profile Button
            OutlinedButton.icon(
              onPressed: () {
                // Navigate to Edit Profile page
              },
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
                // Open contact preferences/settings
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
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
