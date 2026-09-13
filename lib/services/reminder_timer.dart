import 'dart:async';

/// Holds a single pending reminder and fires [onFired] when it is due.
///
/// Browsers pause timers while the computer sleeps, so a periodic wall-clock
/// check fires an overdue reminder shortly after waking instead of waiting
/// out the rest of the original delay.
class ReminderTimer {
  static const _wakeCheckInterval = Duration(seconds: 15);

  final DateTime Function() _clock;
  final _firedController = StreamController<void>.broadcast();
  Timer? _exact;
  Timer? _wakeCheck;

  ReminderTimer({DateTime Function() clock = DateTime.now}) : _clock = clock;

  Stream<void> get onFired => _firedController.stream;

  void scheduleAt(DateTime when) {
    cancel();
    final delay = when.difference(_clock());
    _exact = Timer(delay.isNegative ? Duration.zero : delay, _fire);
    _wakeCheck = Timer.periodic(_wakeCheckInterval, (_) {
      if (!_clock().isBefore(when)) _fire();
    });
  }

  void cancel() {
    _exact?.cancel();
    _wakeCheck?.cancel();
    _exact = null;
    _wakeCheck = null;
  }

  void _fire() {
    cancel();
    _firedController.add(null);
  }
}
