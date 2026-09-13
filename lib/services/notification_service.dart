import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notifier.dart';

export 'notifier.dart';

class NotificationService implements Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _tapController = StreamController<void>.broadcast();
  static const _id = 1001;
  static const _channelId = 'blink_reminders';
  static const _channelName = 'Blink Reminders';

  @override
  Stream<void> get onTap => _tapController.stream;

  // The OS delivers scheduled notifications while the app may not be running,
  // so there is no reliable in-app fire event on mobile.
  @override
  Stream<void> get onFired => const Stream.empty();

  @override
  Future<void> init() async {
    tzdata.initializeTimeZones();
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
  }

  @override
  Future<void> scheduleAt(
    DateTime when, {
    required bool sound,
    required bool vibration,
  }) async {
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
      playSound: sound,
      enableVibration: vibration,
    );
    final ios = DarwinNotificationDetails(presentSound: sound);
    await _plugin.zonedSchedule(
      _id,
      'Time to rest your eyes',
      'Look 20 feet away for a moment',
      tzWhen,
      NotificationDetails(android: android, iOS: ios),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

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
