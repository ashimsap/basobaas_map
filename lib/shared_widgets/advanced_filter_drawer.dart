import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:basobaas_map/provider/post_provider.dart';

class AdvancedFilterDrawer extends StatefulWidget {
  const AdvancedFilterDrawer({super.key});

  @override
  State<AdvancedFilterDrawer> createState() => _AdvancedFilterDrawerState();
}

class _AdvancedFilterDrawerState extends State<AdvancedFilterDrawer> {
  // Controllers
  final TextEditingController locationController = TextEditingController();
  final TextEditingController minPriceController = TextEditingController();
  final TextEditingController maxPriceController = TextEditingController();

  // Date range
  DateTime? startDate;
  DateTime? endDate;

  // Amenities
  final List<String> allAmenities = ["WiFi", "Water", "Hot Water", "Electricity", "Furnished", "AC/Heating", "laundry", "Pet Friendly", "Garbage", "Balcony"];
  final Set<String> selectedAmenities = {};

  // Parking
  String? parkingFilter;

  // Nearby
  final List<String> allNearby = ["Hospital","Garage", "School", "Market", "Bus Stop", "Pharmacy", "Gym", "Park", "Temple", "Swimming Pool", "Mall"];
  final Set<String> selectedNearby = {};

  @override
  void initState() {
    super.initState();
    final provider = context.read<PostProvider>();

    // Initialize local state from provider
    startDate = provider.startDate;
    endDate = provider.endDate;
    locationController.text = provider.locationKeyword ?? "";
    selectedAmenities.addAll(provider.amenitiesFilter);
    parkingFilter = provider.parkingFilter;
    selectedNearby.addAll(provider.nearbyFilter);
    minPriceController.text = provider.minPrice?.toString() ?? "";
    maxPriceController.text = provider.maxPrice?.toString() ?? "";
  }

  @override
  void dispose() {
    locationController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    final provider = context.read<PostProvider>();

    setState(() {
      startDate = null;
      endDate = null;
      locationController.clear();
      minPriceController.clear();
      maxPriceController.clear();
      selectedAmenities.clear();
      parkingFilter = null;
      selectedNearby.clear();
    });

    provider.resetFilters();
    Navigator.of(context).pop();
  }

  Widget _decoratedTextField({
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _decoratedDateButton({
    required String label,
    required DateTime? date,
    required void Function() onPressed,
  }) {
    return Expanded(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: Colors.grey[100],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date != null ? "$label: ${date.toLocal().toString().split(' ')[0]}" : label,
              style: const TextStyle(color: Colors.black87),
            ),
            SizedBox(width: 12,),
            Icon(Icons.calendar_month, size: 23,)
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PostProvider>();
    final height = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: height * 0.85),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 10 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0,0,0,5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: const Text(
                  "Advanced Filters",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),

              // Price
              const Text("Price Range"),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _decoratedTextField(
                      hint: "Min Price",
                      controller: minPriceController,
                      keyboardType: TextInputType.number,
                      onChanged: (val) => provider.setPriceRange(
                        double.tryParse(val),
                        provider.maxPrice,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _decoratedTextField(
                      hint: "Max Price",
                      controller: maxPriceController,
                      keyboardType: TextInputType.number,
                      onChanged: (val) => provider.setPriceRange(
                        provider.minPrice,
                        double.tryParse(val),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date
              const Text("Date Range"),
              Row(
                children: [
                  _decoratedDateButton(
                    label: "From:",
                    date: startDate,
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => startDate = picked);
                    },
                  ),
                  const SizedBox(width: 12),
                  _decoratedDateButton(
                    label: "To:",
                    date: endDate,
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => endDate = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location
              _decoratedTextField(
                hint: "Location",
                controller: locationController,
              ),
              const SizedBox(height: 16),

              // Amenities
              const Text("Amenities"),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: allAmenities.map((amenity) {
                  final selected = selectedAmenities.contains(amenity);
                  return FilterChip(
                    label: Text(amenity),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        if (selected) selectedAmenities.remove(amenity);
                        else selectedAmenities.add(amenity);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Parking
              const Text("Parking"),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ["Car", "Bike", "Both"].map((option) {
                  final selected = parkingFilter == option;
                  return FilterChip(
                    label: Text(option),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        parkingFilter = selected ? null : option;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Nearby
              const Text("Nearby Places"),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: allNearby.map((place) {
                  final selected = selectedNearby.contains(place);
                  return FilterChip(
                    label: Text(place),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        if (selected) selectedNearby.remove(place);
                        else selectedNearby.add(place);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _resetFilters,

                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "Reset Filters",
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        provider.setPriceRange(
                          double.tryParse(minPriceController.text),
                          double.tryParse(maxPriceController.text),
                        );
                        provider.setDateRange(startDate, endDate);
                        provider.setLocationKeyword(
                          locationController.text.isNotEmpty ? locationController.text : null,
                        );
                        provider.setAmenitiesFilter(selectedAmenities);
                        provider.setParkingFilter(parkingFilter);
                        provider.setNearbyFilter(selectedNearby);

                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        "Apply Filters",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
