import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blink/services/notification_service.dart';

/// Records what [NotificationService] hands to the OS plugin.
class _FakePlugin implements FlutterLocalNotificationsPlugin {
  final shown =
      <
        ({
          int id,
          Duration interval,
          NotificationDetails details,
          AndroidScheduleMode mode,
        })
      >[];
  List<PendingNotificationRequest> pending = [];

  @override
  Future<void> periodicallyShowWithDuration(
    int id,
    String? title,
    String? body,
    Duration repeatDurationInterval,
    NotificationDetails notificationDetails, {
    AndroidScheduleMode androidScheduleMode = AndroidScheduleMode.exact,
    String? payload,
  }) async {
    shown.add((
      id: id,
      interval: repeatDurationInterval,
      details: notificationDetails,
      mode: androidScheduleMode,
    ));
    pending = [PendingNotificationRequest(id, title, body, payload)];
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async =>
      pending;

  @override
  Future<void> cancelAll() async {
    pending = [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<NotificationDetails> _detailsFor({
  required bool sound,
  required bool vibration,
}) async {
  final plugin = _FakePlugin();
  await NotificationService(plugin: plugin).startRepeating(
    const Duration(minutes: 20),
    sound: sound,
    vibration: vibration,
  );
  return plugin.shown.single.details;
}

void main() {
  test('startRepeating schedules one exact repeating reminder', () async {
    final plugin = _FakePlugin();

    await NotificationService(plugin: plugin).startRepeating(
      const Duration(minutes: 20),
      sound: true,
      vibration: true,
    );

    expect(plugin.shown.single.interval, const Duration(minutes: 20));
    expect(plugin.shown.single.mode, AndroidScheduleMode.exactAllowWhileIdle);
  });

  test('reminders play the alarm sound when sound is on', () async {
    final details = await _detailsFor(sound: true, vibration: true);

    expect(details.iOS!.sound, 'blink_alarm.wav');
    expect(details.iOS!.presentSound, true);
    expect(details.android!.playSound, true);
    final androidSound =
        details.android!.sound! as RawResourceAndroidNotificationSound;
    expect(androidSound.sound, 'blink_alarm');
  });

  test('reminders are silent when sound is off', () async {
    final details = await _detailsFor(sound: false, vibration: true);

    expect(details.iOS!.sound, isNull);
    expect(details.iOS!.presentSound, false);
    expect(details.android!.playSound, false);
    expect(details.android!.sound, isNull);
  });

  test('reminders break through Focus modes on iOS', () async {
    final details = await _detailsFor(sound: true, vibration: true);

    expect(details.iOS!.interruptionLevel, InterruptionLevel.timeSensitive);
  });

  test('Android vibration follows the setting', () async {
    final on = await _detailsFor(sound: true, vibration: true);
    final off = await _detailsFor(sound: true, vibration: false);

    expect(on.android!.enableVibration, true);
    expect(off.android!.enableVibration, false);
  });

  test('each sound and vibration combination has its own Android channel', () async {
    // Android fixes a channel's sound and vibration when it is created.
    final channels = {
      for (final sound in [true, false])
        for (final vibration in [true, false])
          (await _detailsFor(
            sound: sound,
            vibration: vibration,
          )).android!.channelId,
    };

    expect(channels, hasLength(4));
  });

  test('resumeRepeating keeps a schedule that is still pending', () async {
    final plugin = _FakePlugin();
    final svc = NotificationService(plugin: plugin);
    await svc.startRepeating(
      const Duration(minutes: 20),
      sound: true,
      vibration: true,
    );

    final intact = await svc.resumeRepeating(
      DateTime(2026, 1, 1, 12),
      const Duration(minutes: 20),
      sound: true,
      vibration: true,
    );

    expect(intact, true);
    expect(plugin.shown, hasLength(1));
  });

  test('resumeRepeating starts over when the schedule is gone', () async {
    final plugin = _FakePlugin();

    final intact = await NotificationService(plugin: plugin).resumeRepeating(
      DateTime(2026, 1, 1, 12),
      const Duration(minutes: 20),
      sound: true,
      vibration: true,
    );

    expect(intact, false);
    expect(plugin.shown.single.interval, const Duration(minutes: 20));
  });
}
