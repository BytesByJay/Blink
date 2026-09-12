import 'package:flutter_test/flutter_test.dart';
import 'package:blink/services/notification_service.dart';

void main() {
  test('Notifier abstraction defines the expected API', () {
    final Notifier n = _NoopNotifier();
    expect(n, isA<Notifier>());
  });
}

class _NoopNotifier implements Notifier {
  @override
  Future<void> init() async {}
  @override
  Future<void> scheduleAt(DateTime when,
      {required bool sound, required bool vibration}) async {}
  @override
  Future<void> cancelAll() async {}
  @override
  Stream<void> get onTap => const Stream.empty();
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
}
