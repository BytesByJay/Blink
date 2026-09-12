import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_service.dart';
import '../widgets/circular_button.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _ticker;
  bool _permissionOk = true;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final svc = context.read<SessionService>();
      final ok = await svc.checkNotificationPermission();
      if (!ok) {
        final granted = await svc.requestNotificationPermission();
        if (mounted) setState(() => _permissionOk = granted);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatCountdown(DateTime? target) {
    if (target == null) return '';
    final left = target.difference(DateTime.now());
    if (left.isNegative) return '00:00';
    final m = left.inMinutes.toString().padLeft(2, '0');
    final s = (left.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SessionService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blink'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SettingsScreen(),
            )),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_permissionOk)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 24),
                color: Colors.orange.shade100,
                child: const Text(
                  'Notifications are disabled. Enable them in Settings for reminders to work.',
                ),
              ),
            CircularButton(
              label: svc.isActive ? 'Stop' : 'Start',
              color: svc.isActive ? Colors.redAccent : Colors.teal,
              onTap: () => svc.isActive ? svc.stop() : svc.start(),
            ),
            const SizedBox(height: 32),
            if (svc.isActive)
              Text(
                'Next reminder in ${_formatCountdown(svc.nextReminderAt)}',
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 12),
            Text(
              '${svc.settings.intervalMinutes} min interval · '
              '${svc.settings.lookAwaySeconds} sec look-away',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
