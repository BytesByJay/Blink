import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notifier.dart';
import 'reminder_timer.dart';

export 'notifier.dart';

class NotificationService implements Notifier {
  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    ReminderTimer? timer,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _timer = timer ?? ReminderTimer();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Mirrors the OS schedule in-process. The OS only hands a reminder back on
  /// a tap, so without this nothing opens the Look-Away screen while Blink is
  /// already on screen and the countdown just rolls into the next interval.
  final ReminderTimer _timer;
  final _tapController = StreamController<void>.broadcast();
  static const _id = 1001;
  static const _title = 'Time to rest your eyes';
  static const _body = 'Look 20 feet away for a moment';

  /// Bundled as ios/Runner/blink_alarm.wav and
  /// android/app/src/main/res/raw/blink_alarm.wav.
  static const _alarmSound = 'blink_alarm';

  /// Channel from before reminders had their own sound. Android fixes a
  /// channel's sound when it is created, so it is replaced, not updated.
  static const _legacyChannelId = 'blink_reminders';

  @override
  Stream<void> get onTap => _tapController.stream;

  @override
  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (_) => _tapController.add(null),
    );
    _timer.onFired.listen((_) => _tapController.add(null));
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.deleteNotificationChannel(_legacyChannelId);
  }

  /// The OS owns the repeating schedule, so reminders keep coming while the
  /// app is suspended or closed, whether or not earlier ones were opened.
  @override
  Future<void> startRepeating(
    Duration interval, {
    required int lookAwaySeconds,
    required bool sound,
    required bool vibration,
  }) async {
    await _plugin.cancelAll();
    await _plugin.periodicallyShowWithDuration(
      _id,
      _title,
      _body,
      interval,
      _details(sound: sound, vibration: vibration),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    _timer.startNow(interval);
  }

  @override
  Future<bool> resumeRepeating(
    DateTime startedAt,
    Duration interval, {
    required int lookAwaySeconds,
    required bool sound,
    required bool vibration,
  }) async {
    final pending = await _plugin.pendingNotificationRequests();
    if (pending.any((r) => r.id == _id)) {
      // The OS kept counting from the original start, so match its times.
      _timer.start(startedAt, interval);
      return true;
    }
    await startRepeating(
      interval,
      lookAwaySeconds: lookAwaySeconds,
      sound: sound,
      vibration: vibration,
    );
    return false;
  }

  @override
  Future<void> cancelAll() async {
    _timer.cancel();
    await _plugin.cancelAll();
  }

  @override
  Future<bool> launchedFromReminder() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false;
  }

  NotificationDetails _details({required bool sound, required bool vibration}) {
    // Android fixes a channel's sound and vibration when the channel is
    // created, so each combination gets its own channel.
    final channelId =
        'blink_${sound ? 'alarm' : 'silent'}_${vibration ? 'vibrate' : 'still'}';
    final channelName =
        '${sound ? 'Reminders' : 'Silent reminders'}'
        '${vibration ? '' : ' (no vibration)'}';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        playSound: sound,
        sound: sound
            ? const RawResourceAndroidNotificationSound(_alarmSound)
            : null,
        enableVibration: vibration,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: sound,
        sound: sound ? '$_alarmSound.wav' : null,
        // Shows during Focus and Do Not Disturb; needs the time-sensitive
        // entitlement in ios/Runner/Runner.entitlements.
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  @override
  Future<bool> hasPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final granted = await ios.checkPermissions();
      return granted?.isEnabled ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? true;
    }
    return true;
  }
}
