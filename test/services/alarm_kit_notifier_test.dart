import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blink/services/alarm_kit_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> log;

  void mockChannel({Object? Function(MethodCall)? respond}) {
    log = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kAlarmChannel, (call) async {
          log.add(call);
          return respond?.call(call);
        });
  }

  List<Object?> alarmsFrom(List<MethodCall> log) {
    final schedule = log.firstWhere((c) => c.method == 'schedule');
    return (schedule.arguments as Map)['alarms'] as List<Object?>;
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kAlarmChannel, null);
  });

  test('startRepeating schedules a full batch on the interval cadence', () async {
    mockChannel();
    final start = DateTime(2026, 1, 1, 12);
    final svc = AlarmKitNotifier(clock: () => start);

    await svc.startRepeating(
      const Duration(minutes: 20),
      lookAwaySeconds: 20,
      sound: true,
      vibration: true,
    );

    final alarms = alarmsFrom(log);
    expect(alarms, hasLength(kAlarmBatchSize));
    expect(
      (alarms.first! as Map)['atEpochMs'],
      start.add(const Duration(minutes: 20)).millisecondsSinceEpoch,
    );
    expect(
      (alarms.last! as Map)['atEpochMs'],
      start
          .add(const Duration(minutes: 20) * kAlarmBatchSize)
          .millisecondsSinceEpoch,
    );
    expect((alarms.first! as Map)['lookAwaySeconds'], 20);
  });

  test('the scheduled break length follows the setting', () async {
    mockChannel();
    final svc = AlarmKitNotifier(clock: () => DateTime(2026, 1, 1, 12));

    await svc.startRepeating(
      const Duration(minutes: 20),
      lookAwaySeconds: 45,
      sound: true,
      vibration: true,
    );

    expect((alarmsFrom(log).first! as Map)['lookAwaySeconds'], 45);
  });

  test('startRepeating cancels the previous batch first', () async {
    mockChannel();
    final svc = AlarmKitNotifier(clock: () => DateTime(2026, 1, 1, 12));

    await svc.startRepeating(
      const Duration(minutes: 20),
      lookAwaySeconds: 20,
      sound: true,
      vibration: true,
    );

    expect(log.map((c) => c.method).toList(), ['cancelAll', 'schedule']);
  });

  test('resumeRepeating tops up an intact batch on the original cadence', () async {
    mockChannel(respond: (call) => call.method == 'pendingCount' ? 5 : null);
    // 12:50 is 50 minutes into a 20-minute cadence that began at 12:00, so
    // breaks 1 and 2 are done and the next one is break 3 at 13:00.
    final svc = AlarmKitNotifier(clock: () => DateTime(2026, 1, 1, 12, 50));

    final intact = await svc.resumeRepeating(
      DateTime(2026, 1, 1, 12),
      const Duration(minutes: 20),
      lookAwaySeconds: 20,
      sound: true,
      vibration: true,
    );

    expect(intact, true);
    expect(
      (alarmsFrom(log).first! as Map)['atEpochMs'],
      DateTime(2026, 1, 1, 13).millisecondsSinceEpoch,
    );
    expect(log.any((c) => c.method == 'cancelAll'), false);
  });

  test('resumeRepeating starts over when nothing is pending', () async {
    mockChannel(respond: (call) => call.method == 'pendingCount' ? 0 : null);
    final svc = AlarmKitNotifier(clock: () => DateTime(2026, 1, 1, 12, 50));

    final intact = await svc.resumeRepeating(
      DateTime(2026, 1, 1, 12),
      const Duration(minutes: 20),
      lookAwaySeconds: 20,
      sound: true,
      vibration: true,
    );

    expect(intact, false);
    expect(log.any((c) => c.method == 'cancelAll'), true);
    expect(
      (alarmsFrom(log).first! as Map)['atEpochMs'],
      DateTime(2026, 1, 1, 13, 10).millisecondsSinceEpoch,
    );
  });

  test('cancelAll clears the batch', () async {
    mockChannel();

    await AlarmKitNotifier().cancelAll();

    expect(log.single.method, 'cancelAll');
  });

  test('permission checks go to AlarmKit authorization', () async {
    mockChannel(respond: (call) => call.method == 'authorizationStatus');

    expect(await AlarmKitNotifier().hasPermission(), true);
    expect(log.single.method, 'authorizationStatus');
  });

  test('requestPermission asks AlarmKit and reports refusal', () async {
    mockChannel(respond: (call) => false);

    expect(await AlarmKitNotifier().requestPermission(), false);
    expect(log.single.method, 'requestAuthorization');
  });

  test('openedFromAlarm from native makes onTap emit', () async {
    mockChannel();
    final svc = AlarmKitNotifier();
    await svc.init();
    final taps = <void>[];
    svc.onTap.listen(taps.add);

    // channelBuffers.push is the non-deprecated way to simulate a call
    // arriving from the platform side.
    ServicesBinding.instance.channelBuffers.push(
      kAlarmChannel.name,
      kAlarmChannel.codec.encodeMethodCall(
        const MethodCall('openedFromAlarm'),
      ),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);

    expect(taps, hasLength(1));
  });
}
