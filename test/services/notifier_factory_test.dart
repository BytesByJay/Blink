import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blink/services/alarm_kit_notifier.dart';
import 'package:blink/services/notification_service.dart';
import 'package:blink/services/notifier_factory.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iOS gets the AlarmKit notifier', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(createNotifier(), isA<AlarmKitNotifier>());
  });

  test('Android keeps the notification service', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(createNotifier(), isA<NotificationService>());
  });
}
