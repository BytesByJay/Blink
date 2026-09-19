import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_service.dart';
import '../widgets/countdown_ring.dart';

class LookAwayScreen extends StatefulWidget {
  final VoidCallback? onChime;

  /// Time left in a break already under way, for when Blink is opened partway
  /// through one. Null starts a whole break.
  final int? remainingSeconds;

  const LookAwayScreen({super.key, this.onChime, this.remainingSeconds});

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
    _remaining = widget.remainingSeconds ?? _total;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        _done = true;
        widget.onChime?.call();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _dismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Both leaving early and sitting the break out end it for good, so coming
  /// back to Blink before the next interval does not put this screen up again.
  void _dismiss() {
    context.read<SessionService>().dismissCurrentBreak();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total == 0
        ? 1.0
        : ((_total - _remaining) / _total).clamp(0.0, 1.0);
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
                onPressed: _dismiss,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
