import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart' as geo;
import '../../provider/auth_provider.dart';
import '../../provider/post_provider.dart';

class EditPostPage extends StatefulWidget {
  final Map<String, dynamic> post;
  const EditPostPage({super.key, required this.post});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleC, _descC, _priceC, _depositC, _locationC, _notesC, _floorC;
  late String _propertyType, _bathroom, _parking, _status;
  late int _rooms, _halls, _kitchens;
  late List<TextEditingController> _roomW, _roomL, _hallW, _hallL, _kitchenW, _kitchenL;
  late bool _negotiable;
  DateTime? _availableFrom;
  late LatLng _selectedLocation;
  late Map<String, bool> _nearby, _amenities;
  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();
  late List<String> _existingImages;
  final MapController _mapController = MapController();
  Timer? _debounce;

  final Map<String, bool> _defaultNearby = {
    'Hospital': false, 'Garage': false, 'School': false, 'Market': false, 'Bus Stop': false,
    'Pharmacy': false, 'Gym': false, 'Park': false, 'Temple': false, 'Swimming Pool': false, 'Mall': false,
  };
  final Map<String, bool> _defaultAmenities = {
    'WiFi': false, 'Water': false, 'Hot Water': false, 'Electricity': false, 'Furnished': false,
    'AC/Heating': false, 'Laundry': false, 'Pet Friendly': false, 'Garbage': false, 'Balcony': false,
  };

