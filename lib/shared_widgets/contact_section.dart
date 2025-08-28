import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // add to pubspec.yaml

class ContactSection extends StatelessWidget {
  final Map<String, dynamic> contact;

  const ContactSection({super.key, required this.contact});

  // ===== Launchers =====
  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('⚠️ Cannot launch phone: $phone');
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      debugPrint('⚠️ Cannot launch email: $email');
    }
  }

  Future<void> _launchSocial(String platform, String username) async {
    final trimmedUsername = username.trim();
    String url = '';

    switch (platform.toLowerCase()) {
      case 'facebook':
        url = 'https://www.facebook.com/$trimmedUsername';
        break;
      case 'instagram':
        url = 'https://www.instagram.com/$trimmedUsername/';
        break;
      case 'twitter':
      case 'x':
        url = 'https://twitter.com/$trimmedUsername';
        break;
      default:
        debugPrint('⚠️ Unknown platform: $platform');
        return;
    }

    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    } catch (e) {
      debugPrint('⚠️ Failed to launch $platform profile: $username. Error: $e');
    }
  }

  // ===== Social Icon mapping =====
  IconData _socialIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return FontAwesomeIcons.facebookF;
      case 'instagram':
        return FontAwesomeIcons.instagram;
      case 'twitter':
      case 'x':
        return FontAwesomeIcons.twitter;
      default:
        return Icons.link;
    }
  }
  Color _socialColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'instagram':
        return const Color(0xFFE1306C); // fallback if gradient fails
      case 'twitter':
      case 'x':
        return const Color(0xFF1DA1F2);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final phones = List<String>.from(contact['phones'] ?? []);
    final social = Map<String, dynamic>.from(contact['social'] ?? {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contact:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),

        if (contact['name'] != null) Text('Name: ${contact['name']}'),

        if (contact['email'] != null)
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 16, color: Colors.black),
              children: [
                const TextSpan(text: 'Email: '),
                TextSpan(
                  text: contact['email'],
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = () => _launchEmail(contact['email']),
                ),
              ],
            ),
          ),

        if (phones.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text("Phones:"),
          Wrap(
            spacing: 8,
            children: phones
                .map(
                  (p) => InkWell(
                onTap: () => _launchPhone(p),
                child: Chip(label: Text(p)),
              ),
            )
                .toList(),
          ),
        ],

        if (social.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text('Social:', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: social.entries
                .map(
                  (e) => InkWell(
                onTap: () => _launchSocial(e.key, e.value.toString()),
                child: Chip(
                  avatar: Icon(
                    _socialIcon(e.key),
                    size: 18,
                    color: _socialColor(e.key),
                  ),
                  label: Text(e.value.toString(), style: const TextStyle(color: Colors.black)),
                  backgroundColor: Colors.grey.shade300,
                ),
              ),
            )
                .toList(),
          ),
        ],
      ],
    );
  }
}
