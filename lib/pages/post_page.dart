import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart' as geo;

import '../provider/auth_provider.dart';
import '../provider/post_provider.dart';
import '../shared_widgets/account_warning_dialog.dart';

class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _titleC = TextEditingController();
  final TextEditingController _descC = TextEditingController();
  final TextEditingController _priceC = TextEditingController();
  final TextEditingController _depositC = TextEditingController();
  final TextEditingController _locationC = TextEditingController();
  final TextEditingController _notesC = TextEditingController();
  final TextEditingController _floorC = TextEditingController();

  // Property info
  String _propertyType = 'Room';
  int _rooms = 0, _halls = 0, _kitchens = 0;
  final List<TextEditingController> _roomW = [], _roomL = [];
  final List<TextEditingController> _hallW = [], _hallL = [];
  final List<TextEditingController> _kitchenW = [], _kitchenL = [];

  String _bathroom = 'Private';
  String _parking = 'None';
  bool _negotiable = false;

  String _status = 'Vacant';
  DateTime? _availableFrom;

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
    'Swimming Pool': false,
    'Mall': false,
  };

  final Map<String, bool> _amenities = {
    'WiFi': false,
    'Water': false,
    'Hot Water': false,
    'Electricity': false,
    'Furnished': false,
    'AC/Heating': false,
    'Laundry': false,
    'Pet Friendly': false,
    'Garbage': false,
    'Balcony': false,
  };

  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();

  LatLng _selectedLocation = LatLng(27.7172, 85.3240);
  final MapController _mapController = MapController();
  Timer? _debounce;

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _priceC.dispose();
    _locationC.dispose();
    _notesC.dispose();
    _floorC.dispose();
    for (final c in [..._roomW, ..._roomL, ..._hallW, ..._hallL, ..._kitchenW, ..._kitchenL]) {
      c.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }

  // Clear all text fields and reset state
  void _clearForm() {
    _titleC.clear();
    _descC.clear();
    _priceC.clear();
    _depositC.clear();
    _locationC.clear();
    _notesC.clear();
    _floorC.clear();
    for (final c in [..._roomW, ..._roomL, ..._hallW, ..._hallL, ..._kitchenW, ..._kitchenL]) {
      c.clear();
    }

    setState(() {
      _images.clear();
      _propertyType = 'Room';
      _rooms = _halls = _kitchens = 0;
      _bathroom = 'Private';
      _parking = 'None';
      _negotiable = false;
      _status = 'Vacant';
      _availableFrom = null;
      _amenities.updateAll((key, value) => false);
      _nearby.updateAll((key, value) => false);
      _selectedLocation = LatLng(27.7172, 85.3240);
    });
  }


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
        IconButton(onPressed: count > 0 ? onRemove : null, icon: const Icon(Icons.remove_circle_outline)),
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
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter width' : null,
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
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter length' : null,
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
      case 'To Be Vacant':
        return Colors.orange;
      case 'Rented':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  Future<void> _pickDate({required bool forVacant}) async {
    final now = DateTime.now();
    final initial = _availableFrom ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (forVacant) _availableFrom = picked;
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
      } catch (_) {}
    });
  }

  void _submitPost() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    if (_formKey.currentState!.validate()) {
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
      final postData = {
        'title': _titleC.text.trim(),
        'description': _descC.text.trim(),
        'propertyType': _propertyType,
        'rooms': _rooms,
        'halls': _halls,
        'kitchens': _kitchens,
        'price': int.tryParse(_priceC.text.trim()) ?? 0,
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
      };

      try {
        await postProvider.postRental(metadata: postData, images: _images, userId: authProvider.user!.uid);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post submitted successfully!')));
        _clearForm();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit post: $e')));
      }
    }
  }

  void navigateToPostPage(BuildContext context, AuthProvider authProvider) {
    final needEmail = !authProvider.isVerified();
    final needPhone = authProvider.phones.isEmpty;

    if (needEmail || needPhone) {
      // Show blocking warning
      showDialog(
        context: context,
        barrierDismissible: false, // user cannot dismiss by tapping outside
        builder: (_) => AccountWarningDialog(
          needEmailVerification: needEmail,
          needPhone: needPhone,
        ),
      );
    } else {
      Navigator.pushNamed(context, '/postPage');
    }
  }


  Widget _statusChip(String value) {
    return ChoiceChip(
      label: Text(value),
      selected: _status == value,
      onSelected: (_) => setState(() => _status = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a Rental'), centerTitle: true),
      backgroundColor: const Color(0xFFF7F7F7),
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

              const SizedBox(height: 16),
              // Amenities
              const Text('Amenities', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height:6),
              Wrap(spacing:10, runSpacing:6, children: _amenities.keys.map((k)=>FilterChip(label: Text(k), selected:_amenities[k]!, onSelected:(v)=>setState(()=>_amenities[k]=v))).toList()),

              const SizedBox(height:16),
              // Status + Dates
              const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(spacing:10, children: ['Vacant','To Be Vacant'].map(_statusChip).toList()),
              if(_status=='To Be Vacant')
                TextButton.icon(onPressed: ()=>_pickDate(forVacant:true), icon: const Icon(Icons.date_range), label: Text(_availableFrom==null?'Pick Available From':_availableFrom!.toLocal().toString().split(' ')[0])),

              const SizedBox(height:16),
              // Nearby
              const Text('Nearby', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(spacing:10, runSpacing:6, children:_nearby.keys.map((k)=>FilterChip(label:Text(k), selected:_nearby[k]!, onSelected:(v)=>setState(()=>_nearby[k]=v))).toList()),

              const SizedBox(height:16),
              // Notes
              TextFormField(controller:_notesC,maxLines:3,decoration:_input('Notes / Additional Info')),

              const SizedBox(height:16),
              // Images
              const Text('Images (max 5)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height:6),
              Row(children:[
                ElevatedButton.icon(onPressed:_pickImages, icon:const Icon(Icons.photo_library), label:const Text('Pick Images')),
                const SizedBox(width:12),
                Text('${_images.length}/5 selected')
              ]),
              if(_images.isNotEmpty)
                SizedBox(height:100, child:ListView.builder(scrollDirection: Axis.horizontal,itemCount:_images.length,itemBuilder:(_,i)=>Padding(padding:const EdgeInsets.all(4), child:Stack(children:[
                  Image.file(File(_images[i].path), width:100,height:100,fit:BoxFit.cover),
                  Positioned(top:0,right:0,child:GestureDetector(onTap:()=>setState(()=>_images.removeAt(i)),child:const Icon(Icons.cancel,color:Colors.red)))
                ])))),

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
              SizedBox(width:double.infinity, child:ElevatedButton(onPressed:_submitPost,child:const Text('Submit Post', style:TextStyle(fontSize:16))))
            ],
          ),
        ),
      ),
    );
  }
}
