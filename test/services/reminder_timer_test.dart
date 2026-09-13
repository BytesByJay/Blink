import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blink/services/reminder_timer.dart';

void main() {
  test('fires once at the scheduled time', () {
    fakeAsync((async) {
      final start = DateTime(2026, 1, 1, 12);
      final timer = ReminderTimer(clock: () => start.add(async.elapsed));
      var fired = 0;
      timer.onFired.listen((_) => fired++);

      timer.scheduleAt(start.add(const Duration(minutes: 20)));

      async.elapse(const Duration(minutes: 19, seconds: 59));
      expect(fired, 0);
      async.elapse(const Duration(seconds: 1));
      expect(fired, 1);
      async.elapse(const Duration(hours: 1));
      expect(fired, 1);
    });
  });

  test('cancel prevents the reminder from firing', () {
    fakeAsync((async) {
      final start = DateTime(2026, 1, 1, 12);
      final timer = ReminderTimer(clock: () => start.add(async.elapsed));
      var fired = 0;
      timer.onFired.listen((_) => fired++);

      timer.scheduleAt(start.add(const Duration(minutes: 5)));
      timer.cancel();
      async.elapse(const Duration(minutes: 10));

      expect(fired, 0);
    });
  });

  test('scheduling again replaces the pending reminder', () {
    fakeAsync((async) {
      final start = DateTime(2026, 1, 1, 12);
      final timer = ReminderTimer(clock: () => start.add(async.elapsed));
      final firedAt = <Duration>[];
      timer.onFired.listen((_) => firedAt.add(async.elapsed));

      timer.scheduleAt(start.add(const Duration(minutes: 20)));
      timer.scheduleAt(start.add(const Duration(minutes: 5)));
      async.elapse(const Duration(minutes: 30));

      expect(firedAt, [const Duration(minutes: 5)]);
    });
  });

  test('fires soon after waking when the clock jumped past the target', () {
    fakeAsync((async) {
      final start = DateTime(2026, 1, 1, 12);
      var slept = Duration.zero;
      final timer = ReminderTimer(
        clock: () => start.add(async.elapsed + slept),
      );
      var fired = 0;
      timer.onFired.listen((_) => fired++);

      timer.scheduleAt(start.add(const Duration(minutes: 20)));
      async.elapse(const Duration(minutes: 1));
      slept = const Duration(hours: 1); // laptop slept; timers were paused
      async.elapse(const Duration(seconds: 15));

      expect(fired, 1);
      async.elapse(const Duration(minutes: 30));
      expect(fired, 1);
    });
  });

  test('a time in the past fires immediately', () {
    fakeAsync((async) {
      final start = DateTime(2026, 1, 1, 12);
      final timer = ReminderTimer(clock: () => start.add(async.elapsed));
      var fired = 0;
      timer.onFired.listen((_) => fired++);

      timer.scheduleAt(start.subtract(const Duration(minutes: 1)));
      async.flushTimers();

      expect(fired, 1);
    });
  });
}
