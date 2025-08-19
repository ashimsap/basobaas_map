import 'dart:io';
import 'package:basobaas_map/pages/active_listing_page.dart';
import 'package:basobaas_map/pages/contact_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../provider/auth_provider.dart';
import '../provider/post_provider.dart';
import '../shared_widgets/popup.dart';
import 'login/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _profileImage = File(picked.path);
      });
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.setAvatar(picked);
      if (!success) {
        // handle upload failure
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload avatar')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final displayName = authProvider.displayName ?? "User Name";
    final email = authProvider.email ?? "user@example.com";
    final photoUrl = authProvider.photoURL;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Picture with ImagePicker
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : (photoUrl != null
                      ? NetworkImage(photoUrl)
                      : const AssetImage('assets/default_avatar.png')) as ImageProvider,
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
                      child: const Icon(Icons.edit, size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Name & Email
            Text(displayName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(email, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            const SizedBox(height: 24),

            //Verified user?
            authProvider.isVerified() ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user, color: Colors.blue[700], size: 24),
                const SizedBox(width: 8),
                const Text(
                  "Verified User",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ) : GestureDetector(
              onTap:() {
                  showDialog(
                    context: context,
                    builder: (context) => PopupDialog(
                      title: "Email Verification",
                      message: "Your email is not verified. Would you like us to send a verification link?",
                      confirmText: "Send",
                      onConfirm: () async {
                        bool sent = await authProvider.sendEmailVerification();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(sent ? "Verification email sent!" : "Failed to send email."),
                          ),
                        );
                      },
                      cancelText: "Later",
                    ),
                  );
                },

              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    "Account Not Verified",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Active Listings & Saved Rentals (example static)
            GestureDetector(
              onTap: (){
                Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ContactPage()),
                 );
                },
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.orange.withAlpha(10),
                child: ListTile(
                  leading: const Icon(Icons.contact_mail, color: Colors.green),
                  title: const Text("contact info", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text(""),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
            GestureDetector(
              onTap: (){
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ActiveListingPage()),
                );
              },
              child: Consumer<PostProvider>(
                  builder: (context, postProvider, _) {
                    final activeCount = postProvider.activeListings.length;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      color: Colors.orange.withOpacity(0.1),
                      child: ListTile(
                        leading: const Icon(Icons.home, color: Colors.orange),
                        title: const Text("Active Listings",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle:  Text("$activeCount Listings"),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  }
               ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.redAccent.withOpacity(0.1),
              child: ListTile(
                leading: const Icon(Icons.favorite, color: Colors.redAccent),
                title: const Text("Saved Rentals", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("5 Rentals"),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await authProvider.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );

              },
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
            ),
          ],
        ),
      ),
    );
  }
}
