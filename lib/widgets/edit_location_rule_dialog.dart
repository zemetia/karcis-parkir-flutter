import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/parking_location.dart';
import '../models/parking_rate_rule.dart';
import '../providers/parking_provider.dart';

class EditLocationRuleDialog extends StatefulWidget {
  final ParkingLocation? initialLocation;

  const EditLocationRuleDialog({
    super.key,
    this.initialLocation,
  });

  static Future<ParkingLocation?> show(
    BuildContext context, {
    ParkingLocation? location,
  }) {
    return showModalBottomSheet<ParkingLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditLocationRuleDialog(initialLocation: location),
    );
  }

  @override
  State<EditLocationRuleDialog> createState() => _EditLocationRuleDialogState();
}

class _EditLocationRuleDialogState extends State<EditLocationRuleDialog> {
  final _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _addressController;

  String _selectedVehicle = 'Mobil';
  final List<String> _vehicles = ['Mobil', 'Motor', 'Truk'];

  // Map of vehicle to its edited rule state
  late Map<String, ParkingRateRule> _ratesMap;

  // Controllers for current selected vehicle rate
  late TextEditingController _flatRateController;
  late TextEditingController _initialHoursController;
  late TextEditingController _initialRateController;
  late TextEditingController _hourlyRateController;
  late TextEditingController _dailyMaxController;
  late TextEditingController _gracePeriodController;
  List<RateTier> _currentTiers = [];
  bool _isFlatRate = false;
  bool _isTiered = false;

  final List<String> _categorySuggestions = [
    'Mall / Pusat Belanja',
    'Stasiun & Terminal',
    'Bandara',
    'Pasar & Pinggir Jalan',
    'Fasilitas Umum',
    'Perkantoran & Ruko',
  ];

  @override
  void initState() {
    super.initState();
    final loc = widget.initialLocation;
    _nameController = TextEditingController(text: loc?.name ?? '');
    _categoryController = TextEditingController(
        text: loc?.category ?? 'Mall / Pusat Belanja');
    _addressController = TextEditingController(text: loc?.address ?? '');

    _ratesMap = {};
    for (final v in _vehicles) {
      if (loc != null && loc.rates.containsKey(v)) {
        _ratesMap[v] = loc.rates[v]!;
      } else {
        _ratesMap[v] = ParkingRateRule.defaultFor(v);
      }
    }

    _flatRateController = TextEditingController();
    _initialHoursController = TextEditingController();
    _initialRateController = TextEditingController();
    _hourlyRateController = TextEditingController();
    _dailyMaxController = TextEditingController();
    _gracePeriodController = TextEditingController();

    _syncControllersForVehicle(_selectedVehicle);
  }

  void _syncControllersForVehicle(String vehicle) {
    final rule = _ratesMap[vehicle] ?? ParkingRateRule.defaultFor(vehicle);
    _isFlatRate = rule.isFlatRate;
    _isTiered = rule.tiers.isNotEmpty || rule.initialHours > 1;

    _flatRateController.text = (rule.flatRate > 0 ? rule.flatRate : rule.firstHourRate).toString();
    _initialHoursController.text = rule.effectiveInitialHours.toString();
    _initialRateController.text = rule.effectiveInitialRate.toString();
    _hourlyRateController.text = rule.hourlyRate.toString();
    _dailyMaxController.text = rule.dailyMaxRate.toString();
    _gracePeriodController.text = rule.gracePeriodMinutes.toString();
    _currentTiers = List.from(rule.tiers);
  }

