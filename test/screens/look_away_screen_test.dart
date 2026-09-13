import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blink/screens/look_away_screen.dart';
import 'package:blink/services/session_service.dart';
import 'package:blink/services/settings_service.dart';
import 'package:blink/widgets/countdown_ring.dart';

import '../support/fake_notifier.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'lookAwaySeconds': 2}));

  testWidgets('countdown decrements and fires chime at zero', (t) async {
    final svc = SessionService(
      notifier: FakeNotifier(),
      settingsService: SettingsService(),
    );
    await svc.loadSettings();

    var chimed = false;
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: svc,
        child: MaterialApp(home: LookAwayScreen(onChime: () => chimed = true)),
      ),
    );

    expect(find.text('2'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('1'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    expect(chimed, true);
    // Drain the delayed pop timer before the test ends to avoid pending timer errors.
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('content is horizontally centred on wide windows', (t) async {
    await t.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final svc = SessionService(
      notifier: FakeNotifier(),
      settingsService: SettingsService(),
    );
    await svc.loadSettings();

    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: svc,
        child: const MaterialApp(home: LookAwayScreen()),
      ),
    );

    expect(t.getCenter(find.byType(CountdownRing)).dx, 640);
    expect(t.getCenter(find.text('Skip')).dx, 640);
    // Drain the countdown and delayed pop timers.
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('Skip button dismisses the screen', (t) async {
    final svc = SessionService(
      notifier: FakeNotifier(),
      settingsService: SettingsService(),
    );
    await svc.loadSettings();

    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: svc,
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute(builder: (_) => const LookAwayScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Skip'), findsOneWidget);

    await t.tap(find.text('Skip'));
    await t.pumpAndSettle();
    expect(find.text('Skip'), findsNothing);
  });
}
