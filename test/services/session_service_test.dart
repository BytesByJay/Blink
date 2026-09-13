import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blink/models/settings.dart';
import 'package:blink/services/notification_service.dart';
import 'package:blink/services/session_service.dart';
import 'package:blink/services/settings_service.dart';

class FakeNotifier implements Notifier {
  final scheduled = <DateTime>[];
  int cancelCount = 0;
  final _tap = StreamController<void>.broadcast();

  @override
  Future<void> init() async {}
  @override
  Future<void> scheduleAt(
    DateTime when, {
    required bool sound,
    required bool vibration,
  }) async {
    scheduled.add(when);
  }

  @override
  Future<void> cancelAll() async {
    cancelCount++;
  }

  @override
  Stream<void> get onTap => _tap.stream;
  @override
  Stream<void> get onFired => const Stream.empty();
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('start schedules a notification at now + interval', () async {
    final n = FakeNotifier();
    final fixed = DateTime(2026, 1, 1, 12, 0, 0);
    final svc = SessionService(
      notifier: n,
      settingsService: SettingsService(),
      clock: () => fixed,
    );

    await svc.start();

    expect(svc.isActive, true);
    expect(n.scheduled.single, fixed.add(const Duration(minutes: 20)));
    expect(svc.nextReminderAt, fixed.add(const Duration(minutes: 20)));
  });

  test('stop cancels notifications and clears state', () async {
    final n = FakeNotifier();
    final svc = SessionService(notifier: n, settingsService: SettingsService());

    await svc.start();
    await svc.stop();

    expect(svc.isActive, false);
    expect(svc.nextReminderAt, isNull);
    expect(n.cancelCount, greaterThanOrEqualTo(1));
  });

  test('onReminderFired reschedules next reminder', () async {
    final n = FakeNotifier();
    var now = DateTime(2026, 1, 1, 12, 0, 0);
    final svc = SessionService(
      notifier: n,
      settingsService: SettingsService(),
      clock: () => now,
    );

    await svc.start();
    now = DateTime(2026, 1, 1, 12, 20, 0);
    await svc.onReminderFired();

    expect(n.scheduled.length, 2);
    expect(n.scheduled.last, now.add(const Duration(minutes: 20)));
  });

  test('onReminderFired ignores a second call for the same reminder', () async {
    final n = FakeNotifier();
    var now = DateTime(2026, 1, 1, 12, 0, 0);
    final svc = SessionService(
      notifier: n,
      settingsService: SettingsService(),
      clock: () => now,
    );

    await svc.start();
    now = DateTime(2026, 1, 1, 12, 20, 0);
    await svc.onReminderFired(); // timer fired
    now = DateTime(2026, 1, 1, 12, 20, 30);
    await svc.onReminderFired(); // user clicked the notification

    expect(n.scheduled.length, 2);
    expect(svc.nextReminderAt, DateTime(2026, 1, 1, 12, 40, 0));
  });

  test('onReminderFired accepts a timer firing slightly early', () async {
    final n = FakeNotifier();
    var now = DateTime(2026, 1, 1, 12, 0, 0);
    final svc = SessionService(
      notifier: n,
      settingsService: SettingsService(),
      clock: () => now,
    );

    await svc.start();
    now = DateTime(2026, 1, 1, 12, 19, 59);
    await svc.onReminderFired();

    expect(n.scheduled.length, 2);
  });

  test('applySettings while active re-schedules with new interval', () async {
    final n = FakeNotifier();
    final fixed = DateTime(2026, 1, 1, 12, 0, 0);
    final svc = SessionService(
      notifier: n,
      settingsService: SettingsService(),
      clock: () => fixed,
    );

    await svc.start();
    await svc.applySettings(
      const Settings.defaults().copyWith(intervalMinutes: 5),
    );

    expect(n.cancelCount, greaterThanOrEqualTo(1));
    expect(n.scheduled.last, fixed.add(const Duration(minutes: 5)));
  });

  test('applySettings while idle only persists', () async {
    final n = FakeNotifier();
    final svc = SessionService(notifier: n, settingsService: SettingsService());

    await svc.applySettings(
      const Settings.defaults().copyWith(intervalMinutes: 10),
    );

    expect(svc.isActive, false);
    expect(n.scheduled, isEmpty);
  });
}
