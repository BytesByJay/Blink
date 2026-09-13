import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blink/screens/settings_screen.dart';
import 'package:blink/services/notification_service.dart';
import 'package:blink/services/session_service.dart';
import 'package:blink/services/settings_service.dart';

class _FakeNotifier implements Notifier {
  @override
  Future<void> init() async {}
  @override
  Future<void> scheduleAt(
    DateTime when, {
    required bool sound,
    required bool vibration,
  }) async {}
  @override
  Future<void> cancelAll() async {}
  @override
  Stream<void> get onTap => const Stream.empty();
  @override
  Stream<void> get onFired => const Stream.empty();
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders Interval and Sound controls', (t) async {
    final svc = SessionService(
      notifier: _FakeNotifier(),
      settingsService: SettingsService(),
    );
    await svc.loadSettings();

    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: svc,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.text('Interval'), findsOneWidget);
    expect(find.text('Look-away duration'), findsOneWidget);
    expect(find.text('Sound'), findsOneWidget);
    expect(find.text('Vibration'), findsOneWidget);
  });

  testWidgets('toggling Sound switch persists value', (t) async {
    final svc = SessionService(
      notifier: _FakeNotifier(),
      settingsService: SettingsService(),
    );
    await svc.loadSettings();

    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: svc,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    final soundSwitch = find.byKey(const ValueKey('sound_switch'));
    final initial = t.widget<SwitchListTile>(soundSwitch).value;
    expect(initial, true);

    await t.tap(soundSwitch);
    await t.pumpAndSettle();

    expect(svc.settings.soundEnabled, false);
  });

  testWidgets('choosing a 1 min interval persists value', (t) async {
    final svc = SessionService(
      notifier: _FakeNotifier(),
      settingsService: SettingsService(),
    );
    await svc.loadSettings();

    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: svc,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    await t.tap(find.byType(DropdownButton<int>).first);
    await t.pumpAndSettle();
    await t.tap(find.text('1 min').last);
    await t.pumpAndSettle();

    expect(svc.settings.intervalMinutes, 1);
  });
}
