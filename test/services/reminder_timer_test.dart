import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blink/services/reminder_timer.dart';

void main() {
  test('fires at every interval after the start', () {
    fakeAsync((async) {
      final start = DateTime(2026, 1, 1, 12);
      final timer = ReminderTimer(clock: () => start.add(async.elapsed));
      var fired = 0;
      timer.onFired.listen((_) => fired++);

      timer.start(start, const Duration(minutes: 20));

      async.elapse(const Duration(minutes: 19, seconds: 59));
      expect(fired, 0);
      async.elapse(const Duration(seconds: 1));
      expect(fired, 1);
      async.elapse(const Duration(minutes: 20));
      expect(fired, 2);
    });
  });

  test('cancel stops further reminders', () {
    fakeAsync((async) {
      final start = DateTime(2026, 1, 1, 12);
      final timer = ReminderTimer(clock: () => start.add(async.elapsed));
      var fired = 0;
      timer.onFired.listen((_) => fired++);

      timer.start(start, const Duration(minutes: 20));
      async.elapse(const Duration(minutes: 20));
      timer.cancel();
      async.elapse(const Duration(hours: 1));

      expect(fired, 1);
    });
  });

  test('starting again replaces the running schedule', () {
    fakeAsync((async) {
      final start = DateTime(2026, 1, 1, 12);
      final timer = ReminderTimer(clock: () => start.add(async.elapsed));
      final firedAt = <Duration>[];
      timer.onFired.listen((_) => firedAt.add(async.elapsed));

      timer.start(start, const Duration(minutes: 20));
      timer.start(start, const Duration(minutes: 5));
      async.elapse(const Duration(minutes: 21));

      expect(firedAt, const [
        Duration(minutes: 5),
        Duration(minutes: 10),
        Duration(minutes: 15),
        Duration(minutes: 20),
      ]);
    });
  });

  test('after waking, fires once and then keeps to the schedule', () {
    fakeAsync((async) {
      final start = DateTime(2026, 1, 1, 12);
      var slept = Duration.zero;
      final timer = ReminderTimer(
        clock: () => start.add(async.elapsed + slept),
      );
      var fired = 0;
      timer.onFired.listen((_) => fired++);

      timer.start(start, const Duration(minutes: 20));
      async.elapse(const Duration(minutes: 1));
      slept = const Duration(hours: 1); // laptop slept past three reminders
      async.elapse(const Duration(seconds: 15));
      expect(fired, 1);

      // The clock now reads 13:01:15; the next reminder is 13:20.
      async.elapse(const Duration(minutes: 18, seconds: 44));
      expect(fired, 1);
      async.elapse(const Duration(seconds: 1));
      expect(fired, 2);
    });
  });

  test('a schedule that started earlier fires at its next reminder', () {
    fakeAsync((async) {
      final start = DateTime(2026, 1, 1, 12);
      final timer = ReminderTimer(clock: () => start.add(async.elapsed));
      var fired = 0;
      timer.onFired.listen((_) => fired++);

      // Started at 11:10, so reminders are due at 11:30, 11:50, 12:10, ...
      timer.start(DateTime(2026, 1, 1, 11, 10), const Duration(minutes: 20));

      async.elapse(const Duration(minutes: 9, seconds: 59));
      expect(fired, 0);
      async.elapse(const Duration(seconds: 1));
      expect(fired, 1);
    });
  });
}
