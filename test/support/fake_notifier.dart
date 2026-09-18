import 'dart:async';

import 'package:blink/services/notifier.dart';

class FakeNotifier implements Notifier {
  final started = <({Duration interval, bool sound, bool vibration})>[];
  final resumed = <({DateTime startedAt, Duration interval})>[];
  int cancelCount = 0;

  /// What [resumeRepeating] reports: whether the OS still had the schedule.
  bool scheduleStillPending = true;

  final _tap = StreamController<void>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<void> startRepeating(
    Duration interval, {
    required int lookAwaySeconds,
    required bool sound,
    required bool vibration,
  }) async {
    started.add((interval: interval, sound: sound, vibration: vibration));
  }

  @override
  Future<bool> resumeRepeating(
    DateTime startedAt,
    Duration interval, {
    required int lookAwaySeconds,
    required bool sound,
    required bool vibration,
  }) async {
    resumed.add((startedAt: startedAt, interval: interval));
    return scheduleStillPending;
  }

  @override
  Future<void> cancelAll() async {
    cancelCount++;
  }

  @override
  Stream<void> get onTap => _tap.stream;

  @override
  Future<bool> launchedFromReminder() async => false;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;
}
