import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/parking_ticket.dart';
import '../providers/parking_provider.dart';
import '../services/notification_service.dart';
import '../widgets/ticket_card.dart';
import 'expense_dashboard_screen.dart';
import 'history_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'ticket_detail_screen.dart';
import 'location_templates_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<ParkingProvider>(context, listen: false);
        if (provider.settings.notificationsEnabled) {
          NotificationService().requestPermissions();
        }
        final pendingTicketId = NotificationService().consumePendingTicketId();
        if (pendingTicketId != null) {
          NotificationService.navigateToTicket(pendingTicketId);
        }
      }
    });
  }

  Future<void> _openScanScreen(BuildContext context) async {
    final ticket = await Navigator.of(context).push<ParkingTicket>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (ticket != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Karcis ${ticket.plateNumber?.isNotEmpty == true ? ticket.plateNumber : ticket.rawCode} berhasil disimpan',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Lihat QR',
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TicketDetailScreen(ticket: ticket),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: _selectedTabIndex == 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Karcis Parkir',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 24, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text(
                    'Riwayat Parkir',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on_outlined, size: 22),
            tooltip: 'Lokasi & Template Parkir',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LocationTemplatesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded, size: 22),
            tooltip: 'Rekap Pengeluaran',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExpenseDashboardScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'Pengaturan Alarm',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _selectedTabIndex == 1
          ? const HistoryScreen(isTab: true)
          : Consumer<ParkingProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final tickets = provider.tickets;

          if (tickets.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => provider.loadTickets(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 64,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Belum Ada Karcis Parkir Aktif',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _openScanScreen(context),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Pindai Karcis Sekarang',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ExpenseDashboardScreen()),
                        );
                      },
                      icon: const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF2563EB)),
                      label: const Text(
                        'Lihat Rekap Pengeluaran & Riwayat',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadTickets(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 90),
              itemCount: tickets.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final now = DateTime.now();
                  final totalExpense = provider.getMonthlyTotalExpense(now.year, now.month);
                  final totalDuration = provider.getMonthlyTotalDuration(now.year, now.month);
                  final totalHours = totalDuration.inHours;
                  final remMinutes = totalDuration.inMinutes % 60;
                  final durStr = totalHours > 0 ? '$totalHours j $remMinutes m' : '$remMinutes mnt';
                  final currencyStr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalExpense);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ExpenseDashboardScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: Color(0xFF16A34A)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Pengeluaran Parkir Bulan Ini',
                                        style: TextStyle(fontSize: 11.5, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        '$currencyStr • Durasi: $durStr',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF14532D)),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF16A34A)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Row(
                          children: [
                            const Text(
                              'Karcis Aktif',
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
                                '${tickets.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                final ticket = tickets[index - 1];
                return TicketCard(
                  ticket: ticket,
                  onTap: () {
                    // Navigate to dedicated ticket display screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TicketDetailScreen(ticket: ticket),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
       floatingActionButton: _selectedTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openScanScreen(context),
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: const Text(
                'Pindai Karcis Baru',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            )
          : null,
      bottomNavigationBar: Consumer<ParkingProvider>(
        builder: (context, provider, child) {
          final activeCount = provider.tickets.length;
          final historyCount = provider.historyTickets.length;

          return NavigationBar(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
            destinations: [
              NavigationDestination(
                icon: activeCount > 0
                    ? Badge(
                        label: Text('$activeCount'),
                        child: const Icon(Icons.confirmation_number_outlined),
                      )
                    : const Icon(Icons.confirmation_number_outlined),
                selectedIcon: activeCount > 0
                    ? Badge(
                        label: Text('$activeCount'),
                        child: const Icon(Icons.confirmation_number),
                      )
                    : const Icon(Icons.confirmation_number),
                label: 'Karcis Aktif',
              ),
              NavigationDestination(
                icon: historyCount > 0
                    ? Badge(
                        label: Text('$historyCount'),
                        backgroundColor: const Color(0xFF64748B),
                        child: const Icon(Icons.history_rounded),
                      )
                    : const Icon(Icons.history_rounded),
                selectedIcon: historyCount > 0
                    ? Badge(
                        label: Text('$historyCount'),
                        backgroundColor: const Color(0xFF64748B),
                        child: const Icon(Icons.history_rounded),
                      )
                    : const Icon(Icons.history_rounded),
                label: 'Riwayat',
              ),
            ],
          );
        },
      ),
    );
  }
}
