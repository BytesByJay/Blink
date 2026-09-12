import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

abstract class Notifier {
  Future<void> init();
  Future<void> scheduleAt(DateTime when,
      {required bool sound, required bool vibration});
  Future<void> cancelAll();
  Stream<void> get onTap;
}

class NotificationService implements Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _tapController = StreamController<void>.broadcast();
  static const _id = 1001;
  static const _channelId = 'blink_reminders';
  static const _channelName = 'Blink Reminders';

  @override
  Stream<void> get onTap => _tapController.stream;

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
  Future<void> scheduleAt(DateTime when,
      {required bool sound, required bool vibration}) async {
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
      playSound: sound,
      enableVibration: vibration,
    );
    final ios = DarwinNotificationDetails(
      presentSound: sound,
    );
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
}
