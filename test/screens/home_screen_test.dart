import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blink/screens/home_screen.dart';
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

Widget _wrap(SessionService svc) => ChangeNotifierProvider.value(
  value: svc,
  child: const MaterialApp(home: HomeScreen()),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows Start when idle', (t) async {
    final svc = SessionService(
      notifier: _FakeNotifier(),
      settingsService: SettingsService(),
    );
    await t.pumpWidget(_wrap(svc));
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Stop'), findsNothing);
  });

  testWidgets('tapping Start toggles to Stop', (t) async {
    final svc = SessionService(
      notifier: _FakeNotifier(),
      settingsService: SettingsService(),
    );
    await t.pumpWidget(_wrap(svc));
    await t.tap(find.text('Start'));
    await t.pumpAndSettle();
    expect(find.text('Stop'), findsOneWidget);
  });
}
