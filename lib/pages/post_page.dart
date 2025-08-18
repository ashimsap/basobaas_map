import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart' as geo;

import '../provider/auth_provider.dart';

class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers (base)
  final TextEditingController _titleC = TextEditingController();
  final TextEditingController _descC = TextEditingController();
  final TextEditingController _priceC = TextEditingController();
  final TextEditingController _depositC = TextEditingController();
  final TextEditingController _locationC = TextEditingController();
  final TextEditingController _notesC = TextEditingController();

  // Property type
  String _propertyType = 'Room';

  // Rooms/Halls/Kitchens with dynamic size inputs
  int _rooms = 0;
  int _halls = 0;
  int _kitchens = 0;

  final List<TextEditingController> _roomW = [];
  final List<TextEditingController> _roomL = [];
  final List<TextEditingController> _hallW = [];
  final List<TextEditingController> _hallL = [];
  final List<TextEditingController> _kitchenW = [];
  final List<TextEditingController> _kitchenL = [];

  // Bathroom
  String _bathroom = 'Private'; // Private / Shared

  // Parking
  String _parking = 'None'; // None / Bike / Car / Both

  // Price helpers
  bool _negotiable = false;

  // Status
  String _status = 'Vacant'; // Vacant / ToBeVacant / Filled
  DateTime? _availableFrom;
  DateTime? _filledSince;

  // Near areas (chips)
  final Map<String, bool> _nearby = {
    'Hospital': false,
    'Garage': false,
    'School': false,
    'Market': false,
    'Bus Stop': false,
    'Pharmacy': false,
    'Gym': false,
    'Park': false,
    'Temple': false,
  };

  // Amenities
  final Map<String, bool> _amenities = {
    'WiFi': false,
    'Water': false,
    'Electricity': false,
    'Parking': false,
    'Furnished': false,
    'AC/Heating': false,
    'Laundry': false,
    'Pet Friendly': false,
  };

  // Images (max 5)
  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();

  // Map
  LatLng _selectedLocation = LatLng(27.7172, 85.3240); // Kathmandu default
  final MapController _mapController = MapController();
  Timer? _debounce;

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _priceC.dispose();
    _depositC.dispose();
    _locationC.dispose();
    _notesC.dispose();
    for (final c in [..._roomW, ..._roomL, ..._hallW, ..._hallL, ..._kitchenW, ..._kitchenL]) {
      c.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }

  // ---------- Helpers ----------
  InputDecoration _input(String label, {Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefix,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _counterRow({
    required String label,
    required int count,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        IconButton(
          onPressed: count > 0 ? onRemove : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline)),
      ],
    );
  }

  void _ensureListLength(List<TextEditingController> list, int newLen) {
    while (list.length < newLen) {
      list.add(TextEditingController());
    }
    while (list.length > newLen) {
      list.removeLast().dispose();
    }
  }

  Widget _sizesGrid({
    required String label,
    required int count,
    required List<TextEditingController> wList,
    required List<TextEditingController> lList,
  }) {
    if (count == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label sizes (ft)', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...List.generate(count, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: wList[i],
                    keyboardType: TextInputType.number,
                    decoration: _input('Width'),
                    validator: (v) {
                      if ((v ?? '').isEmpty) return 'Enter width';
                      return null;
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('x', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: TextFormField(
                    controller: lList[i],
                    keyboardType: TextInputType.number,
                    decoration: _input('Length'),
                    validator: (v) {
                      if ((v ?? '').isEmpty) return 'Enter length';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    final remaining = 5 - _images.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can upload up to 5 images.')),
      );
      return;
    }

    final toAdd = picked.take(remaining).toList();
    setState(() => _images.addAll(toAdd));

    if (picked.length > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only $remaining more image(s) allowed (max 5).')),
      );
    }
  }

  Color _statusColor() {
    switch (_status) {
      case 'ToBeVacant':
        return Colors.orange;
      case 'Filled':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  Future<void> _pickDate({required bool forVacant}) async {
    final now = DateTime.now();
    final initial = forVacant ? (_availableFrom ?? now) : (_filledSince ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (forVacant) {
          _availableFrom = picked;
        } else {
          _filledSince = picked;
        }
      });
    }
  }

  void _onLocationChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 650), () async {
      if (text.trim().isEmpty) return;
      try {
        final results = await geo.locationFromAddress(text);
        if (results.isNotEmpty) {
          final loc = results.first;
          final pos = LatLng(loc.latitude, loc.longitude);
          setState(() => _selectedLocation = pos);
          _mapController.move(pos, 15);
        }
      } catch (_) {
        // ignore geocoding errors silently or show a gentle hint if you prefer
      }
    });
  }

  // ---------- Submit (kept same flow; just adds more fields to map) ----------
  void _submitPost() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isVerified()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verify your account through profile page to post a rental.")),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final selectedAmenities = _amenities.entries.where((e) => e.value).map((e) => e.key).toList();
      final selectedNearby = _nearby.entries.where((e) => e.value).map((e) => e.key).toList();

      // Pack sizes
      List<Map<String, String>> roomSizes = List.generate(_rooms, (i) => {
        'width': _roomW[i].text.trim(),
        'length': _roomL[i].text.trim(),
      });
      List<Map<String, String>> hallSizes = List.generate(_halls, (i) => {
        'width': _hallW[i].text.trim(),
        'length': _hallL[i].text.trim(),
      });
      List<Map<String, String>> kitchenSizes = List.generate(_kitchens, (i) => {
        'width': _kitchenW[i].text.trim(),
        'length': _kitchenL[i].text.trim(),
      });

      final postData = {
        // original keys you had:
        'title': _titleC.text.trim(),
        'description': _descC.text.trim(),
        'propertyType': _propertyType,
        'rooms': _rooms, // kept for backward compatibility
        'beds': 0, // no separate beds control now; keep 0 or compute from rooms
        'price': _priceC.text.trim(),
        'deposit': _depositC.text.trim(),
        'location': _selectedLocation,
        'amenities': _amenities, // map of booleans as before
        'contact': {
          'name': authProvider.displayName ?? '',
          'email': authProvider.email ?? '',
        },
        'images': _images,

        // new fields:
        'negotiable': _negotiable,
        'bathroom': _bathroom,
        'parking': _parking,
        'status': _status,
        'availableFrom': _availableFrom?.toIso8601String(),
        'filledSince': _filledSince?.toIso8601String(),
        'roomSizes': roomSizes,
        'hallSizes': hallSizes,
        'kitchenSizes': kitchenSizes,
        'nearby': selectedNearby,
        'notes': _notesC.text.trim(),
        'typedAddress': _locationC.text.trim(),
      };

      // TODO: Send postData to your backend/Firestore + upload images to Storage
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post submitted successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context); // listen true to update contact display

    return Scaffold(
      appBar: AppBar(title: const Text('Post a Rental')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextFormField(
                controller: _titleC,
                decoration: _input('Title', prefix: const Icon(Icons.title)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter title' : null,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descC,
                maxLines: 4,
                decoration: _input('Description', prefix: const Icon(Icons.notes)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter description' : null,
              ),
              const SizedBox(height: 12),

              // Property Type
              DropdownButtonFormField<String>(
                value: _propertyType,
                isExpanded: true,
                items: const ['Room', 'Flat', 'Apartment', 'Shared Room']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _propertyType = v!),
                decoration: _input('Property Type', prefix: const Icon(Icons.home_work)),
              ),
              const SizedBox(height: 16),

              // Rooms / Halls / Kitchens (dynamic size fields)
              _counterRow(
                label: 'Rooms',
                count: _rooms,
                onAdd: () {
                  setState(() {
                    _rooms++;
                    _ensureListLength(_roomW, _rooms);
                    _ensureListLength(_roomL, _rooms);
                  });
                },
                onRemove: () {
                  setState(() {
                    if (_rooms > 0) _rooms--;
                    _ensureListLength(_roomW, _rooms);
                    _ensureListLength(_roomL, _rooms);
                  });
                },
              ),
              _sizesGrid(label: 'Room', count: _rooms, wList: _roomW, lList: _roomL),
              const SizedBox(height: 8),

              _counterRow(
                label: 'Halls',
                count: _halls,
                onAdd: () {
                  setState(() {
                    _halls++;
                    _ensureListLength(_hallW, _halls);
                    _ensureListLength(_hallL, _halls);
                  });
                },
                onRemove: () {
                  setState(() {
                    if (_halls > 0) _halls--;
                    _ensureListLength(_hallW, _halls);
                    _ensureListLength(_hallL, _halls);
                  });
                },
              ),
              _sizesGrid(label: 'Hall', count: _halls, wList: _hallW, lList: _hallL),
              const SizedBox(height: 8),

              _counterRow(
                label: 'Kitchens',
                count: _kitchens,
                onAdd: () {
                  setState(() {
                    _kitchens++;
                    _ensureListLength(_kitchenW, _kitchens);
                    _ensureListLength(_kitchenL, _kitchens);
                  });
                },
                onRemove: () {
                  setState(() {
                    if (_kitchens > 0) _kitchens--;
                    _ensureListLength(_kitchenW, _kitchens);
                    _ensureListLength(_kitchenL, _kitchens);
                  });
                },
              ),
              _sizesGrid(label: 'Kitchen', count: _kitchens, wList: _kitchenW, lList: _kitchenL),
              const SizedBox(height: 16),

              // Bathroom (radio)
              const Text('Bathroom', style: TextStyle(fontWeight: FontWeight.w600)),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'Private',
                      groupValue: _bathroom,
                      title: const Text('Private'),
                      onChanged: (v) => setState(() => _bathroom = v!),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'Shared',
                      groupValue: _bathroom,
                      title: const Text('Shared'),
                      onChanged: (v) => setState(() => _bathroom = v!),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Parking (radio)
              const Text('Parking', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(
                spacing: 10,
                children: [
                  _parkingChip('None'),
                  _parkingChip('Bike'),
                  _parkingChip('Car'),
                  _parkingChip('Both'),
                ],
              ),
              const SizedBox(height: 16),

              // Price / Deposit / Negotiable
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceC,
                      keyboardType: TextInputType.number,
                      decoration: _input('Price (NPR)', prefix: const Icon(Icons.currency_rupee)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter price' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _depositC,
                      keyboardType: TextInputType.number,
                      decoration: _input('Deposit (optional)', prefix: const Icon(Icons.savings)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _negotiable,
                onChanged: (v) => setState(() => _negotiable = v ?? false),
                title: const Text('Price negotiable'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),

              // Amenities
              const Text('Amenities', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: _amenities.keys.map((k) {
                  return FilterChip(
                    label: Text(k),
                    selected: _amenities[k]!,
                    onSelected: (v) => setState(() => _amenities[k] = v),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Status + dates
              const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(
                spacing: 10,
                children: [
                  _statusChip('Vacant'),
                  _statusChip('ToBeVacant'),
                  _statusChip('Filled'),
                ],
              ),
              const SizedBox(height: 8),
              if (_status == 'ToBeVacant')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(forVacant: true),
                        icon: const Icon(Icons.event),
                        label: Text(_availableFrom == null
                            ? 'Select available from date'
                            : 'From: ${_availableFrom!.toLocal().toString().split(' ').first}'),
                      ),
                    ),
                  ],
                ),
              if (_status == 'Filled')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(forVacant: false),
                        icon: const Icon(Icons.event_busy),
                        label: Text(_filledSince == null
                            ? 'Select filled since date'
                            : 'Since: ${_filledSince!.toLocal().toString().split(' ').first}'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Nearby
              const Text('Nearby Areas', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: _nearby.keys.map((k) {
                  return FilterChip(
                    label: Text(k),
                    selected: _nearby[k]!,
                    onSelected: (v) => setState(() => _nearby[k] = v),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesC,
                maxLines: 4,
                decoration: _input('Additional notes (optional)', prefix: const Icon(Icons.edit_note)),
              ),
              const SizedBox(height: 16),

              // Contact (from profile)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFDDDDDD)),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.contact_mail),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Contact', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(auth.displayName ?? '(no name)'),
                          Text(auth.email ?? '(no email)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Location search + map
              TextFormField(
                controller: _locationC,
                decoration: _input(
                  'Search location name',
                  prefix: const Icon(Icons.place_outlined),
                  suffix: (_locationC.text.isNotEmpty)
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _locationC.clear();
                      setState(() {});
                    },
                  )
                      : null,
                ),
                onChanged: (t) {
                  setState(() {}); // to show/hide clear icon
                  _onLocationChanged(t);
                },
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 220,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: 15,
                    onTap: (tapPos, latLng) => setState(() => _selectedLocation = latLng),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.basobaas',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation,
                          width: 40,
                          height: 40,
                          child: Icon(Icons.location_pin, color: _statusColor(), size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Images
              const Text('Images (max 5)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick Images'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 84,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        itemBuilder: (context, i) {
                          return Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 84,
                                height: 84,
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFDDDDDD)),
                                ),
                                child: Image.file(File(_images[i].path), fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 4,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () => setState(() => _images.removeAt(i)),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black54,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Submit
              Center(
                child: ElevatedButton(
                  onPressed: _submitPost,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    child: Text('Post Rental', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF7F7F7),
    );
  }

  // --- Helper chips ---
  Widget _parkingChip(String value) {
    final selected = _parking == value;
    return ChoiceChip(
      label: Text(value),
      selected: selected,
      onSelected: (_) => setState(() => _parking = value),
    );
  }

  Widget _statusChip(String value) {
    final selected = _status == value;
    final label = switch (value) {
      'Vacant' => 'Vacant',
      'ToBeVacant' => 'To be vacant (from)',
      'Filled' => 'Filled (since)',
      _ => value,
    };
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _status = value),
    );
  }
}
