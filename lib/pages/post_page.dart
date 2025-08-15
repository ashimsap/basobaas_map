import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';

class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _depositController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  String _propertyType = 'Room';
  int _rooms = 1;
  int _beds = 1;
  LatLng _selectedLocation = LatLng(27.7172, 85.3240); // Default Kathmandu
  final MapController _mapController = MapController();

  // Images
  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();

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

  Future<void> _pickImages() async {
    final List<XFile>? selected = await _picker.pickMultiImage();
    if (selected != null) {
      setState(() => _images.addAll(selected));
    }
  }

  void _submitPost() {
    if (_formKey.currentState!.validate()) {
      // Collect all data here
      final postData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'propertyType': _propertyType,
        'rooms': _rooms,
        'beds': _beds,
        'price': _priceController.text,
        'deposit': _depositController.text,
        'location': _selectedLocation,
        'amenities': _amenities,
        'contact': _contactController.text,
        'images': _images,
      };

      // TODO: Send this data to Firebase or your backend
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post submitted successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a Rental')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value!.isEmpty ? 'Enter title' : null,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) => value!.isEmpty ? 'Enter description' : null,
              ),
              const SizedBox(height: 12),

              // Property Type
              DropdownButtonFormField<String>(
                value: _propertyType,
                items: ['Room', 'Flat', 'Apartment', 'Shared Room']
                    .map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type),
                ))
                    .toList(),
                onChanged: (val) => setState(() => _propertyType = val!),
                decoration: const InputDecoration(labelText: 'Property Type'),
              ),
              const SizedBox(height: 12),

              // Rooms & Beds
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Rooms'),
                      initialValue: '1',
                      keyboardType: TextInputType.number,
                      onChanged: (val) => _rooms = int.tryParse(val) ?? 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Beds'),
                      initialValue: '1',
                      keyboardType: TextInputType.number,
                      onChanged: (val) => _beds = int.tryParse(val) ?? 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Price & Deposit
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isEmpty ? 'Enter price' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _depositController,
                      decoration: const InputDecoration(labelText: 'Deposit'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Map Picker
              SizedBox(
                height: 200,
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
                          child:  const Icon(Icons.location_pin, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Amenities
              const Text('Amenities', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 10,
                children: _amenities.keys.map((key) {
                  return FilterChip(
                    label: Text(key),
                    selected: _amenities[key]!,
                    onSelected: (val) => setState(() => _amenities[key] = val),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Contact
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Enter contact number' : null,
              ),
              const SizedBox(height: 12),

              // Images
              Text('Images', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _pickImages,
                    child: const Text('Pick Images'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Image.file(
                              File(_images[index].path),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submit Button
              Center(
                child: ElevatedButton(
                  onPressed: _submitPost,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    child: Text('Post', style: TextStyle(fontSize: 16)),
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
