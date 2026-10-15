import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/parking_provider.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late List<double> _reminderHours;
  late bool _notificationsEnabled;
  late bool _vibrationEnabled;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<ParkingProvider>(context, listen: false).settings;
    _reminderHours = List<double>.from(settings.reminderHours);
    _notificationsEnabled = settings.notificationsEnabled;
    _vibrationEnabled = settings.vibrationEnabled;
  }

  Future<void> _saveSettings() async {
    final provider = Provider.of<ParkingProvider>(context, listen: false);
    await provider.updateSettings(
      reminderHours: _reminderHours,
      firstHours: _reminderHours.isNotEmpty ? _reminderHours.first : 11.0,
      secondHours: _reminderHours.length > 1 ? _reminderHours[1] : 24.0,
      notificationsEnabled: _notificationsEnabled,
      vibrationEnabled: _vibrationEnabled,
    );
  }

  void _showAddReminderDialog() {
    final customController = TextEditingController();
    final presets = [1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 10.0, 11.0, 12.0, 18.0, 24.0, 48.0];
    double? selectedPreset;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.add_alarm_rounded, color: Color(0xFF2563EB), size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Tambah Jam Pengingat',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pilihan Cepat (Jam)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets.map((hours) {
                    final label = hours == hours.roundToDouble()
                        ? '${hours.toInt()} Jam'
                        : '${hours.toStringAsFixed(1)} Jam';
                    final isAlreadyAdded = _reminderHours.contains(hours);
                    final isSelected = selectedPreset == hours;

                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor: isAlreadyAdded
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFFF8FAFC),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isAlreadyAdded ? const Color(0xFF94A3B8) : const Color(0xFF0F172A)),
                      ),
                      onSelected: isAlreadyAdded
                          ? null
                          : (selected) {
                              setModalState(() {
                                selectedPreset = selected ? hours : null;
                                customController.clear();
                              });
                            },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Atau Masukkan Jam Khusus',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: customController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Contoh: 5 atau 7.5',
                    suffixText: 'Jam',
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
                  onChanged: (val) {
                    if (val.trim().isNotEmpty) {
                      setModalState(() {
                        selectedPreset = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    double? hourToAdd;
                    if (selectedPreset != null) {
                      hourToAdd = selectedPreset;
                    } else if (customController.text.trim().isNotEmpty) {
                      hourToAdd = double.tryParse(customController.text.trim());
                    }

                    if (hourToAdd == null || hourToAdd <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Harap masukkan angka jam yang valid (> 0).'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    if (_reminderHours.contains(hourToAdd)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Jam pengingat tersebut sudah ada dalam daftar.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _reminderHours.add(hourToAdd!);
                      _reminderHours.sort();
                    });
                    _saveSettings();
                    Navigator.of(ctx).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Pengingat ${hourToAdd.toStringAsFixed(0)} jam berhasil ditambahkan.'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                  },
                  child: const Text('Simpan Pengingat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _removeReminder(double hour) {
    if (_reminderHours.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal harus ada 1 jam pengingat.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _reminderHours.remove(hour);
    });
    _saveSettings();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pengingat ${hour.toStringAsFixed(0)} jam dihapus.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Pengaturan Alarm & Notifikasi'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Master Notification Switch
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Notifikasi Pengingat',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Pemberitahuan otomatis saat durasi parkir tercapai',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  value: _notificationsEnabled,
                  onChanged: (val) {
                    setState(() {
                      _notificationsEnabled = val;
                    });
                    _saveSettings();
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                ),
                SwitchListTile(
                  title: const Text(
                    'Getaran Alarm',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Getar saat notifikasi pengingat tiba',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  value: _vibrationEnabled,
                  onChanged: _notificationsEnabled
                      ? (val) {
                          setState(() {
                            _vibrationEnabled = val;
                          });
                          _saveSettings();
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Dynamic Reminders Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Jam Pengingat Parkir',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Text(
                      '${_reminderHours.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: _showAddReminderDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Tambah Jam',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // List of Reminder Hour Cards
          ..._reminderHours.asMap().entries.map((entry) {
            final index = entry.key;
            final hour = entry.value;
            final isLongParking = hour >= 24;
            final hourText = hour == hour.roundToDouble()
                ? '${hour.toInt()} Jam'
                : '${hour.toStringAsFixed(1)} Jam';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isLongParking ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isLongParking ? Icons.hotel_rounded : Icons.alarm_rounded,
                        color: isLongParking ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengingat ke-${index + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            isLongParking ? 'Tarif Menginap ($hourText)' : 'Batas Durasi ($hourText)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLongParking ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isLongParking ? const Color(0xFFFECACA) : const Color(0xFFDBEAFE),
                        ),
                      ),
                      child: Text(
                        hourText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isLongParking ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFF94A3B8)),
                      tooltip: 'Hapus Pengingat',
                      onPressed: _reminderHours.length > 1
                          ? () => _removeReminder(hour)
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),

          // Test Notification button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
            ),
            onPressed: () async {
              await NotificationService().showInstantNotification(
                title: '🔔 Uji Coba Pengingat Parkir',
                body: 'Sistem notifikasi karcis parkir berfungsi normal.',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifikasi uji coba berhasil dikirim.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.notifications_active_outlined, size: 20, color: Color(0xFF0F172A)),
            label: const Text(
              'Kirim Notifikasi Uji Coba',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