  void _saveCurrentVehicleRule() {
    final flat = int.tryParse(_flatRateController.text.trim()) ?? 0;
    final initH = int.tryParse(_initialHoursController.text.trim()) ?? 1;
    final initR = int.tryParse(_initialRateController.text.trim()) ?? 4000;
    final hourly = int.tryParse(_hourlyRateController.text.trim()) ?? 3000;
    final daily = int.tryParse(_dailyMaxController.text.trim()) ?? 0;
    final grace = int.tryParse(_gracePeriodController.text.trim()) ?? 0;

    _ratesMap[_selectedVehicle] = ParkingRateRule(
      firstHourRate: initR,
      hourlyRate: _isFlatRate ? 0 : hourly,
      dailyMaxRate: daily,
      gracePeriodMinutes: grace,
      isFlatRate: _isFlatRate,
      flatRate: flat,
      initialHours: _isFlatRate ? 1 : initH,
      initialRate: initR,
      tiers: _isFlatRate ? const [] : List.from(_currentTiers),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _addressController.dispose();
    _flatRateController.dispose();
    _initialHoursController.dispose();
    _initialRateController.dispose();
    _hourlyRateController.dispose();
    _dailyMaxController.dispose();
    _gracePeriodController.dispose();
    super.dispose();
  }

  ParkingRateRule _buildCurrentPreviewRule() {
    final flat = int.tryParse(_flatRateController.text.trim()) ?? 0;
    final initH = int.tryParse(_initialHoursController.text.trim()) ?? 1;
    final initR = int.tryParse(_initialRateController.text.trim()) ?? 4000;
    final hourly = int.tryParse(_hourlyRateController.text.trim()) ?? 3000;
    final daily = int.tryParse(_dailyMaxController.text.trim()) ?? 0;
    final grace = int.tryParse(_gracePeriodController.text.trim()) ?? 0;

    return ParkingRateRule(
      firstHourRate: initR,
      hourlyRate: _isFlatRate ? 0 : hourly,
      dailyMaxRate: daily,
      gracePeriodMinutes: grace,
      isFlatRate: _isFlatRate,
      flatRate: flat,
      initialHours: _isFlatRate ? 1 : initH,
      initialRate: initR,
      tiers: _isFlatRate ? const [] : List.from(_currentTiers),
    );
  }

  void _addTierDialog() {
    final afterController = TextEditingController(text: '4');
    final rateController = TextEditingController(text: '5000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.stairs_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Tambah Jenjang Tarif', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tentukan perubahan tarif per jam setelah kendaraan parkir lebih dari X jam.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: afterController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Setelah Berapa Jam Parkir?',
                hintText: '4',
                suffixText: 'jam',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tarif Per Jam di Jenjang Ini',
                hintText: '6000',
                prefixText: 'Rp ',
                suffixText: '/jam',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final after = int.tryParse(afterController.text.trim()) ?? 0;
              final rate = int.tryParse(rateController.text.trim()) ?? 0;
              if (after > 0 && rate > 0) {
                setState(() {
                  _currentTiers.removeWhere((t) => t.afterHours == after);
                  _currentTiers.add(RateTier(afterHours: after, hourlyRate: rate));
                  _currentTiers.sort((a, b) => a.afterHours.compareTo(b.afterHours));
                });
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Simpan Jenjang'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewRule = _buildCurrentPreviewRule();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_location_alt_rounded,
                    color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.initialLocation == null
                          ? 'Tambah Lokasi & Aturan Parkir'
                          : 'Edit Aturan: ${widget.initialLocation!.name}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Sesuaikan aturan tarif per jam, sekali bayar, atau berjenjang',
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
          const Divider(height: 20),

          // Scrollable form body
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Lokasi (Nama, Kategori, Alamat)
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nama Lokasi / Tempat Parkir *',
                      hintText: 'Misal: Mall PTC, Grand Indonesia, RS Sardjito',
                      prefixIcon: const Icon(Icons.business_rounded, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _categoryController,
                          decoration: InputDecoration(
                            labelText: 'Kategori',
                            hintText: 'Mall / Pusat Belanja',
                            prefixIcon: const Icon(Icons.category_outlined, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _categorySuggestions.map((cat) {
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _categoryController.text = cat;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            cat,
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Alamat / Area (Opsional)',
                      hintText: 'Misal: Jl. Raya Surabaya Barat',
                      prefixIcon: const Icon(Icons.place_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Vehicle Selector Tabs
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: _vehicles.map((v) {
                        final isSel = _selectedVehicle == v;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _saveCurrentVehicleRule();
                              setState(() {
                                _selectedVehicle = v;
                                _syncControllersForVehicle(v);
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: isSel
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    v == 'Motor'
                                        ? Icons.two_wheeler_rounded
                                        : (v == 'Truk'
                                            ? Icons.local_shipping_rounded
                                            : Icons.directions_car_rounded),
                                    size: 16,
                                    color: isSel ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    v,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      color: isSel ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pricing Mode Selector: [Per Jam Standar] [Sekali Bayar (Flat)] [Berjenjang Bertingkat]
                  const Text(
                    'Pilih Skema Tarif:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Per Jam', style: TextStyle(fontSize: 11.5)),
                          selected: !_isFlatRate && !_isTiered,
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(
                            color: (!_isFlatRate && !_isTiered) ? Colors.white : const Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _isFlatRate = false;
                                _isTiered = false;
                                _currentTiers.clear();
                                _initialHoursController.text = '1';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Sekali Bayar', style: TextStyle(fontSize: 11.5)),
                          selected: _isFlatRate,
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(
                            color: _isFlatRate ? Colors.white : const Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _isFlatRate = true;
                                _isTiered = false;
                                if (_flatRateController.text.isEmpty || _flatRateController.text == '0') {
                                  _flatRateController.text = _selectedVehicle == 'Motor' ? '2000' : '5000';
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Berjenjang', style: TextStyle(fontSize: 11.5)),
                          selected: !_isFlatRate && _isTiered,
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(
                            color: (!_isFlatRate && _isTiered) ? Colors.white : const Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _isFlatRate = false;
                                _isTiered = true;
                                if (_currentTiers.isEmpty) {
                                  _currentTiers.add(const RateTier(afterHours: 4, hourlyRate: 6000));
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Form fields based on selected mode
                  if (_isFlatRate) ...[
                    // Flat Rate inputs
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Skema Sekali Bayar (Flat): Bayar satu nominal tetap saat masuk/keluar tanpa hitungan per jam.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _flatRateController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Tarif Sekali Parkir (Flat)',
                              prefixText: 'Rp ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Hourly / Tiered inputs
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _initialHoursController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    labelText: 'Durasi Awal',
                                    hintText: '1',
                                    suffixText: 'jam',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _initialRateController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    labelText: 'Tarif Jam Awal',
                                    hintText: '4000',
                                    prefixText: 'Rp ',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _hourlyRateController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: _isTiered
                                  ? 'Tarif Jam Berikutnya (Tahap Normal)'
                                  : 'Tarif Jam Berikutnya (+Rp/jam)',
                              hintText: '3000',
                              prefixText: 'Rp ',
                              suffixText: '/jam',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),

                          // If Tiered mode: Show list of additional tiers
                          if (_isTiered) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Jenjang Tarif Tambahan (Setelah X Jam):',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('Tambah Jenjang', style: TextStyle(fontSize: 11.5)),
                                  onPressed: _addTierDialog,
                                ),
                              ],
                            ),
                            if (_currentTiers.isEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Text(
                                  'Belum ada jenjang tambahan. Klik "+ Tambah Jenjang" untuk mengatur kenaikan tarif setelah X jam (misal setelah 4 jam di Mall PTC).',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                              ),
                            ] else ...[
                              ..._currentTiers.map((tier) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.trending_up_rounded,
                                          size: 16, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Setelah ${tier.afterHours} jam ➔ ${_currencyFormat.format(tier.hourlyRate)} / jam',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 18, color: Color(0xFFDC2626)),
                                        tooltip: 'Hapus Jenjang',
                                        onPressed: () {
                                          setState(() {
                                            _currentTiers.remove(tier);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Grace Period and Daily Max
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _gracePeriodController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Bebas Biaya (Grace)',
                            hintText: '0',
                            suffixText: 'mnt',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _dailyMaxController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Maksimal Sehari (24 jam)',
                            hintText: '0 = tanpa batas',
                            prefixText: 'Rp ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Live Simulation Calculator Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calculate_rounded,
                                size: 16, color: Color(0xFF15803D)),
                            const SizedBox(width: 6),
                            Text(
                              'Simulasi Tarif ($_selectedVehicle):',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildSimBadge('1 Jam', previewRule.calculateCost(const Duration(hours: 1))),
                            _buildSimBadge('2 Jam', previewRule.calculateCost(const Duration(hours: 2))),
                            _buildSimBadge('3 Jam', previewRule.calculateCost(const Duration(hours: 3))),
                            _buildSimBadge('5 Jam', previewRule.calculateCost(const Duration(hours: 5))),
                            _buildSimBadge('8 Jam', previewRule.calculateCost(const Duration(hours: 8))),
                            _buildSimBadge('24 Jam', previewRule.calculateCost(const Duration(hours: 24))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Bottom Action: Simpan
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nama lokasi parkir wajib diisi!'),
                    backgroundColor: Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              _saveCurrentVehicleRule();

              final loc = ParkingLocation(
                id: widget.initialLocation?.id ?? const Uuid().v4(),
                name: name,
                category: _categoryController.text.trim().isNotEmpty
                    ? _categoryController.text.trim()
                    : 'Mall / Pusat Belanja',
                address: _addressController.text.trim().isNotEmpty
                    ? _addressController.text.trim()
                    : null,
                isDefaultTemplate: widget.initialLocation?.isDefaultTemplate ?? false,
                rates: Map.from(_ratesMap),
              );

              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final provider = Provider.of<ParkingProvider>(context, listen: false);
              await provider.saveParkingLocation(loc);

              if (mounted) {
                nav.pop(loc);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Lokasi & aturan tarif "$name" berhasil disimpan.'),
                    backgroundColor: const Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 18),
                SizedBox(width: 8),
                Text(
                  'Simpan Lokasi & Aturan Tarif',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimBadge(String label, int cost) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Text(
        '$label: ${_currencyFormat.format(cost)}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF166534),
        ),
      ),
    );
  }
}
