import 'dart:async';

/// The first reminder due strictly after [after], for a schedule that repeats
/// every [interval] from [startedAt].
DateTime nextReminderAfter(
  DateTime startedAt,
  Duration interval,
  DateTime after,
) {
  final elapsed = after.difference(startedAt);
  if (elapsed.isNegative) return startedAt.add(interval);
  final done = elapsed.inMicroseconds ~/ interval.inMicroseconds;
  return startedAt.add(interval * (done + 1));
}

/// The most recent reminder due at or before [at], or null when none has come
/// due yet, for a schedule that repeats every [interval] from [startedAt].
DateTime? lastReminderAtOrBefore(
  DateTime startedAt,
  Duration interval,
  DateTime at,
) {
  final elapsed = at.difference(startedAt);
  if (elapsed.isNegative) return null;
  final done = elapsed.inMicroseconds ~/ interval.inMicroseconds;
  return done == 0 ? null : startedAt.add(interval * done);
}

/// Fires [onFired] every interval after a start time until cancelled.
///
/// Browsers pause timers while the computer sleeps, so a periodic wall-clock
/// check fires an overdue reminder shortly after waking instead of waiting
/// out the rest of the original delay. Reminders missed while asleep collapse
/// into that one catch-up.
class ReminderTimer {
  static const _wakeCheckInterval = Duration(seconds: 15);

  final DateTime Function() _clock;
  final _firedController = StreamController<void>.broadcast();
  Timer? _exact;
  Timer? _wakeCheck;

  ReminderTimer({DateTime Function() clock = DateTime.now}) : _clock = clock;

  Stream<void> get onFired => _firedController.stream;

  void start(DateTime startedAt, Duration interval) {
    _armAfter(startedAt, interval, _clock());
  }

  /// Starts a schedule whose first reminder is [interval] from now.
  void startNow(Duration interval) => start(_clock(), interval);

  void cancel() {
    _exact?.cancel();
    _wakeCheck?.cancel();
    _exact = null;
    _wakeCheck = null;
  }

  void _armAfter(DateTime startedAt, Duration interval, DateTime after) {
    cancel();
    final due = nextReminderAfter(startedAt, interval, after);

    void fire() {
      final now = _clock();
      _armAfter(startedAt, interval, now.isAfter(due) ? now : due);
      _firedController.add(null);
    }

    final delay = due.difference(_clock());
    _exact = Timer(delay.isNegative ? Duration.zero : delay, fire);
    _wakeCheck = Timer.periodic(_wakeCheckInterval, (_) {
      if (!_clock().isBefore(due)) fire();
    });
  }
}
