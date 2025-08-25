import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart' as geo;
import '../../provider/auth_provider.dart';
import '../../provider/post_provider.dart';

class EditPostPage extends StatefulWidget {
  final Map<String, dynamic> postData;
  final String postId;

  const EditPostPage({super.key, required this.postData, required this.postId});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final MapController _mapController = MapController();
  Timer? _debounce;

  // Controllers
  late final TextEditingController _titleC,
      _descC,
      _priceC,
      _depositC,
      _locationC,
      _notesC,
      _floorC;

  // Property info
  late String _propertyType;
  late int _rooms, _halls, _kitchens;
  late List<TextEditingController> _roomW, _roomL, _hallW, _hallL, _kitchenW, _kitchenL;

  // Other fields
  late String _bathroom, _parking, _status;
  late bool _negotiable;
  DateTime? _availableFrom;
  DateTime? _rentedSince;
  late LatLng _selectedLocation;

  // Options
  late Map<String, bool> _amenities;
  late Map<String, bool> _nearby;

  // Images
  late List<XFile> _images;
  late List<String> _existingImages;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    final data = widget.postData;

    // Initialize controllers
    _titleC = TextEditingController(text: data['title']);
    _descC = TextEditingController(text: data['description']);
    _priceC = TextEditingController(text: data['price']?.toString());
    _depositC = TextEditingController(text: data['deposit']?.toString());
    _locationC = TextEditingController(text: data['typedAddress']);
    _notesC = TextEditingController(text: data['notes']);
    _floorC = TextEditingController(text: data['floor']);

    // Property details
    _propertyType = data['propertyType'] ?? 'Room';
    _rooms = data['rooms'] ?? 0;
    _halls = data['halls'] ?? 0;
    _kitchens = data['kitchens'] ?? 0;
    _bathroom = data['bathroom'] ?? 'Private';
    _negotiable = data['negotiable'] ?? false;
    _status = data['status'] ?? 'Vacant';
    _availableFrom = data['availableFrom'] != null ? DateTime.tryParse(data['availableFrom']) : null;
    _rentedSince = data['rentedSince'] != null ? DateTime.tryParse(data['rentedSince']) : null;

    _parking = data['parking'] == 'Bike & Car' ? 'Both' : (data['parking'] ?? 'None');


    // Options
    _amenities = _initOptionMap([
      'WiFi', 'Water', 'Hot Water', 'Electricity', 'Furnished',
      'AC/Heating', 'Laundry', 'Pet Friendly', 'Garbage', 'Balcony'
    ], data['amenities']);
    _nearby = _initOptionMap([
      'Hospital', 'Garage', 'School', 'Market', 'Bus Stop',
      'Pharmacy', 'Gym', 'Park', 'Temple', 'Swimming Pool', 'Mall'
    ], data['nearby']);

    // Location
    _selectedLocation = LatLng(
      data['location']?['latitude'] ?? 27.7172,
      data['location']?['longitude'] ?? 85.3240,
    );

    // Initialize size controllers
    _roomW = _initSizeControllers(data['roomSizes'], 'width', _rooms);
    _roomL = _initSizeControllers(data['roomSizes'], 'length', _rooms);
    _hallW = _initSizeControllers(data['hallSizes'], 'width', _halls);
    _hallL = _initSizeControllers(data['hallSizes'], 'length', _halls);
    _kitchenW = _initSizeControllers(data['kitchenSizes'], 'width', _kitchens);
    _kitchenL = _initSizeControllers(data['kitchenSizes'], 'length', _kitchens);

