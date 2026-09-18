import 'dart:async';

import 'package:flutter/services.dart';

import 'notifier.dart';

export 'notifier.dart';

/// Breaks scheduled ahead of time. AlarmKit has no arbitrary-interval
/// recurrence, so Blink schedules a batch and tops it up when the app opens.
const kAlarmBatchSize = 24;

const kAlarmChannel = MethodChannel('blink/alarmkit');

/// [Notifier] backed by AlarmKit (iOS 26+).
///
/// The break runs in system UI: the alarm alerts at break time, and its
/// "Look away" button starts the countdown shown on the Lock Screen and
/// Dynamic Island. Blink runs no in-app timer on iOS.
class AlarmKitNotifier implements Notifier {
  AlarmKitNotifier({
    MethodChannel channel = kAlarmChannel,
    DateTime Function() clock = DateTime.now,
  }) : _channel = channel,
       _clock = clock;

  final MethodChannel _channel;
  final DateTime Function() _clock;
  final _tapController = StreamController<void>.broadcast();

  /// Remembered from the last schedule so a top-up reuses the break length.
  int _lookAwaySeconds = 20;

  @override
  Stream<void> get onTap => _tapController.stream;

  @override
  Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openedFromAlarm') _tapController.add(null);
      return null;
    });
  }

  @override
  Future<void> startRepeating(
    Duration interval, {
    required int lookAwaySeconds,
    required bool sound,
    required bool vibration,
  }) async {
    _lookAwaySeconds = lookAwaySeconds;
    await _channel.invokeMethod<void>('cancelAll');
    await _scheduleFrom(_clock(), interval, 0);
  }

  @override
  Future<bool> resumeRepeating(
    DateTime startedAt,
    Duration interval, {
    required int lookAwaySeconds,
    required bool sound,
    required bool vibration,
  }) async {
    _lookAwaySeconds = lookAwaySeconds;
    final pending = await _channel.invokeMethod<int>('pendingCount') ?? 0;
    if (pending == 0) {
      await startRepeating(
        interval,
        lookAwaySeconds: lookAwaySeconds,
        sound: sound,
        vibration: vibration,
      );
      return false;
    }
    // Keep the OS cadence: count how many breaks have already gone by.
    final elapsed = _clock().difference(startedAt);
    final done = elapsed.isNegative
        ? 0
        : elapsed.inMicroseconds ~/ interval.inMicroseconds;
    await _scheduleFrom(startedAt, interval, done);
    return true;
  }

  @override
  Future<void> cancelAll() => _channel.invokeMethod<void>('cancelAll');

  /// The break happens in system UI, so opening the app is never required.
  @override
  Future<bool> launchedFromReminder() async => false;

  @override
  Future<bool> hasPermission() async =>
      await _channel.invokeMethod<bool>('authorizationStatus') ?? false;

  @override
  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestAuthorization') ?? false;

  /// Schedules breaks `skip + 1 .. skip + kAlarmBatchSize` counted from
  /// [startedAt], leaving out any already in the past.
  Future<void> _scheduleFrom(
    DateTime startedAt,
    Duration interval,
    int skip,
  ) async {
    final now = _clock();
    final alarms = <Map<String, Object>>[];
    for (var k = skip + 1; alarms.length < kAlarmBatchSize; k++) {
      final at = startedAt.add(interval * k);
      if (!at.isAfter(now)) continue;
      alarms.add({
        'atEpochMs': at.millisecondsSinceEpoch,
        'lookAwaySeconds': _lookAwaySeconds,
      });
    }
    await _channel.invokeMethod<void>('schedule', {'alarms': alarms});
  }
}
