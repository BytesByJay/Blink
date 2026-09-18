abstract class Notifier {
  Future<void> init();

  /// Delivers a reminder every [interval], the first one [interval] from now,
  /// until [cancelAll]. Replaces any existing schedule.
  Future<void> startRepeating(
    Duration interval, {
    required bool sound,
    required bool vibration,
  });

  /// Re-arms, after the app restarts, the schedule [startRepeating] began at
  /// [startedAt]. Returns false if the schedule was gone and had to start
  /// again from now.
  Future<bool> resumeRepeating(
    DateTime startedAt,
    Duration interval, {
    required bool sound,
    required bool vibration,
  });

  Future<void> cancelAll();

  /// Emits when the Look-Away screen should open: the user opened a reminder
  /// (e.g. tapped its notification), or one came due while the app was on
  /// screen, where the OS reports nothing by itself.
  Stream<void> get onTap;

  /// Whether the app was launched by opening a reminder.
  Future<bool> launchedFromReminder();

  Future<bool> hasPermission();
  Future<bool> requestPermission();
}
