import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _intervals = [5, 10, 15, 20, 30, 45, 60];
  static const _lookAways = [10, 20, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SessionService>();
    final s = svc.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Interval'),
            subtitle: const Text('Minutes between reminders'),
            trailing: DropdownButton<int>(
              value: s.intervalMinutes,
              items: _intervals
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v min')))
                  .toList(),
              onChanged: (v) {
                if (v != null) svc.applySettings(s.copyWith(intervalMinutes: v));
              },
            ),
          ),
          ListTile(
            title: const Text('Look-away duration'),
            subtitle: const Text('Seconds to rest your eyes'),
            trailing: DropdownButton<int>(
              value: s.lookAwaySeconds,
              items: _lookAways
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v sec')))
                  .toList(),
              onChanged: (v) {
                if (v != null) svc.applySettings(s.copyWith(lookAwaySeconds: v));
              },
            ),
          ),
          SwitchListTile(
            key: const ValueKey('sound_switch'),
            title: const Text('Sound'),
            value: s.soundEnabled,
            onChanged: (v) => svc.applySettings(s.copyWith(soundEnabled: v)),
          ),
          SwitchListTile(
            key: const ValueKey('vibration_switch'),
            title: const Text('Vibration'),
            value: s.vibrationEnabled,
            onChanged: (v) => svc.applySettings(s.copyWith(vibrationEnabled: v)),
          ),
        ],
      ),
    );
  }
}
