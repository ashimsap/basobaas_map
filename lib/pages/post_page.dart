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
  DateTime? _filledSince;

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
    _depositC.dispose();
    _locationC.dispose();
    _notesC.dispose();
    for (final c in [..._roomW, ..._roomL, ..._hallW, ..._hallL, ..._kitchenW, ..._kitchenL]) {
      c.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }

  // ----------------- UI Helpers -----------------
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
    while (list.length < newLen) list.add(TextEditingController());
    while (list.length > newLen) list.removeLast().dispose();
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
        if (forVacant) _availableFrom = picked;
        else _filledSince = picked;
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

  // ----------------- Submit -----------------
  void _submitPost() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    if (!authProvider.isVerified()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verify your account through profile page to post a rental.")),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final selectedAmenities = _amenities.entries.where((e) => e.value).map((e) => e.key).toList();
      final selectedNearby = _nearby.entries.where((e) => e.value).map((e) => e.key).toList();

      final roomSizes = List.generate(_rooms, (i) => {'width': _roomW[i].text.trim(), 'length': _roomL[i].text.trim()});
      final hallSizes = List.generate(_halls, (i) => {'width': _hallW[i].text.trim(), 'length': _hallL[i].text.trim()});
      final kitchenSizes = List.generate(_kitchens, (i) => {'width': _kitchenW[i].text.trim(), 'length': _kitchenL[i].text.trim()});

      String parkingValue = _parking == 'Both' ? 'Bike & Car' : _parking;

      final postData = {
        'title': _titleC.text.trim(),
        'description': _descC.text.trim(),
        'propertyType': _propertyType,
        'rooms': _rooms,
        'halls': _halls,
        'kitchens': _kitchens,
        'price': _priceC.text.trim(),
        'deposit': _depositC.text.trim(),
        'location': {'latitude': _selectedLocation.latitude, 'longitude': _selectedLocation.longitude},
        'amenities': selectedAmenities,
        'nearby': selectedNearby,
        'contact': {'name': authProvider.displayName ?? '', 'email': authProvider.email ?? ''},
        'negotiable': _negotiable,
        'bathroom': _bathroom,
        'parking': parkingValue,
        'status': _status,
        'availableFrom': _availableFrom?.toIso8601String(),
        'filledSince': _filledSince?.toIso8601String(),
        'roomSizes': roomSizes,
        'hallSizes': hallSizes,
        'kitchenSizes': kitchenSizes,
        'notes': _notesC.text.trim(),
        'typedAddress': _locationC.text.trim(),
      };

      try {
        await postProvider.postRental(metadata: postData, images: _images, userId: authProvider.user!.uid);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post submitted successfully!')));

        setState(() {
          _images.clear();
          _rooms = _halls = _kitchens = 0;
          _amenities.updateAll((key, value) => false);
          _nearby.updateAll((key, value) => false);
          _availableFrom = null;
          _filledSince = null;
          _formKey.currentState?.reset();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit post: $e')));
      }
    }
  }

  // ----------------- Chips -----------------
  Widget _parkingChip(String value) => ChoiceChip(
    label: Text(value),
    selected: _parking == value,
    onSelected: (_) => setState(() => _parking = value),
  );

  Widget _statusChip(String value) {
    final label = switch (value) {
      'Vacant' => 'Vacant',
      'ToBeVacant' => 'To be vacant (from)',
      'Filled' => 'Filled (since)',
      _ => value,
    };
    return ChoiceChip(
      label: Text(label),
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

              // Rooms/Halls/Kitchens
              _counterRow(label: 'Rooms', count: _rooms, onAdd: () { setState(() { _rooms++; _ensureListLength(_roomW, _rooms); _ensureListLength(_roomL, _rooms); }); }, onRemove: () { setState(() { if (_rooms>0)_rooms--; _ensureListLength(_roomW,_rooms); _ensureListLength(_roomL,_rooms); }); }),
              _sizesGrid(label: 'Room', count: _rooms, wList: _roomW, lList: _roomL),
              const SizedBox(height: 8),
              _counterRow(label: 'Halls', count: _halls, onAdd: () { setState(() { _halls++; _ensureListLength(_hallW,_halls); _ensureListLength(_hallL,_halls); }); }, onRemove: () { setState(() { if (_halls>0)_halls--; _ensureListLength(_hallW,_halls); _ensureListLength(_hallL,_halls); }); }),
              _sizesGrid(label: 'Hall', count: _halls, wList: _hallW, lList: _hallL),
              const SizedBox(height: 8),
              _counterRow(label: 'Kitchens', count: _kitchens, onAdd: () { setState(() { _kitchens++; _ensureListLength(_kitchenW,_kitchens); _ensureListLength(_kitchenL,_kitchens); }); }, onRemove: () { setState(() { if (_kitchens>0)_kitchens--; _ensureListLength(_kitchenW,_kitchens); _ensureListLength(_kitchenL,_kitchens); }); }),
              _sizesGrid(label: 'Kitchen', count: _kitchens, wList: _kitchenW, lList: _kitchenL),

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
              // Parking
              const Text('Parking', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(spacing: 10, children: ['None','Bike','Car','Both'].map(_parkingChip).toList()),
              const SizedBox(height: 16),
              // Price & Deposit
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _priceC, keyboardType: TextInputType.number, decoration: _input('Price (NPR)', prefix: const Text('  रु', style: TextStyle(fontSize: 30))), validator: (v)=>(v==null||v.trim().isEmpty)?'Enter price':null)),
                  const SizedBox(width:12),
                  Expanded(child: TextFormField(controller:_depositC, keyboardType: TextInputType.number, decoration: _input('Deposit (optional)', prefix: const Icon(Icons.savings)))),
                ],
              ),
              CheckboxListTile(value:_negotiable,onChanged:(v)=>setState(()=>_negotiable=v??false),title:const Text('Price negotiable'),controlAffinity: ListTileControlAffinity.leading,contentPadding: EdgeInsets.zero),
              const SizedBox(height: 16),
              // Amenities
              const Text('Amenities', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height:6),
              Wrap(spacing:10, runSpacing:6, children: _amenities.keys.map((k)=>FilterChip(label: Text(k), selected:_amenities[k]!, onSelected:(v)=>setState(()=>_amenities[k]=v))).toList()),
              const SizedBox(height:16),
              // Status + Dates
              const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(spacing:10, children: ['Vacant','ToBeVacant','Filled'].map(_statusChip).toList()),
              if(_status=='ToBeVacant')
                TextButton.icon(onPressed: ()=>_pickDate(forVacant:true), icon: const Icon(Icons.date_range), label: Text(_availableFrom==null?'Pick Available From':_availableFrom!.toLocal().toString().split(' ')[0])),
              if(_status=='Filled')
                TextButton.icon(onPressed: ()=>_pickDate(forVacant:false), icon: const Icon(Icons.date_range), label: Text(_filledSince==null?'Pick Filled Since':_filledSince!.toLocal().toString().split(' ')[0])),
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
                TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName:'com.example.app'),
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
