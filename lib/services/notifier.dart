abstract class Notifier {
  Future<void> init();
  Future<void> scheduleAt(
    DateTime when, {
    required bool sound,
    required bool vibration,
  });
  Future<void> cancelAll();

  /// Emits when the user opens a reminder (e.g. taps its notification).
  Stream<void> get onTap;

  /// Emits when a reminder comes due, if the platform can observe that.
  Stream<void> get onFired;

  Future<bool> hasPermission();
  Future<bool> requestPermission();
}
