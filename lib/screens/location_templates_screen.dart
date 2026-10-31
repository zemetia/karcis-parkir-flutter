import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/parking_location.dart';
import '../providers/parking_provider.dart';
import '../widgets/edit_location_rule_dialog.dart';

class LocationTemplatesScreen extends StatefulWidget {
  const LocationTemplatesScreen({super.key});

  @override
  State<LocationTemplatesScreen> createState() => _LocationTemplatesScreenState();
}

class _LocationTemplatesScreenState extends State<LocationTemplatesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Semua';
  final _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  final List<String> _categories = [
    'Semua',
    'Mall / Pusat Belanja',
    'Stasiun & Terminal',
    'Bandara',
    'Pasar & Pinggir Jalan',
    'Fasilitas Umum',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showTestSimulatorDialog(BuildContext context, ParkingLocation location) {
    String selectedVehicle = 'Mobil';
    double sliderHours = 3.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final rule = location.getRateFor(selectedVehicle);
          final minutes = (sliderHours * 60).round();
          final duration = Duration(minutes: minutes);
          final cost = rule.calculateCost(duration);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.calculate_rounded, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Simulasi Tarif: ${location.name}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uji coba kalkulasi biaya parkir berdasarkan aturan di lokasi ini.',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),

                // Vehicle Selector
                Row(
                  children: ['Mobil', 'Motor', 'Truk'].map((v) {
                    final isSel = selectedVehicle == v;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(v, style: const TextStyle(fontSize: 12)),
                        selected: isSel,
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : const Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() {
                              selectedVehicle = v;
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Rule Summary
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    rule.summaryDescription,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Slider duration
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Durasi Parkir:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(
                      sliderHours == 24
                          ? '24 jam (1 Hari)'
                          : '${sliderHours.toStringAsFixed(1)} jam',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: sliderHours,
                  min: 0.5,
                  max: 24.0,
                  divisions: 47,
                  label: '${sliderHours.toStringAsFixed(1)} jam',
                  onChanged: (val) {
                    setDialogState(() {
                      sliderHours = val;
                    });
                  },
                ),

                // Result Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Total Estimasi Biaya:',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF166534)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormat.format(cost),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tutup'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ParkingProvider>(context);
    final allLocations = provider.locationService.locations;

    final searchQuery = _searchController.text.trim().toLowerCase();
    final filteredLocations = allLocations.where((loc) {
      final matchesSearch = loc.name.toLowerCase().contains(searchQuery) ||
          (loc.address != null && loc.address!.toLowerCase().contains(searchQuery)) ||
          loc.category.toLowerCase().contains(searchQuery);

      final matchesCategory =
          _selectedCategory == 'Semua' || loc.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Lokasi & Template Parkir'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Opsi Template',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) async {
              if (val == 'reset') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reset ke Template Asli?'),
                    content: const Text(
                      'Semua template bawaan (PTC, Grand Indonesia, dll) akan dikembalikan ke aturan awal.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await provider.resetParkingLocationsToDefault();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Template lokasi berhasil direset ke bawaan.'),
                        backgroundColor: Color(0xFF059669),
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt_rounded, size: 18, color: Color(0xFFDC2626)),
                    SizedBox(width: 8),
                    Text('Reset Template Bawaan'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari template lokasi (Mall PTC, Stasiun, Flat...)',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
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
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Locations list
          Expanded(
            child: filteredLocations.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_off_outlined,
                              size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada template lokasi "${_searchController.text}"',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Buat Lokasi Baru'),
                            onPressed: () => EditLocationRuleDialog.show(context),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredLocations.length,
                    itemBuilder: (ctx, index) {
                      final loc = filteredLocations[index];
                      final mobilRule = loc.getRateFor('Mobil');
                      final motorRule = loc.getRateFor('Motor');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top title row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      loc.category.contains('Stasiun')
                                          ? Icons.train_rounded
                                          : (loc.category.contains('Bandara')
                                              ? Icons.flight_rounded
                                              : (loc.category.contains('Pasar')
                                                  ? Icons.storefront_rounded
                                                  : Icons.local_mall_rounded)),
                                      color: const Color(0xFF2563EB),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                loc.name,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            if (loc.isDefaultTemplate)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Template',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (loc.address != null &&
                                            loc.address!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            loc.address!,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 10),

                              // Rates preview rows
                              _buildRateRow(
                                icon: Icons.two_wheeler_rounded,
                                label: 'Motor',
                                description: motorRule.summaryDescription,
                              ),
                              const SizedBox(height: 6),
                              _buildRateRow(
                                icon: Icons.directions_car_rounded,
                                label: 'Mobil',
                                description: mobilRule.summaryDescription,
                              ),
                              const SizedBox(height: 12),

                              // Action buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Simulator button
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.calculate_outlined,
                                        size: 15, color: Color(0xFF2563EB)),
                                    label: const Text(
                                      'Tes Hitung',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _showTestSimulatorDialog(context, loc),
                                  ),
                                  const SizedBox(width: 8),

                                  // Edit button
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.edit_rounded, size: 14),
                                    label: const Text(
                                      'Sesuaikan Aturan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: () => EditLocationRuleDialog.show(
                                        context,
                                        location: loc),
                                  ),

                                  if (!loc.isDefaultTemplate) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: Color(0xFFDC2626)),
                                      tooltip: 'Hapus Lokasi',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text('Hapus "${loc.name}"?'),
                                            content: const Text(
                                                'Lokasi kustom ini akan dihapus dari daftar.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(false),
                                                child: const Text('Batal'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFFDC2626),
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(true),
                                                child: const Text('Hapus'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await provider
                                              .deleteParkingLocation(loc.id);
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Tambah Lokasi', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => EditLocationRuleDialog.show(context),
      ),
    );
  }

  Widget _buildRateRow({
    required IconData icon,
    required String label,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
