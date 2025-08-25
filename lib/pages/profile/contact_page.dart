import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/auth_provider.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  bool _editing = false;

  late TextEditingController _secondaryEmailController;
  late TextEditingController _aboutController;
  final List<TextEditingController> _phoneControllers = [];
  final Map<String, TextEditingController> _socialControllers = {};

  @override
  void initState() {
    super.initState();
    _secondaryEmailController = TextEditingController();
    _aboutController = TextEditingController();
  }

  @override
  void dispose() {
    _secondaryEmailController.dispose();
    _aboutController.dispose();
    for (var c in _phoneControllers) c.dispose();
    for (var c in _socialControllers.values) c.dispose();
    super.dispose();
  }

  void _startEditing(AuthProvider auth) {
    setState(() {
      _editing = true;

      _secondaryEmailController.text = auth.secondaryEmail ?? '';
      _aboutController.text = auth.about ?? '';

      _phoneControllers.clear();
      for (var p in auth.phones) {
        _phoneControllers.add(TextEditingController(text: p));
      }

      for (var platform in ['Facebook', 'Instagram', 'Twitter']) {
        _socialControllers[platform] ??= TextEditingController(
          text: auth.socialMedia[platform] ?? '',
        );
      }
    });
  }

  void _cancelEditing() {
    setState(() => _editing = false);
  }

  Future<void> _saveEditing(AuthProvider auth) async {
    // Secondary email
    await auth.setSecondaryEmail(_secondaryEmailController.text.trim());

    // Phones
    List<String> newPhones = [];
    for (var c in _phoneControllers) {
      if (c.text.trim().isNotEmpty) newPhones.add(c.text.trim());
    }
    await auth.setPhones(newPhones);

    // Social Media
    for (var platform in _socialControllers.keys) {
      final val = _socialControllers[platform]?.text.trim() ?? '';
      if (val.isNotEmpty) {
        await auth.setSocialMedia(platform, val);
      } else {
        await auth.removeSocialMedia(platform);
      }
    }

    // About
    await auth.setAbout(_aboutController.text.trim());

    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Contact Info"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _editing ? _buildEditUI(auth) : _buildViewUI(auth),
      ),
      floatingActionButton: !_editing
          ? FloatingActionButton.extended(
        onPressed: () => _startEditing(auth),
        label: const Text('Edit'),
        icon: const Icon(Icons.edit),
      )
          : null,

    );
  }

  /// VIEW MODE
  Widget _buildViewUI(AuthProvider auth) {
    return Column(
      children: [
        _buildInfoCard(
          icon: Icons.email,
          title: "Primary Email",
          subtitle: auth.email ?? "Not set",
        ),
        _buildInfoCard(
          icon: Icons.alternate_email,
          title: "Secondary Email",
          subtitle: auth.secondaryEmail ?? "Not set",
        ),
        _buildPhonesCard(auth),
        _buildSocialCard(auth),
        _buildInfoCard(
          icon: Icons.info,
          title: "About",
          subtitle: auth.about ?? "Not set",
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _buildPhonesCard(AuthProvider auth) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.phone, color: Colors.green),
        title: const Text(
          "Phone Numbers",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: auth.phones.isEmpty
            ? [const ListTile(title: Text("Not set"))]
            : auth.phones
            .map(
              (p) => ListTile(
            leading: const Icon(Icons.phone),
            title: Text("+977 $p"),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildSocialCard(AuthProvider auth) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.people, color: Colors.purple),
        title: const Text(
          "Social Media",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: auth.socialMedia.isEmpty
            ? [const ListTile(title: Text("Not set"))]
            : auth.socialMedia.entries
            .map(
              (e) => ListTile(
            leading: Icon(_iconForPlatform(e.key)),
            title: Text(e.key),
            subtitle: Text(e.value),
          ),
        )
            .toList(),
      ),
    );
  }

  IconData _iconForPlatform(String platform) {
    switch (platform) {
      case 'Facebook':
        return Icons.facebook;
      case 'Instagram':
        return Icons.camera_alt;
      case 'Twitter':
        return Icons.alternate_email;
      default:
        return Icons.link;
    }
  }

  /// EDIT MODE
  Widget _buildEditUI(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Secondary Email",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        TextField(
          controller: _secondaryEmailController,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),

        const Text(
          "Phone Numbers",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...List.generate(_phoneControllers.length, (i) => _buildPhoneField(i)),
        TextButton.icon(
          onPressed: () =>
              setState(() => _phoneControllers.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: const Text("Add Phone"),
        ),
        const SizedBox(height: 16),

        const Text(
          "Social Media",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...[
          'Facebook',
          'Instagram',
          'Twitter',
        ].map((platform) => _buildSocialField(platform)),
        const SizedBox(height: 16),

        const Text("About", style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _aboutController,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: _cancelEditing, child: const Text("Cancel")),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _saveEditing(auth),
              child: const Text("Save"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhoneField(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _phoneControllers[index],
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Phone",
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => setState(() => _phoneControllers.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialField(String platform) {
    _socialControllers[platform] ??= TextEditingController();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: _socialControllers[platform],
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: platform,
        ),
      ),
    );
  }
}