  @override
  void initState() {
    super.initState();
    _initializeFromPost();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is Timestamp) return value.toDate();
    return null;
  }

  void _initializeFromPost() {
    final post = widget.post;
    _titleC = TextEditingController(text: post['title']);
    _descC = TextEditingController(text: post['description']);
    _priceC = TextEditingController(text: post['price']?.toString());
    _depositC = TextEditingController(text: post['deposit']?.toString());
    _locationC = TextEditingController(text: post['typedAddress']);
    _notesC = TextEditingController(text: post['notes']);
    _floorC = TextEditingController(text: post['floor']?.toString());

    _propertyType = post['propertyType'] ?? 'Room';
    _rooms = post['rooms'] ?? 0;
    _halls = post['halls'] ?? 0;
    _kitchens = post['kitchens'] ?? 0;

    _bathroom = post['bathroom'] ?? 'Private';
    _parking = post['parking'] ?? 'None';
    _negotiable = post['negotiable'] ?? false;

    _status = post['status'] ?? 'Vacant';
    _availableFrom = _parseDate(post['availableFrom']);

    // Nearby
    final nearbyFromPost = post['nearby'];
    if (nearbyFromPost is Map<String, dynamic>) {
      _nearby = Map<String, bool>.from(nearbyFromPost);
    } else if (nearbyFromPost is List) {
      _nearby = Map.fromIterable(
        _defaultNearby.keys,
        key: (k) => k,
        value: (k) => nearbyFromPost.contains(k),
      );
    } else {
      _nearby = Map.from(_defaultNearby);
    }

    // Amenities
    final amenitiesFromPost = post['amenities'];
    if (amenitiesFromPost is Map<String, dynamic>) {
      _amenities = Map<String, bool>.from(amenitiesFromPost);
    } else if (amenitiesFromPost is List) {
      _amenities = Map.fromIterable(
        _defaultAmenities.keys,
        key: (k) => k,
        value: (k) => amenitiesFromPost.contains(k),
      );
    } else {
      _amenities = Map.from(_defaultAmenities);
    }

    final loc = post['location'];
    _selectedLocation = loc != null
        ? LatLng(loc['latitude'] ?? 27.7172, loc['longitude'] ?? 85.3240)
        : LatLng(27.7172, 85.3240);

    _roomW = _initSizeControllers(post['roomSizes']);
    _roomL = _initSizeControllers(post['roomSizes'], length: true);
    _hallW = _initSizeControllers(post['hallSizes']);
    _hallL = _initSizeControllers(post['hallSizes'], length: true);
    _kitchenW = _initSizeControllers(post['kitchenSizes']);
    _kitchenL = _initSizeControllers(post['kitchenSizes'], length: true);

    _existingImages = List<String>.from(post['images'] ?? []);
  }

  List<TextEditingController> _initSizeControllers(List<dynamic>? sizes, {bool length = false}) {
    if (sizes == null) return [];
    return sizes.map((s) => TextEditingController(text: length ? s['length'] : s['width'])).toList();
  }

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _priceC.dispose();
    _depositC.dispose();
    _locationC.dispose();
    _notesC.dispose();
    _floorC.dispose();
    for (final c in [..._roomW, ..._roomL, ..._hallW, ..._hallL, ..._kitchenW, ..._kitchenL]) c.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  InputDecoration _input(String label, {Widget? prefix, Widget? suffix}) => InputDecoration(
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

  Widget _counterRow({required String label, required int count, required VoidCallback onAdd, required VoidCallback onRemove}) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        IconButton(onPressed: count > 0 ? onRemove : null, icon: const Icon(Icons.remove_circle_outline)),
        Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline)),
      ],
    );
  }

  void _ensureListLength(List<TextEditingController> list, int newLen) {
    while (list.length < newLen) list.add(TextEditingController());
    while (list.length > newLen) list.removeLast().dispose();
  }

  Widget _sizesGrid({required String label, required int count, required List<TextEditingController> wList, required List<TextEditingController> lList}) {
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
                Expanded(child: TextFormField(controller: wList[i], keyboardType: TextInputType.number, decoration: _input('Width'), validator: (v) => v == null || v.isEmpty ? 'Enter width' : null)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('x', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Expanded(child: TextFormField(controller: lList[i], keyboardType: TextInputType.number, decoration: _input('Length'), validator: (v) => v == null || v.isEmpty ? 'Enter length' : null)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _pickImages() async {
    final remaining = 5 - (_existingImages.length + _images.length);
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 5 images allowed.')));
      return;
    }
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() => _images.addAll(picked.take(remaining)));
    if (picked.length > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Only $remaining more image(s) allowed.')));
    }
  }

  Widget _buildImagePreview() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._existingImages.asMap().entries.map((entry) {
            final index = entry.key;
            final url = entry.value;
            return Padding(
              padding: const EdgeInsets.all(4),
              child: Stack(
                children: [
                  Image.network(url, width: 100, height: 100, fit: BoxFit.cover),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _existingImages.removeAt(index)),
                      child: const Icon(Icons.cancel, color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          }),
          ..._images.asMap().entries.map((entry) {
            final index = entry.key;
            final xfile = entry.value;
            return Padding(
              padding: const EdgeInsets.all(4),
              child: Stack(
                children: [
                  Image.file(File(xfile.path), width: 100, height: 100, fit: BoxFit.cover),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _images.removeAt(index)),
                      child: const Icon(Icons.cancel, color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _onLocationChanged(String text) async {
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
      } catch (_) {}
    });
  }

  Widget _choiceChips(String title, Map<String, bool> data, void Function(String, bool) onChanged) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: data.keys.map((k) {
        return FilterChip(
          label: Text(k),
          selected: data[k]!,
          onSelected: (v) => setState(() => onChanged(k, v)),
        );
      }).toList(),
    );
  }

  void _submitEdit() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    final selectedAmenities = _amenities.entries.where((e) => e.value).map((e) => e.key).toList();
    final selectedNearby = _nearby.entries.where((e) => e.value).map((e) => e.key).toList();

    final roomSizes = List.generate(_rooms, (i) => {'width': _roomW[i].text.trim(), 'length': _roomL[i].text.trim()});
    final hallSizes = List.generate(_halls, (i) => {'width': _hallW[i].text.trim(), 'length': _hallL[i].text.trim()});
    final kitchenSizes = List.generate(_kitchens, (i) => {'width': _kitchenW[i].text.trim(), 'length': _kitchenL[i].text.trim()});

    final postData = {
      'title': _titleC.text.trim(),
      'description': _descC.text.trim(),
      'propertyType': _propertyType,
      'rooms': _rooms,
      'halls': _halls,
      'kitchens': _kitchens,
      'price': _priceC.text.trim(),
      'deposit': _depositC.text.trim(),
      'floor': _floorC.text.trim(),
      'location': {'latitude': _selectedLocation.latitude, 'longitude': _selectedLocation.longitude},
      'amenities': selectedAmenities,
      'nearby': selectedNearby,
      'contact': {'name': authProvider.displayName ?? '', 'email': authProvider.email ?? ''},
      'negotiable': _negotiable,
      'bathroom': _bathroom,
      'parking': _parking,
      'status': _status,
      'availableFrom': _availableFrom?.toIso8601String(),
      'roomSizes': roomSizes,
      'hallSizes': hallSizes,
      'kitchenSizes': kitchenSizes,
      'notes': _notesC.text.trim(),
      'typedAddress': _locationC.text.trim(),
      'images': _existingImages,
    };

    try {
      final newImagesPaths = _images.map((e) => e.path).toList();
      await postProvider.updateRental(postId: widget.post['id'], metadata: postData, newImages: newImagesPaths);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post updated successfully!')));
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update post: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Rental'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(controller: _titleC, decoration: _input('Title'), validator: (v) => v == null || v.isEmpty ? 'Enter title' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _descC, decoration: _input('Description'), maxLines: 3, validator: (v) => v == null || v.isEmpty ? 'Enter description' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _priceC, decoration: _input('Price'), keyboardType: TextInputType.number, validator: (v) => v == null || v.isEmpty ? 'Enter price' : null),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Price Negotiable', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _negotiable,
                        onChanged: (v) => setState(() => _negotiable = v ?? false),
                      ),
                    ],
                  ),

                ],
              ),

              TextFormField(controller: _depositC, decoration: _input('Deposit'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextFormField(controller: _floorC, decoration: _input('Floor')),
              const SizedBox(height: 12),
              //Property Type
              const SizedBox(height: 12),
              const Text('Property Type', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 10,
                children: ['Room', 'Flat', 'Apartment', 'Shared'].map((type) {
                  return ChoiceChip(
                    label: Text(type),
                    selected: _propertyType == type,
                    onSelected: (_) => setState(() => _propertyType = type),
                  );
                }).toList(),
              ),
              //Status
              const SizedBox(height: 12),
              const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 10,
                children: ['To Be Vacant', 'Vacant'].map((status) { // reordered
                  return ChoiceChip(
                    label: Text(status),
                    selected: _status == status,
                    onSelected: (_) => setState(() => _status = status),
                  );
                }).toList(),
              ),

              // Date Picker
              if (_status == 'To Be Vacant') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _availableFrom != null
                            ? 'Available From: ${_availableFrom!.toLocal().toString().split(' ')[0]}'
                            : 'Select Available From Date',
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _availableFrom ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) setState(() => _availableFrom = pickedDate);
                      },
                      child: const Text('Pick Date'),
                    ),
                  ],
                ),
              ],





              // Rooms/Halls/Kitchens
              _counterRow(
                  label: 'Rooms',
                  count: _rooms,
                  onAdd: () => setState(() {
                    _rooms++;
                    _ensureListLength(_roomW, _rooms);
                    _ensureListLength(_roomL, _rooms);
                  }),
                  onRemove: () => setState(() {
                    _rooms--;
                    _ensureListLength(_roomW, _rooms);
                    _ensureListLength(_roomL, _rooms);
                  })),
              _sizesGrid(label: 'Room', count: _rooms, wList: _roomW, lList: _roomL),
              _counterRow(
                  label: 'Halls',
                  count: _halls,
                  onAdd: () => setState(() {
                    _halls++;
                    _ensureListLength(_hallW, _halls);
                    _ensureListLength(_hallL, _halls);
                  }),
                  onRemove: () => setState(() {
                    _halls--;
                    _ensureListLength(_hallW, _halls);
                    _ensureListLength(_hallL, _halls);
                  })),
              _sizesGrid(label: 'Hall', count: _halls, wList: _hallW, lList: _hallL),
              _counterRow(
                  label: 'Kitchens',
                  count: _kitchens,
                  onAdd: () => setState(() {
                    _kitchens++;
                    _ensureListLength(_kitchenW, _kitchens);
                    _ensureListLength(_kitchenL, _kitchens);
                  }),
                  onRemove: () => setState(() {
                    _kitchens--;
                    _ensureListLength(_kitchenW, _kitchens);
                    _ensureListLength(_kitchenL, _kitchens);
                  })),
              _sizesGrid(label: 'Kitchen', count: _kitchens, wList: _kitchenW, lList: _kitchenL),
              const SizedBox(height: 12),
              //Bathroom
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
              //Parking
              const Text('Parking', style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 10,
              children: ['None', 'Bike', 'Car', 'Both'].map((p) {
                final value = p == 'Both' ? 'Bike & Car' : p; // maps UI label to stored value
                return ChoiceChip(
                  label: Text(p),
                  selected: _parking == value,
                  onSelected: (_) => setState(() => _parking = value),
                );
              }).toList(),
            ),
              // Amenities & Nearby
              const Text('Amenities', style: TextStyle(fontWeight: FontWeight.bold)),
              _choiceChips('Amenities', _amenities, (k, v) => _amenities[k] = v),
              const SizedBox(height: 12),
              const Text('Nearby', style: TextStyle(fontWeight: FontWeight.bold)),
              _choiceChips('Nearby', _nearby, (k, v) => _nearby[k] = v),
              const SizedBox(height: 12),



              // Address
              TextFormField(controller: _locationC, decoration: _input('Address'), onChanged: _onLocationChanged),
              const SizedBox(height: 12),

              // Map placeholder (if needed)
              SizedBox(
                height: 200,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                      initialCenter: _selectedLocation,
                      initialZoom: 15,
                    onTap: (tapPosition, latlng) {
                      setState(() => _selectedLocation = latlng);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName: "com.basobaas_map",
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                            point: _selectedLocation,
                            width: 50,
                            height: 50,

                            child: const Icon(Icons.location_on, color: Colors.red, size: 40)
                        )
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // Images
              _buildImagePreview(),
              Row(
                children: [
                  ElevatedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add Images'),
                  ),
                  const SizedBox(width: 12),
                  Text('${_existingImages.length + _images.length}/5 selected'),

                ],
              ),
              const SizedBox(height: 16),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: _submitEdit,
                    child: const Text('Save Changes')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
