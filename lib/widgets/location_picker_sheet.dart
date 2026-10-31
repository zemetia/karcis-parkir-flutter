import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/parking_location.dart';
import '../models/parking_rate_rule.dart';
import '../providers/parking_provider.dart';
import 'edit_location_rule_dialog.dart';

class LocationPickerSheet extends StatefulWidget {
  final String? selectedLocationName;
  final String vehicleType;

  const LocationPickerSheet({
    super.key,
    this.selectedLocationName,
    this.vehicleType = 'Mobil',
  });

  static Future<ParkingLocation?> show(
    BuildContext context, {
    String? currentLocation,
    String vehicleType = 'Mobil',
  }) {
    return showModalBottomSheet<ParkingLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationPickerSheet(
        selectedLocationName: currentLocation,
        vehicleType: vehicleType,
      ),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Semua';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ParkingProvider>(context);
    final allLocations = provider.locationService.locations;

    // Filter categories
    final categories = [
      'Semua',
      'Mall / Pusat Belanja',
      'Stasiun & Terminal',
      'Bandara',
      'Pasar & Pinggir Jalan',
      'Fasilitas Umum',
    ];

    final searchQuery = _searchController.text.trim().toLowerCase();
    final filteredLocations = allLocations.where((loc) {
      final matchesSearch = loc.name.toLowerCase().contains(searchQuery) ||
          (loc.address != null && loc.address!.toLowerCase().contains(searchQuery)) ||
          loc.category.toLowerCase().contains(searchQuery);

      final matchesCategory = _selectedCategory == 'Semua' || loc.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Template Lokasi Parkir',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Otomatis terapkan aturan tarif sesuai lokasi',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cari lokasi (PTC, Grand Indonesia, Stasiun...)',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSel = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(cat, style: const TextStyle(fontSize: 11.5)),
                    selected: isSel,
                    selectedColor: const Color(0xFF2563EB),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : const Color(0xFF334155),
                      fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                    ),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isSel ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // List of locations
          Expanded(
            child: filteredLocations.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_off_outlined,
                              size: 40, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 8),
                          Text(
                            'Tidak ditemukan lokasi "${_searchController.text}"',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Buat Lokasi Ini'),
                            onPressed: () async {
                              final nav = Navigator.of(context);
                              final created = await EditLocationRuleDialog.show(
                                context,
                                location: ParkingLocation(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  name: _searchController.text.trim(),
                                  rates: {
                                    'Mobil': ParkingRateRule.defaultFor('Mobil'),
                                    'Motor': ParkingRateRule.defaultFor('Motor'),
                                  },
                                ),
                              );
                              if (created != null && mounted) {
                                nav.pop(created);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredLocations.length,
                    itemBuilder: (ctx, index) {
                      final loc = filteredLocations[index];
                      final isSelected = widget.selectedLocationName != null &&
                          widget.selectedLocationName!.toLowerCase() ==
                              loc.name.toLowerCase();

                      final vehicleRule = loc.getRateFor(widget.vehicleType);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        color: isSelected
                            ? const Color(0xFFEFF6FF)
                            : Colors.white,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).pop(loc);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFDBEAFE)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    loc.category.contains('Stasiun')
                                        ? Icons.train_rounded
                                        : (loc.category.contains('Bandara')
                                            ? Icons.flight_rounded
                                            : (loc.category.contains('Pasar')
                                                ? Icons.storefront_rounded
                                                : Icons.local_mall_rounded)),
                                    size: 18,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              loc.name,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected
                                                    ? const Color(0xFF1D4ED8)
                                                    : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              loc.category,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '⚡ ${widget.vehicleType}: ${vehicleRule.summaryDescription}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF2563EB), size: 20)
                                else
                                  const Icon(Icons.chevron_right_rounded,
                                      color: Color(0xFF94A3B8), size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),

          // Bottom "+ Tambah Lokasi Baru" button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFF2563EB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF2563EB)),
            label: const Text(
              'Tambah Lokasi Baru Sendiri',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
              ),
            ),
            onPressed: () async {
              final nav = Navigator.of(context);
              final created = await EditLocationRuleDialog.show(context);
              if (created != null && mounted) {
                nav.pop(created);
              }
            },
          ),
        ],
      ),
    );
  }
}
