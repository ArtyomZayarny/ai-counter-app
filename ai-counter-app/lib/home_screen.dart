import 'dart:async';

import 'package:flutter/material.dart';

import 'api_service.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _serverOnline = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkServer();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _checkServer());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkServer() async {
    final online = await checkHealth();
    if (mounted) setState(() => _serverOnline = online);
  }

  Future<void> _openScan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    _checkServer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ytilities')),
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
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _UtilityCard(
                      icon: Icons.local_fire_department,
                      label: 'Gas',
                      color: Colors.orange,
                      enabled: _serverOnline,
                      onTap: _serverOnline ? _openScan : null,
                    ),
                    const SizedBox(height: 16),
                    _UtilityCard(
                      icon: Icons.water_drop,
                      label: 'Water',
                      color: Colors.blue,
                      enabled: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ComingSoonScreen(title: 'Water'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _UtilityCard(
                      icon: Icons.bolt,
                      label: 'Light',
                      color: Colors.amber,
                      enabled: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ComingSoonScreen(title: 'Light'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilityCard extends StatelessWidget {
  const _UtilityCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Coming soon',
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
