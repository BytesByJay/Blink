import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_service.dart';
import '../widgets/countdown_ring.dart';

class LookAwayScreen extends StatefulWidget {
  final VoidCallback? onChime;
  const LookAwayScreen({super.key, this.onChime});

  @override
  State<LookAwayScreen> createState() => _LookAwayScreenState();
}

class _LookAwayScreenState extends State<LookAwayScreen> {
  late int _total;
  late int _remaining;
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _total = context.read<SessionService>().settings.lookAwaySeconds;
    _remaining = _total;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        _done = true;
        widget.onChime?.call();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).maybePop();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total == 0 ? 1.0 : (_total - _remaining) / _total;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              const Spacer(),
              const Text(
                'Look 20 feet away',
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
              const SizedBox(height: 24),
              CountdownRing(
                progress: progress,
                label: _done ? '✓' : '$_remaining',
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Skip',
                    style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