    // Images
    _images = [];
    _existingImages = List<String>.from(data['images'] ?? []);
  }

  Map<String, bool> _initOptionMap(List<String> keys, dynamic data) {
    return {for (var k in keys) k: (data ?? []).contains(k)};
  }

  List<TextEditingController> _initSizeControllers(List<dynamic>? sizes, String key, int count) {
    return List.generate(count, (i) => TextEditingController(text: sizes != null && i < sizes.length ? sizes[i][key]?.toString() : ''));
  }

  @override
  void dispose() {
    for (final c in [_titleC, _descC, _priceC, _depositC, _locationC, _notesC, _floorC, ..._roomW, ..._roomL, ..._hallW, ..._hallL, ..._kitchenW, ..._kitchenL]) {
      c.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }

  void _ensureListLength(List<TextEditingController> list, int length) {
    while (list.length < length) list.add(TextEditingController());
    while (list.length > length) list.removeLast().dispose();
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

  Widget _counterRow({required String label, required int count, required VoidCallback onAdd, required VoidCallback onRemove}) => Row(
    children: [
      Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
      IconButton(onPressed: count > 0 ? onRemove : null, icon: const Icon(Icons.remove_circle_outline)),
      Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline)),
    ],
  );

  Widget _sizesGrid({required String label, required int count, required List<TextEditingController> wList, required List<TextEditingController> lList}) {
    if (count == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label sizes (ft)', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...List.generate(count, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                  child: TextFormField(
                    controller: wList[i],
                    keyboardType: TextInputType.number,
                    decoration: _input('Width'),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Enter width' : null,
                  )),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('x', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              Expanded(
                  child: TextFormField(
                    controller: lList[i],
                    keyboardType: TextInputType.number,
                    decoration: _input('Length'),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Enter length' : null,
                  )),
            ],
          ),
        ))
      ],
    );
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    final remaining = 5 - _images.length - _existingImages.length;
    setState(() => _images.addAll(picked.take(remaining)));
    if (picked.length > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Only $remaining more image(s) allowed.')));
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
          setState(() => _selectedLocation = LatLng(loc.latitude, loc.longitude));
          _mapController.move(_selectedLocation, 15);
        }
      } catch (_) {}
    });
  }

  Future<void> _pickDate({required bool forVacant}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (forVacant) {
          _availableFrom = picked;
        } else {
          _rentedSince = picked;
        }
      });
    }
  }


  Color _statusColor() {
    switch (_status) {
      case 'To Be Vacant':
        return Colors.orange;
      case 'Rented':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  Widget _statusChip(String value) => ChoiceChip(
    label: Text(value),
    selected: _status == value,
    onSelected: (_) => setState(() => _status = value),
  );

  Widget _parkingChip(String value) => ChoiceChip(
    label: Text(value),
    selected: _parking == value,
    onSelected: (_) => setState(() => _parking = value),
  );

  Future<void> _submitPost() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    if (!authProvider.isVerified()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verify your account to edit a rental.")),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final selectedAmenities = _amenities.entries.where((e) => e.value).map((e) => e.key).toList();
    final selectedNearby = _nearby.entries.where((e) => e.value).map((e) => e.key).toList();
    final roomSizes = List.generate(_rooms, (i) => {'width': _roomW[i].text.trim(), 'length': _roomL[i].text.trim()});
    final hallSizes = List.generate(_halls, (i) => {'width': _hallW[i].text.trim(), 'length': _hallL[i].text.trim()});
    final kitchenSizes = List.generate(_kitchens, (i) => {'width': _kitchenW[i].text.trim(), 'length': _kitchenL[i].text.trim()});
    final contactInfo = <String, dynamic>{
      'name': authProvider.displayName ?? '',
      'email': authProvider.email ?? '',
    };
    if ((authProvider.secondaryEmail ?? '').isNotEmpty) {
      contactInfo['secondaryEmail'] = authProvider.secondaryEmail;
    }
    if (authProvider.phones.isNotEmpty) {
      contactInfo['phones'] = authProvider.phones;
    }
    if (authProvider.socialMedia.isNotEmpty) {
      contactInfo['socialMedia'] = authProvider.socialMedia;
    }
    if ((authProvider.about ?? '').isNotEmpty) {
      contactInfo['about'] = authProvider.about;
    }

    final updatedData = {
      'title': _titleC.text.trim(),
      'description': _descC.text.trim(),
      'propertyType': _propertyType,
      'rooms': _rooms,
      'halls': _halls,
      'kitchens': _kitchens,
      'price': int.tryParse(_priceC.text.trim()) ?? 0,
      'deposit': int.tryParse(_depositC.text.trim()) ?? 0,
      'floor': _floorC.text.trim(),
      'location': {'latitude': _selectedLocation.latitude, 'longitude': _selectedLocation.longitude},
      'amenities': selectedAmenities,
      'nearby': selectedNearby,
      'bathroom': _bathroom,
      'parking': _parking,
      'negotiable': _negotiable,
      'status': _status,
      'availableFrom': _status == 'To Be Vacant' ? _availableFrom?.toIso8601String() : null,
      'rentedSince': _status == 'Rented' ? _rentedSince?.toIso8601String() : null,
      'roomSizes': roomSizes,
      'hallSizes': hallSizes,
      'kitchenSizes': kitchenSizes,
      'notes': _notesC.text.trim(),
      'typedAddress': _locationC.text.trim(),
    };

    final uploadedUrls = await _uploadImages(_images);
    final allImages = [..._existingImages, ...uploadedUrls];

    await postProvider.updateRental(
      postId: widget.postId,
      metadata: {...updatedData, 'images': allImages},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post updated successfully.")));
      Navigator.of(context).pop(true);
    }
  }

  Future<List<String>> _uploadImages(List<XFile> files) async {
    // Implement your upload logic (e.g., Firebase Storage)
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Rental'), centerTitle: true),
      backgroundColor: const Color(0xFFF7F7F7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              // Property Type dropdown
              DropdownButtonFormField<String>(
                value: _propertyType,
                isExpanded: true,
                items: const ['Room', 'Flat', 'Shared Room', 'Studio', 'House']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _propertyType = v!;
                    _rooms = _halls = _kitchens = 0;
                    _ensureListLength(_roomW, _rooms);
                    _ensureListLength(_roomL, _rooms);
                    _ensureListLength(_hallW, _halls);
                    _ensureListLength(_hallL, _halls);
                    _ensureListLength(_kitchenW, _kitchens);
                    _ensureListLength(_kitchenL, _kitchens);
                  });
                },
                decoration: _input('Property Type', prefix: const Icon(Icons.home_work)),
              ),
              const SizedBox(height: 16),

              // Dynamic counters based on property type
              if (_propertyType == 'Room') ...[
                _counterRow(
                  label: 'Rooms',
                  count: _rooms,
                  onAdd: () {
                    if (_rooms < 5) {
                      setState(() {
                        _rooms++;
                        _ensureListLength(_roomW, _rooms);
                        _ensureListLength(_roomL, _rooms);
                      });
                    }
                  },
                  onRemove: () {
                    if (_rooms > 0) {
                      setState(() {
                        _rooms--;
                        _ensureListLength(_roomW, _rooms);
                        _ensureListLength(_roomL, _rooms);
                      });
                    }
                  },
                ),
                _sizesGrid(label: 'Room', count: _rooms, wList: _roomW, lList: _roomL),
              ] else if (_propertyType == 'Flat' || _propertyType == 'Shared Room') ...[
                _counterRow(
                  label: 'Rooms',
                  count: _rooms,
                  onAdd: () {
                    if (_rooms < 3) {
                      setState(() {
                        _rooms++;
                        _ensureListLength(_roomW, _rooms);
                        _ensureListLength(_roomL, _rooms);
                      });
                    }
                  },
                  onRemove: () {
                    if (_rooms > 0) {
                      setState(() {
                        _rooms--;
                        _ensureListLength(_roomW, _rooms);
                        _ensureListLength(_roomL, _rooms);
                      });
                    }
                  },
                ),
                _sizesGrid(label: 'Room', count: _rooms, wList: _roomW, lList: _roomL),
                _counterRow(
                  label: 'Halls',
                  count: _halls,
                  onAdd: () {
                    if (_halls < 2) {
                      setState(() {
                        _halls++;
                        _ensureListLength(_hallW, _halls);
                        _ensureListLength(_hallL, _halls);
                      });
                    }
                  },
                  onRemove: () {
                    if (_halls > 0) {
                      setState(() {
                        _halls--;
                        _ensureListLength(_hallW, _halls);
                        _ensureListLength(_hallL, _halls);
                      });
                    }
                  },
                ),
                _sizesGrid(label: 'Hall', count: _halls, wList: _hallW, lList: _hallL),
                _counterRow(
                  label: 'Kitchens',
                  count: _kitchens,
                  onAdd: () {
                    if (_kitchens < 1) {
                      setState(() {
                        _kitchens++;
                        _ensureListLength(_kitchenW, _kitchens);
                        _ensureListLength(_kitchenL, _kitchens);
                      });
                    }
                  },
                  onRemove: () {
                    if (_kitchens > 0) {
                      setState(() {
                        _kitchens--;
                        _ensureListLength(_kitchenW, _kitchens);
                        _ensureListLength(_kitchenL, _kitchens);
                      });
                    }
                  },
                ),
                _sizesGrid(label: 'Kitchen', count: _kitchens, wList: _kitchenW, lList: _kitchenL),
              ] else if (_propertyType == 'Studio') ...[
                Builder(builder: (_) {
                  // Ensure the lists have length 1
                  _ensureListLength(_roomW, 1);
                  _ensureListLength(_roomL, 1);
                  return _sizesGrid(label: 'Studio', count: 1, wList: _roomW, lList: _roomL);
                }),
              ] else if (_propertyType == 'House') ...[
                _counterRow(
                  label: 'Rooms',
                  count: _rooms,
                  onAdd: () {
                    if (_rooms < 9) {
                      setState(() {
                        _rooms++;
                        _ensureListLength(_roomW, _rooms);
                        _ensureListLength(_roomL, _rooms);
                      });
                    }
                  },
                  onRemove: () {
                    if (_rooms > 0) {
                      setState(() {
                        _rooms--;
                        _ensureListLength(_roomW, _rooms);
                        _ensureListLength(_roomL, _rooms);
                      });
                    }
                  },
                ),
                _sizesGrid(label: 'Room', count: _rooms, wList: _roomW, lList: _roomL),
                _counterRow(
                  label: 'Halls',
                  count: _halls,
                  onAdd: () {
                    if (_halls < 9) {
                      setState(() {
                        _halls++;
                        _ensureListLength(_hallW, _halls);
                        _ensureListLength(_hallL, _halls);
                      });
                    }
                  },
                  onRemove: () {
                    if (_halls > 0) {
                      setState(() {
                        _halls--;
                        _ensureListLength(_hallW, _halls);
                        _ensureListLength(_hallL, _halls);
                      });
                    }
                  },
                ),
                _sizesGrid(label: 'Hall', count: _halls, wList: _hallW, lList: _hallL),
                _counterRow(
                  label: 'Kitchens',
                  count: _kitchens,
                  onAdd: () {
                    if (_kitchens < 9) {
                      setState(() {
                        _kitchens++;
                        _ensureListLength(_kitchenW, _kitchens);
                        _ensureListLength(_kitchenL, _kitchens);
                      });
                    }
                  },
                  onRemove: () {
                    if (_kitchens > 0) {
                      setState(() {
                        _kitchens--;
                        _ensureListLength(_kitchenW, _kitchens);
                        _ensureListLength(_kitchenL, _kitchens);
                      });
                    }
                  },
                ),
                _sizesGrid(label: 'Kitchen', count: _kitchens, wList: _kitchenW, lList: _kitchenL),
              ],
              // Floor (optional)
              TextFormField(controller:_floorC, decoration: _input('Floor (optional)')),

              const SizedBox(height: 16),


              // Bathroom
              const Text('Bathroom', style: TextStyle(fontWeight: FontWeight.w600)),
              Row(
                children: [
                  Expanded(child: RadioListTile<String>(value: 'Private', groupValue: _bathroom, title: const Text('Private'), onChanged: (v) => setState(()=>_bathroom=v!), dense:true, contentPadding: EdgeInsets.zero)),
                  Expanded(child: RadioListTile<String>(value: 'Shared', groupValue: _bathroom, title: const Text('Shared'), onChanged: (v) => setState(()=>_bathroom=v!), dense:true, contentPadding: EdgeInsets.zero)),
                ],
              ),
              const SizedBox(height: 8),

              // Price & Deposit
              const Text('Price', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height:6),
              TextFormField(controller: _priceC, keyboardType: TextInputType.number, decoration: _input('Price (NPR)', prefix: const Text('  रु', style: TextStyle(fontSize: 30))), validator: (v)=>(v==null||v.trim().isEmpty)?'Enter price':null),
              //Negotiable
              CheckboxListTile(value:_negotiable,onChanged:(v)=>setState(()=>_negotiable=v??false),title:const Text('Price negotiable'),controlAffinity: ListTileControlAffinity.leading,contentPadding: EdgeInsets.zero),
              // Parking Section
              const SizedBox(height: 16),
              const Text('Parking', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(
                spacing: 10,
                children: ['None', 'Bike', 'Car', 'Both'].map((value) => ChoiceChip(
                  label: Text(value),
                  selected: _parking == value,
                  onSelected: (_) => setState(() => _parking = value),
                )).toList(),
              ),

              const SizedBox(height: 16),
              // Amenities
              const Text('Amenities', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height:6),
              Wrap(spacing:10, runSpacing:6, children: _amenities.keys.map((k)=>FilterChip(label: Text(k), selected:_amenities[k]!, onSelected:(v)=>setState(()=>_amenities[k]=v))).toList()),

              const SizedBox(height:16),
              // Status + Date Section
              const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(
                spacing: 10,
                children: ['Vacant', 'To Be Vacant', 'Rented'].map((value) => ChoiceChip(
                  label: Text(value),
                  selected: _status == value,
                  onSelected: (_) => setState(() => _status = value),
                )).toList(),
              ),
              //conditional date piccker
              if (_status == 'To Be Vacant')
                TextButton.icon(
                  onPressed: () => _pickDate(forVacant: true),
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _availableFrom == null
                        ? 'Pick Available From'
                        : _availableFrom!.toLocal().toString().split(' ')[0],
                  ),
                ),

              if (_status == 'Rented')
                TextButton.icon(
                  onPressed: () => _pickDate(forVacant: false),
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _rentedSince == null
                        ? 'Pick Rented Since'
                        : _rentedSince!.toLocal().toString().split(' ')[0],
                  ),
                ),
              const SizedBox(height:16),
              // Nearby
              const Text('Nearby', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(spacing:10, runSpacing:6, children:_nearby.keys.map((k)=>FilterChip(label:Text(k), selected:_nearby[k]!, onSelected:(v)=>setState(()=>_nearby[k]=v))).toList()),

              const SizedBox(height:16),
              // Notes
              TextFormField(controller:_notesC,maxLines:3,decoration:_input('Notes / Additional Info')),

              const SizedBox(height:16),
              //images
              const Text('Images (max 5)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height:6),
              Row(children:[
                ElevatedButton.icon(onPressed:_pickImages, icon:const Icon(Icons.photo_library), label:const Text('Pick Images')),
                const SizedBox(width:12),
                Text('${_existingImages.length + _images.length}/5 selected')
              ]),
              if(_existingImages.isNotEmpty || _images.isNotEmpty)
                SizedBox(
                    height:100,
                    child:ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _existingImages.length + _images.length,
                        itemBuilder: (_,i){
                          if(i<_existingImages.length){
                            final url = _existingImages[i];
                            return Padding(
                                padding: const EdgeInsets.all(4),
                                child: Stack(
                                    children:[
                                      Image.network(url,width:100,height:100,fit:BoxFit.cover),
                                      Positioned(top:0,right:0,child:GestureDetector(onTap:()=>setState(()=>_existingImages.removeAt(i)),child:const Icon(Icons.cancel,color:Colors.red)))
                                    ]
                                )
                            );
                          } else {
                            final file = _images[i-_existingImages.length];
                            return Padding(
                                padding: const EdgeInsets.all(4),
                                child: Stack(
                                    children:[
                                      Image.file(File(file.path),width:100,height:100,fit:BoxFit.cover),
                                      Positioned(top:0,right:0,child:GestureDetector(onTap:()=>setState(()=>_images.removeAt(i-_existingImages.length)),child:const Icon(Icons.cancel,color:Colors.red)))
                                    ]
                                )
                            );
                          }
                        }
                    )
                ),
              const SizedBox(height:16),
              // Map & Address
              TextFormField(controller:_locationC, decoration:_input('Address',prefix: const Icon(Icons.location_on)), onChanged:_onLocationChanged, validator:(v)=>(v==null||v.trim().isEmpty)?'Enter location':null),
              const SizedBox(height:8),
              SizedBox(height:250, child:FlutterMap(mapController:_mapController, options:MapOptions(initialCenter:_selectedLocation, initialZoom:15, onTap:(tapPos, point){setState(()=>_selectedLocation=point);}), children:[
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.basobaas_map",),
                MarkerLayer(markers:[Marker(point:_selectedLocation,width:50,height:50,child:Icon(Icons.location_pin,color:_statusColor(),size:40))])
              ])),

              const SizedBox(height:24),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitPost,
                      child: const Text('Update Rental', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              )

            ],
          ),
        ),
      ),
    );
  }
}
