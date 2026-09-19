import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blink/main.dart';
import 'package:blink/screens/look_away_launcher.dart';
import 'package:blink/screens/look_away_screen.dart';
import 'package:blink/services/session_service.dart';
import 'package:blink/services/settings_service.dart';

import 'support/fake_notifier.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'lookAwaySeconds': 20}));

  /// Drives the app through a background/foreground round trip the way the
  /// engine does when the user opens Blink from an alarm.
  Future<void> reopen(WidgetTester t) async {
    for (final state in ['AppLifecycleState.paused', 'AppLifecycleState.resumed']) {
      ServicesBinding.instance.channelBuffers.push(
        'flutter/lifecycle',
        const StringCodec().encodeMessage(state)!,
        (_) {},
      );
      await t.pump();
    }
  }

  Future<SessionService> pumpApp(
    WidgetTester t,
    DateTime Function() clock,
  ) async {
    final svc = SessionService(
      notifier: FakeNotifier(),
      settingsService: SettingsService(),
      clock: clock,
    );
    await svc.start();
    final navigatorKey = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: svc,
        child: BlinkApp(
          navigatorKey: navigatorKey,
          lookAway: LookAwayLauncher(navigatorKey),
        ),
      ),
    );
    return svc;
  }

  testWidgets('reopening Blink during a break shows what is left of it', (
    t,
  ) async {
    var now = DateTime(2026, 1, 1, 12);
    await pumpApp(t, () => now);
    expect(find.byType(LookAwayScreen, skipOffstage: false), findsNothing);

    // The break due at 12:20 is five seconds old.
    now = DateTime(2026, 1, 1, 12, 20, 5);
    await reopen(t);
    await t.pumpAndSettle();

    expect(find.byType(LookAwayScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('15'), findsOneWidget);

    await t.pump(const Duration(seconds: 20));
    await t.pumpAndSettle();
  });

  testWidgets('reopening between breaks leaves the Home screen alone', (
    t,
  ) async {
    var now = DateTime(2026, 1, 1, 12);
    await pumpApp(t, () => now);

    now = DateTime(2026, 1, 1, 12, 20, 25);
    await reopen(t);
    await t.pumpAndSettle();

    expect(find.byType(LookAwayScreen, skipOffstage: false), findsNothing);
  });

  testWidgets('a break already seen out does not reopen', (t) async {
    var now = DateTime(2026, 1, 1, 12);
    final svc = await pumpApp(t, () => now);

    now = DateTime(2026, 1, 1, 12, 20, 5);
    svc.dismissCurrentBreak();
    await reopen(t);
    await t.pumpAndSettle();

    expect(find.byType(LookAwayScreen, skipOffstage: false), findsNothing);
  });
}
