import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blink/screens/home_screen.dart';
import 'package:blink/services/session_service.dart';
import 'package:blink/services/settings_service.dart';

import '../support/fake_notifier.dart';

Widget _wrap(SessionService svc) => ChangeNotifierProvider.value(
  value: svc,
  child: const MaterialApp(home: HomeScreen()),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows Start when idle', (t) async {
    final svc = SessionService(
      notifier: FakeNotifier(),
      settingsService: SettingsService(),
    );
    await t.pumpWidget(_wrap(svc));
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Stop'), findsNothing);
  });

  testWidgets('tapping Start toggles to Stop', (t) async {
    final svc = SessionService(
      notifier: FakeNotifier(),
      settingsService: SettingsService(),
    );
    await t.pumpWidget(_wrap(svc));
    await t.tap(find.text('Start'));
    await t.pumpAndSettle();
    expect(find.text('Stop'), findsOneWidget);
  });
}
