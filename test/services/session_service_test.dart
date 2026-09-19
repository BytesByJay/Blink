import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blink/models/settings.dart';
import 'package:blink/services/session_service.dart';
import 'package:blink/services/settings_service.dart';

import '../support/fake_notifier.dart';

SessionService _session(FakeNotifier n, DateTime Function() clock) =>
    SessionService(
      notifier: n,
      settingsService: SettingsService(),
      clock: clock,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('start begins reminders repeating every interval', () async {
    final n = FakeNotifier();
    final svc = _session(n, () => DateTime(2026, 1, 1, 12));

    await svc.start();

    expect(svc.isActive, true);
    expect(n.started.single.interval, const Duration(minutes: 20));
    expect(svc.nextReminderAt, DateTime(2026, 1, 1, 12, 20));
  });

  test('start passes the sound and vibration settings', () async {
    SharedPreferences.setMockInitialValues({
      'soundEnabled': false,
      'vibrationEnabled': true,
    });
    final n = FakeNotifier();

    await _session(n, DateTime.now).start();

    expect(n.started.single.sound, false);
    expect(n.started.single.vibration, true);
  });

  test('next reminder keeps advancing while reminders are ignored', () async {
    var now = DateTime(2026, 1, 1, 12);
    final svc = _session(FakeNotifier(), () => now);
    await svc.start();

    now = DateTime(2026, 1, 1, 12, 45);
    expect(svc.nextReminderAt, DateTime(2026, 1, 1, 13));
    now = DateTime(2026, 1, 1, 13);
    expect(svc.nextReminderAt, DateTime(2026, 1, 1, 13, 20));
  });

  test('stop cancels reminders and clears state', () async {
    final n = FakeNotifier();
    final svc = _session(n, DateTime.now);

    await svc.start();
    await svc.stop();

    expect(svc.isActive, false);
    expect(svc.nextReminderAt, isNull);
    expect(n.cancelCount, greaterThanOrEqualTo(1));
  });

  test('an active session resumes after the app restarts', () async {
    var now = DateTime(2026, 1, 1, 12);
    await _session(FakeNotifier(), () => now).start();

    now = DateTime(2026, 1, 1, 12, 30);
    final n = FakeNotifier();
    final restarted = _session(n, () => now);
    await restarted.loadSettings();

    expect(restarted.isActive, true);
    expect(n.resumed.single.startedAt, DateTime(2026, 1, 1, 12));
    expect(n.resumed.single.interval, const Duration(minutes: 20));
    expect(restarted.nextReminderAt, DateTime(2026, 1, 1, 12, 40));
  });

  test('a lost schedule restarts from now and is remembered', () async {
    var now = DateTime(2026, 1, 1, 12);
    await _session(FakeNotifier(), () => now).start();

    now = DateTime(2026, 1, 1, 12, 30);
    final lost = FakeNotifier()..scheduleStillPending = false;
    final restarted = _session(lost, () => now);
    await restarted.loadSettings();

    expect(restarted.nextReminderAt, DateTime(2026, 1, 1, 12, 50));

    final n = FakeNotifier();
    await _session(n, () => now).loadSettings();
    expect(n.resumed.single.startedAt, DateTime(2026, 1, 1, 12, 30));
  });

  test('a stopped session stays stopped after the app restarts', () async {
    final first = _session(FakeNotifier(), DateTime.now);
    await first.start();
    await first.stop();

    final n = FakeNotifier();
    final restarted = _session(n, DateTime.now);
    await restarted.loadSettings();

    expect(restarted.isActive, false);
    expect(n.resumed, isEmpty);
  });

  test('applySettings while active restarts with the new interval', () async {
    var now = DateTime(2026, 1, 1, 12);
    final n = FakeNotifier();
    final svc = _session(n, () => now);
    await svc.start();

    now = DateTime(2026, 1, 1, 12, 7);
    await svc.applySettings(
      const Settings.defaults().copyWith(intervalMinutes: 5),
    );

    expect(n.started.last.interval, const Duration(minutes: 5));
    expect(svc.nextReminderAt, DateTime(2026, 1, 1, 12, 12));

    final afterRestart = FakeNotifier();
    await _session(afterRestart, () => now).loadSettings();
    expect(afterRestart.resumed.single.startedAt, DateTime(2026, 1, 1, 12, 7));
  });

  test('applySettings while idle only persists', () async {
    final n = FakeNotifier();
    final svc = _session(n, DateTime.now);

    await svc.applySettings(
      const Settings.defaults().copyWith(intervalMinutes: 10),
    );

    expect(svc.isActive, false);
    expect(n.started, isEmpty);
    expect((await SettingsService().load()).intervalMinutes, 10);
  });

  group('breakRemaining', () {
    test('is null while no session is running', () async {
      final svc = _session(FakeNotifier(), () => DateTime(2026, 1, 1, 12));

      expect(svc.breakRemaining, isNull);
    });

    test('is null between breaks', () async {
      var now = DateTime(2026, 1, 1, 12);
      final svc = _session(FakeNotifier(), () => now);
      await svc.start();

      now = DateTime(2026, 1, 1, 12, 10);
      expect(svc.breakRemaining, isNull);
    });

    test('counts down the look-away seconds once a break comes due', () async {
      var now = DateTime(2026, 1, 1, 12);
      final svc = _session(FakeNotifier(), () => now);
      await svc.start();

      now = DateTime(2026, 1, 1, 12, 20);
      expect(svc.breakRemaining, const Duration(seconds: 20));
      now = DateTime(2026, 1, 1, 12, 20, 15);
      expect(svc.breakRemaining, const Duration(seconds: 5));
    });

    test('is null once the break has run out', () async {
      var now = DateTime(2026, 1, 1, 12);
      final svc = _session(FakeNotifier(), () => now);
      await svc.start();

      now = DateTime(2026, 1, 1, 12, 20, 20);
      expect(svc.breakRemaining, isNull);
    });

    test('a dismissed break does not come back', () async {
      var now = DateTime(2026, 1, 1, 12);
      final svc = _session(FakeNotifier(), () => now);
      await svc.start();

      now = DateTime(2026, 1, 1, 12, 20, 5);
      svc.dismissCurrentBreak();
      expect(svc.breakRemaining, isNull);

      // The next break is its own break, so it still counts down.
      now = DateTime(2026, 1, 1, 12, 40, 5);
      expect(svc.breakRemaining, const Duration(seconds: 15));
    });

    test('restarting the session clears a dismissal', () async {
      var now = DateTime(2026, 1, 1, 12);
      final svc = _session(FakeNotifier(), () => now);
      await svc.start();

      now = DateTime(2026, 1, 1, 12, 20, 5);
      svc.dismissCurrentBreak();
      now = DateTime(2026, 1, 1, 12, 30);
      await svc.start();

      now = DateTime(2026, 1, 1, 12, 50, 5);
      expect(svc.breakRemaining, const Duration(seconds: 15));
    });
  });
}
