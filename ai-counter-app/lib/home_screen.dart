import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api_service.dart';
import 'models/meter.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'scan_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/calculator_screen.dart';
import 'widgets/bill_card.dart';
import 'widgets/custom_loader.dart';
import 'widgets/reading_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _serverOnline = true;
  Timer? _timer;
  int _selectedTab = 0; // 0=Gas, 1=Water, 2=Light
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  Meter? _gasMeter;
  DashboardProvider? _gasDashboardProvider;

  Meter? _waterMeter;
  DashboardProvider? _waterDashboardProvider;

  Meter? _electricityMeter;
  DashboardProvider? _electricityDashboardProvider;

  bool _creatingWaterMeter = false;
  bool _creatingElectricityMeter = false;

  final Set<String> _deletingIds = {};
  bool _loggingOut = false;
  bool _scannerOpening = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  Meter? get _currentMeter {
    switch (_selectedTab) {
      case 0: return _gasMeter;
      case 1: return _waterMeter;
      case 2: return _electricityMeter;
      default: return _gasMeter;
    }
  }

  DashboardProvider? get _currentDashboard {
    switch (_selectedTab) {
      case 0: return _gasDashboardProvider;
      case 1: return _waterDashboardProvider;
      case 2: return _electricityDashboardProvider;
      default: return _gasDashboardProvider;
    }
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _checkServer();
    _loadMeters();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _checkServer());
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (!hasConnection && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _timer?.cancel();
    _fadeController.dispose();
    _gasDashboardProvider?.dispose();
    _waterDashboardProvider?.dispose();
    _electricityDashboardProvider?.dispose();
    super.dispose();
  }

  Future<void> _checkServer() async {
    final online = await checkHealth();
    if (mounted) setState(() => _serverOnline = online);
  }

  Future<void> _loadMeters() async {
    try {
      final meters = await getMeters();
      if (!mounted) return;

      final gas = meters.where((m) => m.utilityType == 'gas').firstOrNull;
      final water = meters.where((m) => m.utilityType == 'water').firstOrNull;
      final electricity =
          meters.where((m) => m.utilityType == 'electricity').firstOrNull;

      setState(() {
        _gasMeter = gas;
        _waterMeter = water;
        _electricityMeter = electricity;
      });

      if (gas != null && _gasDashboardProvider == null) {
        _gasDashboardProvider = DashboardProvider(gas.id)..loadAll();
      }
      if (water != null && _waterDashboardProvider == null) {
        _waterDashboardProvider = DashboardProvider(water.id)..loadAll();
      }
      if (electricity != null && _electricityDashboardProvider == null) {
        _electricityDashboardProvider =
            DashboardProvider(electricity.id)..loadAll();
      }

      setState(() {});
      _fadeController.forward();
    } on UnauthorizedException {
      if (mounted) context.read<AuthProvider>().handle401();
    } catch (_) {}
  }

  Future<void> _ensureWaterMeter() async {
    if (_waterMeter != null || _creatingWaterMeter) return;
    if (_gasMeter == null) return;

    setState(() => _creatingWaterMeter = true);
    try {
      final meter = await createMeter(
        propertyId: _gasMeter!.propertyId,
        utilityType: 'water',
        name: 'Water Meter',
      );
      if (!mounted) return;
      _waterMeter = meter;
      _waterDashboardProvider =
          DashboardProvider(meter.id)..loadAll();
      setState(() {});
    } on UnauthorizedException {
      if (mounted) context.read<AuthProvider>().handle401();
    } catch (_) {} finally {
      if (mounted) setState(() => _creatingWaterMeter = false);
    }
  }

  Future<void> _ensureElectricityMeter() async {
    if (_electricityMeter != null || _creatingElectricityMeter) return;
    if (_gasMeter == null) return;

    setState(() => _creatingElectricityMeter = true);
    try {
      final meter = await createMeter(
        propertyId: _gasMeter!.propertyId,
        utilityType: 'electricity',
        name: 'Electricity Meter',
      );
      if (!mounted) return;
      _electricityMeter = meter;
      _electricityDashboardProvider =
          DashboardProvider(meter.id)..loadAll();
      setState(() {});
    } on UnauthorizedException {
      if (mounted) context.read<AuthProvider>().handle401();
    } catch (_) {} finally {
      if (mounted) setState(() => _creatingElectricityMeter = false);
    }
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
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      child: Text(initials, style: const TextStyle(fontSize: 13, color: Colors.white)),
    );
  }

  Future<void> _openScan() async {
    if (_scannerOpening) return;
    final meter = _currentMeter;
    if (meter == null || !_serverOnline) return;

    _scannerOpening = true;
    try {
      final labels = ['Gas Meter', 'Water Meter', 'Electricity Meter'];
      final label = labels[_selectedTab];
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              ScanScreen(meterId: meter.id, meterLabel: label),
          transitionsBuilder: (_, anim, __, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
      _currentDashboard?.loadAll();
    } finally {
      _scannerOpening = false;
    }
  }

  bool _manualInputOpening = false;

  Future<void> _openManualInput() async {
    if (_manualInputOpening) return;
    final meter = _currentMeter;
    if (meter == null || !_serverOnline) return;

    _manualInputOpening = true;
    try {
      final labels = ['Gas', 'Water', 'Electricity'];
      final label = labels[_selectedTab];
      final controller = TextEditingController();
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ManualInputSheet(
          label: label,
          controller: controller,
          meterId: meter.id,
        ),
      );
      if (saved == true) {
        _currentDashboard?.loadAll();
      }
    } finally {
      _manualInputOpening = false;
    }
  }

  Future<void> _openCalculator() async {
    final meter = _currentMeter;
    final dashboard = _currentDashboard;
    if (meter == null || dashboard == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalculatorScreen(
          meter: meter,
          readings: dashboard.readings,
        ),
      ),
    );
    dashboard.loadAll();
  }

  void _onNavTap(int index) {
    setState(() => _selectedTab = index);
    if (index == 1) {
      _ensureWaterMeter();
    } else if (index == 2) {
      _ensureElectricityMeter();
    }
  }

  void _confirmDelete(
      BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  Widget _buildDashboard() {
    final dashboard = _currentDashboard;

    if (dashboard == null) {
      if (_creatingWaterMeter || _creatingElectricityMeter) {
        return const Center(child: CustomLoader());
      }
      return const Center(child: CustomLoader());
    }

    return ChangeNotifierProvider.value(
      value: dashboard,
      child: Consumer<DashboardProvider>(
        builder: (context, dashboard, _) {
          if (dashboard.loading) {
            return const Center(child: CustomLoader());
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: RefreshIndicator(
              color: const Color(0xFF6366F1),
              onRefresh: dashboard.loadAll,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  if (dashboard.error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(dashboard.error!,
                          style: TextStyle(color: Colors.red.shade700)),
                    ),
                  // Bills section
                  if (dashboard.bills.isNotEmpty) ...[
                    _buildSectionHeader('Bills', Icons.receipt_long),
                    const SizedBox(height: 10),
                    ...dashboard.bills.asMap().entries.map((entry) =>
                        _AnimatedCardWrapper(
                          index: entry.key,
                          child: BillCard(
                            bill: entry.value,
                            onDelete: _deletingIds.contains(entry.value.id)
                                ? null
                                : () => _confirmDelete(
                                    context,
                                    'Delete this bill?',
                                    () async {
                                      final id = entry.value.id;
                                      if (_deletingIds.contains(id)) return;
                                      setState(() => _deletingIds.add(id));
                                      try {
                                        await dashboard.removeBill(id);
                                      } on UnauthorizedException {
                                        if (context.mounted) {
                                          context.read<AuthProvider>().handle401();
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => _deletingIds.remove(id));
                                        }
                                      }
                                    },
                                  ),
                          ),
                        )),
                    const SizedBox(height: 28),
                  ],
                  // Readings section
                  _buildSectionHeader('Readings', Icons.speed),
                  const SizedBox(height: 10),
                  if (dashboard.readings.isEmpty)
                    _buildEmptyState(),
                  ...dashboard.readings.asMap().entries.map((entry) =>
                      _AnimatedCardWrapper(
                        index: entry.key + (dashboard.bills.isNotEmpty ? dashboard.bills.length : 0),
                        child: ReadingCard(
                          reading: entry.value,
                          onDelete: _deletingIds.contains(entry.value.id)
                              ? null
                              : () => _confirmDelete(
                                  context,
                                  'Delete this reading?',
                                  () async {
                                    final id = entry.value.id;
                                    if (_deletingIds.contains(id)) return;
                                    setState(() => _deletingIds.add(id));
                                    try {
                                      await dashboard.removeReading(id);
                                    } on UnauthorizedException {
                                      if (context.mounted) {
                                        context.read<AuthProvider>().handle401();
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _deletingIds.remove(id));
                                      }
                                    }
                                  },
                                ),
                        ),
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final labels = ['Gas', 'Water', 'Light'];
    final label = labels[_selectedTab];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.camera_alt_outlined, size: 48,
              color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'No readings yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap $label below to scan your meter',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Ytilities',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                if (_loggingOut) return;
                _loggingOut = true;
                try {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                } finally {
                  _loggingOut = false;
                }
              }
            },
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              heroTag: 'calculator',
              onPressed: _openCalculator,
              backgroundColor: const Color(0xFF4F46E5),
              child: const Icon(Icons.calculate, color: Colors.white),
            ),
            FloatingActionButton(
              heroTag: 'manual',
              onPressed: _openManualInput,
              backgroundColor: const Color(0xFF4F46E5),
              child: const Icon(Icons.edit, color: Colors.white),
            ),
            FloatingActionButton(
              heroTag: 'camera',
              onPressed: _openScan,
              backgroundColor: const Color(0xFF4F46E5),
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4F46E5), // Indigo
              Color(0xFF6366F1), // Lighter indigo
              Color(0xFF818CF8), // Even lighter
              Color(0xFF3B82F6), // Blue
            ],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (!_serverOnline)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_off, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text('Server unavailable',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              Expanded(child: _buildDashboard()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF4F46E5),
            unselectedItemColor: Colors.grey.shade400,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            currentIndex: _selectedTab,
            onTap: _onNavTap,
            items: const [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Icon(Icons.local_fire_department, size: 28),
                ),
                label: 'Gas',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Icon(Icons.water_drop, size: 28),
                ),
                label: 'Water',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Icon(Icons.bolt, size: 28),
                ),
                label: 'Light',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedCardWrapper extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedCardWrapper({required this.index, required this.child});

  @override
  State<_AnimatedCardWrapper> createState() => _AnimatedCardWrapperState();
}

class _AnimatedCardWrapperState extends State<_AnimatedCardWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

class _ManualInputSheet extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String meterId;

  const _ManualInputSheet({
    required this.label,
    required this.controller,
    required this.meterId,
  });

  @override
  State<_ManualInputSheet> createState() => _ManualInputSheetState();
}

class _ManualInputSheetState extends State<_ManualInputSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Enter a value');
      return;
    }
    final value = int.tryParse(text);
    if (value == null || value < 0) {
      setState(() => _error = 'Enter a valid number');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await createReading(meterId: widget.meterId, value: value);
      if (mounted) Navigator.pop(context, true);
    } on UnauthorizedException {
      if (mounted) {
        context.read<AuthProvider>().handle401();
        Navigator.pop(context, false);
      }
    } on RecognitionException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Failed to save reading';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${widget.label} Reading',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter the current meter value',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: widget.controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 6),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '00000',
                hintStyle: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: Colors.grey.shade300,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                ),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Reading', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
