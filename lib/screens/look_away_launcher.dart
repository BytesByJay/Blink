import 'package:flutter/material.dart';

import 'look_away_screen.dart';

/// Opens the Look-Away screen for a reminder, unless it is already showing.
class LookAwayLauncher {
  LookAwayLauncher(this._navigatorKey, {this.onChime});

  final GlobalKey<NavigatorState> _navigatorKey;
  final VoidCallback? onChime;
  bool _open = false;

  /// [remainingSeconds] shortens the countdown to what is left of a break
  /// that is already under way; omit it to run a whole break.
  Future<void> show({int? remainingSeconds}) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null || _open) return;
    _open = true;
    try {
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => LookAwayScreen(
            onChime: onChime,
            remainingSeconds: remainingSeconds,
          ),
        ),
      );
    } finally {
      _open = false;
    }
  }
}
