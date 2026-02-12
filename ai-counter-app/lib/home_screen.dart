import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api_service.dart';
import 'models/meter.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'scan_screen.dart';
import 'screens/calculator_screen.dart';
import 'widgets/bill_card.dart';
import 'widgets/reading_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _serverOnline = true;
  Timer? _timer;
  Meter? _gasMeter;
  int _tabIndex = 0;
  DashboardProvider? _dashboardProvider;

  @override
  void initState() {
    super.initState();
    _checkServer();
    _loadMeters();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _checkServer());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dashboardProvider?.dispose();
    super.dispose();
  }

  Future<void> _checkServer() async {
    final online = await checkHealth();
    if (mounted) setState(() => _serverOnline = online);
  }

  Future<void> _loadMeters() async {
    try {
      final meters = await getMeters();
      if (mounted) {
        setState(() {
          _gasMeter = meters.where((m) => m.utilityType == 'gas').firstOrNull;
        });
        if (_gasMeter != null && _dashboardProvider == null) {
          _dashboardProvider = DashboardProvider(_gasMeter!.id)..loadAll();
          setState(() {});
        }
      }
    } on UnauthorizedException {
      if (mounted) context.read<AuthProvider>().handle401();
    } catch (_) {}
  }

  Widget _buildAvatar(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final photoUrl = auth.photoUrl;
    final name = auth.user?.name ?? '';
    final initials = name.isNotEmpty
        ? name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    if (photoUrl != null) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(photoUrl),
      );
    }
    return CircleAvatar(
      radius: 16,
      child: Text(initials, style: const TextStyle(fontSize: 13)),
    );
  }

  Future<void> _openScan() async {
    if (_gasMeter == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanScreen(meterId: _gasMeter!.id),
      ),
    );
    _dashboardProvider?.loadAll();
  }

  Future<void> _openCalculator() async {
    if (_gasMeter == null || _dashboardProvider == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalculatorScreen(
          meter: _gasMeter!,
          readings: _dashboardProvider!.readings,
        ),
      ),
    );
    _dashboardProvider?.loadAll();
  }

  void _confirmDelete(
      BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildGasTab() {
    if (_dashboardProvider == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ChangeNotifierProvider.value(
      value: _dashboardProvider!,
      child: Consumer<DashboardProvider>(
        builder: (context, dashboard, _) {
          if (dashboard.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: dashboard.loadAll,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (dashboard.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(dashboard.error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                // Bills section
                if (dashboard.bills.isNotEmpty) ...[
                  const Text('Bills',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...dashboard.bills.map((bill) => BillCard(
                        bill: bill,
                        onDelete: () => _confirmDelete(
                          context,
                          'Delete this bill?',
                          () async {
                            try {
                              await dashboard.removeBill(bill.id);
                            } on UnauthorizedException {
                              if (context.mounted) {
                                context.read<AuthProvider>().handle401();
                              }
                            }
                          },
                        ),
                      )),
                  const SizedBox(height: 24),
                ],
                // Readings section
                const Text('Readings',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (dashboard.readings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No readings yet. Scan a meter to start!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  ),
                ...dashboard.readings.map((reading) => ReadingCard(
                      reading: reading,
                      onDelete: () => _confirmDelete(
                        context,
                        'Delete this reading?',
                        () async {
                          try {
                            await dashboard.removeReading(reading.id);
                          } on UnauthorizedException {
                            if (context.mounted) {
                              context.read<AuthProvider>().handle401();
                            }
                          }
                        },
                      ),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildComingSoon(String title, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: color.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            '$title — Coming soon',
            style: TextStyle(fontSize: 20, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ytilities'),
        actions: [
          if (_tabIndex == 0 && _gasMeter != null)
            IconButton(
              icon: const Icon(Icons.calculate),
              tooltip: 'Calculator',
              onPressed: _openCalculator,
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                context.read<AuthProvider>().logout();
              }
            },
            offset: const Offset(0, 48),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: const [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildAvatar(context),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_serverOnline)
            const MaterialBanner(
              content: Text('Server unavailable'),
              leading: Icon(Icons.cloud_off, color: Colors.red),
              backgroundColor: Color(0xFFFFEBEE),
              actions: [SizedBox.shrink()],
            ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildGasTab(),
                _buildComingSoon('Water', Icons.water_drop, Colors.blue),
                _buildComingSoon('Light', Icons.bolt, Colors.amber),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabIndex == 0 && _serverOnline && _gasMeter != null
          ? FloatingActionButton(
              onPressed: _openScan,
              child: const Icon(Icons.camera_alt),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_fire_department),
            label: 'Gas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.water_drop),
            label: 'Water',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bolt),
            label: 'Light',
          ),
        ],
      ),
    );
  }
}
