import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/auth_provider.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final Map<int, TextEditingController> _phoneControllers = {};
  final Map<String, TextEditingController> _socialControllers = {};
  final TextEditingController _secondaryEmailController = TextEditingController();
  bool _addingNewPhone = false;

  @override
  void dispose() {
    _secondaryEmailController.dispose();
    for (var ctrl in _phoneControllers.values) ctrl.dispose();
    for (var ctrl in _socialControllers.values) ctrl.dispose();
    super.dispose();
  }

  Widget _buildPhoneRow(AuthProvider authProvider, int index) {
    final phone = index < authProvider.phones.length ? authProvider.phones[index] : '';
    _phoneControllers[index] ??= TextEditingController(text: phone);

    final isEditing = phone.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text('Phone ${index + 1}: +977 - ', style: const TextStyle(fontSize: 16)),
          Expanded(
            child: isEditing
                ? TextField(
              controller: _phoneControllers[index],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter phone number',
              ),
            )
                : Text(phone, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              final value = _phoneControllers[index]?.text.trim();
              if (value != null && value.isNotEmpty) {
                if (index < authProvider.phones.length) {
                  await authProvider.updatePhone(index, value);
                } else {
                  await authProvider.addPhone(value);
                  _addingNewPhone = false;
                }
                setState(() {});
              }
            },
            child: Text(isEditing ? 'Save' : 'Edit'),
          ),
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                authProvider.removePhone(index);
                _phoneControllers[index]?.clear();
                setState(() {});
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSocialRow(AuthProvider authProvider, String platform) {
    final value = authProvider.socialMedia[platform] ?? '';
    _socialControllers[platform] ??= TextEditingController(text: value);

    final isEditing = value.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text('$platform: ', style: const TextStyle(fontSize: 16)),
          Expanded(
            child: isEditing
                ? TextField(
              controller: _socialControllers[platform],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter profile URL',
              ),
            )
                : Text(value, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              final val = _socialControllers[platform]?.text.trim();
              if (val != null && val.isNotEmpty) {
                await authProvider.setSocialMedia(platform, val);
                setState(() {});
              }
            },
            child: Text(isEditing ? 'Save' : 'Edit'),
          ),
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                authProvider.removeSocialMedia(platform);
                _socialControllers[platform]?.clear();
                setState(() {});
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    _secondaryEmailController.text = authProvider.secondaryEmail ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Contact Info'), centerTitle: true,),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Primary Email
          const Text('Primary Email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(authProvider.user?.email ?? '', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 12),

          // Secondary Email
          const Text('Secondary Email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _secondaryEmailController,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final val = _secondaryEmailController.text.trim();
                  if (val.isNotEmpty) await authProvider.setSecondaryEmail(val);
                  setState(() {});
                },
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Phone Numbers
          const Text('Phone Numbers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...List.generate(authProvider.phones.length, (i) => _buildPhoneRow(authProvider, i)),
          if (_addingNewPhone)
            _buildPhoneRow(authProvider, authProvider.phones.length),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _addingNewPhone = true;
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add phone number'),
          ),
          const SizedBox(height: 16),

          // Social Media
          const Text('Social Media', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...['Facebook', 'Instagram', 'Twitter'].map((p) => _buildSocialRow(authProvider, p)),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Text.rich(
                    TextSpan(
                      text: "Disclaimer: ",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      children: [
                        TextSpan(
                          text:
                          "The contact details you provide (email, phone numbers, and social media links) "
                              "will be attached to your rental postings. Other users will be able to view this "
                              "information to reach out regarding your listings. Please only share details you "
                              "are comfortable making public.",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                            color: Colors.red.withAlpha(200),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Row(
            children: [
              Icon(Icons.help_outline),
              SizedBox(width: 10,),
              Expanded(child: Text(
                "Your contact details will be shown on your rental ads so interested renters can contact you directly.",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),

              )
              ),
            ],
          ),

        ]),
      ),
    );
  }
}
