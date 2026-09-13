import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blink/screens/look_away_launcher.dart';
import 'package:blink/screens/look_away_screen.dart';
import 'package:blink/services/session_service.dart';
import 'package:blink/services/settings_service.dart';

import '../support/fake_notifier.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'lookAwaySeconds': 2}));

  testWidgets('a reminder while Look-Away is open does not stack another', (
    t,
  ) async {
    final svc = SessionService(
      notifier: FakeNotifier(),
      settingsService: SettingsService(),
    );
    await svc.loadSettings();
    final navigatorKey = GlobalKey<NavigatorState>();
    final launcher = LookAwayLauncher(navigatorKey);

    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: svc,
        child: MaterialApp(navigatorKey: navigatorKey, home: const Scaffold()),
      ),
    );

    unawaited(launcher.show());
    await t.pumpAndSettle();
    unawaited(launcher.show());
    await t.pumpAndSettle();

    expect(find.byType(LookAwayScreen, skipOffstage: false), findsOneWidget);

    await t.tap(find.text('Skip'));
    await t.pumpAndSettle();
    unawaited(launcher.show());
    await t.pumpAndSettle();

    expect(find.byType(LookAwayScreen, skipOffstage: false), findsOneWidget);

    // Drain the countdown and delayed pop timers.
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
  });
}
