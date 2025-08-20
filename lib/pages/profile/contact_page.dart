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
  final List<TextEditingController> _phoneControllers = [];
  final Map<String, TextEditingController> _socialControllers = {};

  @override
  void initState() {
    super.initState();
    _secondaryEmailController = TextEditingController();
  }

  @override
  void dispose() {
    _secondaryEmailController.dispose();
    for (var c in _phoneControllers) c.dispose();
    for (var c in _socialControllers.values) c.dispose();
    super.dispose();
  }

  void _startEditing(AuthProvider authProvider) {
    setState(() {
      _editing = true;

      // Initialize controllers
      _secondaryEmailController.text = authProvider.secondaryEmail ?? '';
      _phoneControllers.clear();
      for (var p in authProvider.phones) {
        _phoneControllers.add(TextEditingController(text: p));
      }

      for (var platform in ['Facebook', 'Instagram', 'Twitter']) {
        _socialControllers[platform] ??=
            TextEditingController(text: authProvider.socialMedia[platform] ?? '');
      }
    });
  }

  void _cancelEditing() {
    setState(() => _editing = false);
  }

  Future<void> _saveEditing(AuthProvider authProvider) async {
    final secondaryEmail = _secondaryEmailController.text.trim();
    if (secondaryEmail.isNotEmpty) {
      await authProvider.setSecondaryEmail(secondaryEmail);
    }

    // Phones
    List<String> validPhones = [];
    for (var controller in _phoneControllers) {
      final val = controller.text.trim();
      if (val.isNotEmpty) validPhones.add(val);
    }
    await authProvider.setPhones(validPhones); // We'll add setPhones in AuthProvider

    // Social media
    for (var platform in _socialControllers.keys) {
      final val = _socialControllers[platform]?.text.trim() ?? '';
      if (val.isNotEmpty) {
        await authProvider.setSocialMedia(platform, val);
      } else {
        await authProvider.removeSocialMedia(platform);
      }
    }

    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Info'),
        centerTitle: true,
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _startEditing(authProvider),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _editing ? _buildEditForm(authProvider) : _buildView(authProvider),
      ),
    );
  }

  Widget _buildView(AuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Primary Email', authProvider.user?.email ?? ''),
        _buildInfoRow('Secondary Email', authProvider.secondaryEmail ?? 'Not set'),
        _buildPhoneList(authProvider),
        _buildSocialList(authProvider),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildPhoneList(AuthProvider authProvider) {
    if (authProvider.phones.isEmpty) return _buildInfoRow('Phones', 'Not set');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Phone Numbers:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        ...authProvider.phones.map((p) => Text('+977 $p')),
      ],
    );
  }

  Widget _buildSocialList(AuthProvider authProvider) {
    if (authProvider.socialMedia.isEmpty) return _buildInfoRow('Social Media', 'Not set');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Social Media:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        ...authProvider.socialMedia.entries.map(
              (e) => Text('${e.key}: ${e.value}'),
        ),
      ],
    );
  }

  Widget _buildEditForm(AuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Secondary Email', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(controller: _secondaryEmailController, decoration: const InputDecoration(border: OutlineInputBorder())),
        const SizedBox(height: 12),

        const Text('Phone Numbers', style: TextStyle(fontWeight: FontWeight.bold)),
        ...List.generate(_phoneControllers.length, (i) => _buildPhoneField(i)),
        TextButton.icon(
          onPressed: () => setState(() => _phoneControllers.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: const Text('Add Phone'),
        ),
        const SizedBox(height: 12),

        const Text('Social Media', style: TextStyle(fontWeight: FontWeight.bold)),
        ...['Facebook', 'Instagram', 'Twitter'].map((platform) => _buildSocialField(platform)),

        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: _cancelEditing, child: const Text('Cancel')),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: () => _saveEditing(authProvider), child: const Text('Save')),
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
          const Text('Phone +977 - '),
          Expanded(child: TextField(controller: _phoneControllers[index], keyboardType: TextInputType.phone, decoration: const InputDecoration(border: OutlineInputBorder()))),
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
      child: Row(
        children: [
          Text('$platform: '),
          Expanded(
            child: TextField(
              controller: _socialControllers[platform],
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
        ],
      ),
    );
  }
}
