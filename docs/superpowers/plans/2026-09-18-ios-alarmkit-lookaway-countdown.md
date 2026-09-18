# iOS AlarmKit Look-Away Countdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace iOS local notifications with AlarmKit so a look-away break alerts loudly at break time and then shows a live countdown on the Lock Screen and Dynamic Island, completable without opening Blink.

**Architecture:** A new `AlarmKitNotifier` implements the existing `Notifier` interface over a `MethodChannel`, and `notifier_factory_mobile.dart` selects it on iOS. Native Swift schedules one AlarmKit alarm per break with `countdownDuration(postAlert:)` and a `secondaryButtonBehavior: .countdown` button. A mandatory Widget Extension renders the countdown. Android and web are untouched.

**Tech Stack:** Flutter/Dart, Swift 5.9+, AlarmKit (iOS 26), ActivityKit, WidgetKit, `MethodChannel`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-18-ios-alarmkit-lookaway-countdown-design.md`. Read it first.
- iOS deployment target moves **15.0 → 26.0**. No pre-iOS-26 fallback.
- **Android and web behaviour must not change.** All existing tests pass untouched.
- `HomeScreen`, `SettingsScreen` and `Settings` are **not modified**. `Notifier`
  gains a `lookAwaySeconds` parameter and `SessionService` passes it through
  (Task 1) — AlarmKit cannot schedule a break without knowing its length.
- MethodChannel name is exactly `blink/alarmkit`.
- Batch size constant `kAlarmBatchSize = 24` (8 hours at a 20-minute interval). Clamp after verifying AlarmKit's real pending limit on device.
- Alarm copy, verbatim: title `Time to rest your eyes`, stop button `Skip`, secondary button `Look away`. End-of-break alert title: `Break over`.
- The alarm ships with the **system default sound**. Custom sounds are broken on iOS 26.0 (spec §12); do not wire `blink_alarm.wav` into AlarmKit.
- **AlarmKit is new and could not be compiled while writing this plan.** Every Swift signature below must be checked against Xcode autocomplete before assuming it is correct. Where a signature differs, keep the behaviour and adjust the call.
- Commit after each task.

---

### Task 1: AlarmKitNotifier — scheduling a batch

**Files:**
- Create: `lib/services/alarm_kit_notifier.dart`
- Modify: `lib/services/notifier.dart`, `lib/services/notification_service.dart`, `lib/services/web_notifier.dart`, `lib/services/session_service.dart`, `test/support/fake_notifier.dart`
- Test: `test/services/alarm_kit_notifier_test.dart`

**Interfaces:**
- Consumes: `Notifier` from `lib/services/notifier.dart`.
- Produces: `Notifier.startRepeating` and `Notifier.resumeRepeating` both gain a
  `required int lookAwaySeconds` named parameter. Also `class AlarmKitNotifier
  implements Notifier`, `const kAlarmBatchSize = 24`, `const kAlarmChannel =
  MethodChannel('blink/alarmkit')`. Channel method `schedule` takes
  `{'alarms': List<Map<String,Object>>}`, each entry
  `{'atEpochMs': int, 'lookAwaySeconds': int}`.

- [ ] **Step 0: Thread the break length through `Notifier`**

Add `required int lookAwaySeconds,` to the named parameters of `startRepeating`
and `resumeRepeating` in `lib/services/notifier.dart`, then to the `@override`
signatures in `notification_service.dart`, `web_notifier.dart` and
`test/support/fake_notifier.dart`. Those three ignore the value.

In `lib/services/session_service.dart`, pass it at both call sites:

```dart
      final intact = await _notifier.resumeRepeating(
        savedStart,
        _interval,
        lookAwaySeconds: _settings.lookAwaySeconds,
        sound: _settings.soundEnabled,
        vibration: _settings.vibrationEnabled,
      );
```

```dart
    await _notifier.startRepeating(
      _interval,
      lookAwaySeconds: _settings.lookAwaySeconds,
      sound: _settings.soundEnabled,
      vibration: _settings.vibrationEnabled,
    );
```

Run `flutter test` — existing tests must still pass before continuing.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/alarm_kit_notifier_test.dart
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

    final schedule = log.firstWhere((c) => c.method == 'schedule');
    final alarms = (schedule.arguments as Map)['alarms'] as List;
    expect(alarms, hasLength(kAlarmBatchSize));
    expect(
      alarms.first['atEpochMs'],
      start.add(const Duration(minutes: 20)).millisecondsSinceEpoch,
    );
    expect(
      alarms.last['atEpochMs'],
      start
          .add(const Duration(minutes: 20) * kAlarmBatchSize)
          .millisecondsSinceEpoch,
    );
    expect(alarms.first['lookAwaySeconds'], 20);
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/alarm_kit_notifier_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:blink/services/alarm_kit_notifier.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/services/alarm_kit_notifier.dart
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
  })  : _channel = channel,
        _clock = clock;

  final MethodChannel _channel;
  final DateTime Function() _clock;
  final _tapController = StreamController<void>.broadcast();

  /// Remembered from the last schedule so a top-up reuses the break length.
  int _lookAwaySeconds = 20;

  @override
  Stream<void> get onTap => _tapController.stream;

  @override
  Future<void> init() async {}

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

  @override
  Future<bool> resumeRepeating(
    DateTime startedAt,
    Duration interval, {
    required int lookAwaySeconds,
    required bool sound,
    required bool vibration,
  }) async =>
      throw UnimplementedError('Task 2');

  @override
  Future<void> cancelAll() => throw UnimplementedError('Task 2');

  @override
  Future<bool> launchedFromReminder() async => false;

  @override
  Future<bool> hasPermission() async => throw UnimplementedError('Task 3');

  @override
  Future<bool> requestPermission() async => throw UnimplementedError('Task 3');
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/alarm_kit_notifier_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/alarm_kit_notifier.dart test/services/alarm_kit_notifier_test.dart
git commit -m "feat(ios): schedule AlarmKit break batches from Dart"
```

---

### Task 2: Top-up on resume, and cancellation

**Files:**
- Modify: `lib/services/alarm_kit_notifier.dart`
- Test: `test/services/alarm_kit_notifier_test.dart`

**Interfaces:**
- Consumes: `AlarmKitNotifier`, `kAlarmBatchSize`, `kAlarmChannel` from Task 1.
- Produces: channel methods `pendingCount` (returns `int`) and `cancelAll` (returns `null`). `resumeRepeating` returns `true` when alarms were still pending, `false` when it restarted from now.

- [ ] **Step 1: Write the failing test**

```dart
// append inside main() in test/services/alarm_kit_notifier_test.dart
  test('resumeRepeating tops up an intact batch on the original cadence',
      () async {
    mockChannel(respond: (call) => call.method == 'pendingCount' ? 5 : null);
    // 12:50 is 50 minutes into a 20-minute cadence that began at 12:00,
    // so breaks 1 and 2 are done and the next one is break 3 at 13:00.
    final svc = AlarmKitNotifier(clock: () => DateTime(2026, 1, 1, 12, 50));

    final intact = await svc.resumeRepeating(
      DateTime(2026, 1, 1, 12),
      const Duration(minutes: 20),
      lookAwaySeconds: 20,
      sound: true,
      vibration: true,
    );

    expect(intact, true);
    final alarms =
        (log.firstWhere((c) => c.method == 'schedule').arguments
            as Map)['alarms'] as List;
    expect(
      alarms.first['atEpochMs'],
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
    final alarms =
        (log.firstWhere((c) => c.method == 'schedule').arguments
            as Map)['alarms'] as List;
    expect(
      alarms.first['atEpochMs'],
      DateTime(2026, 1, 1, 13, 10).millisecondsSinceEpoch,
    );
  });

  test('cancelAll clears the batch', () async {
    mockChannel();
    await AlarmKitNotifier().cancelAll();

    expect(log.single.method, 'cancelAll');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/alarm_kit_notifier_test.dart`
Expected: FAIL — `UnimplementedError: Task 2`.

- [ ] **Step 3: Write minimal implementation**

Replace the two `Task 2` stubs in `lib/services/alarm_kit_notifier.dart`:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/alarm_kit_notifier_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/alarm_kit_notifier.dart test/services/alarm_kit_notifier_test.dart
git commit -m "feat(ios): top up AlarmKit batch on resume"
```

---

### Task 3: Authorization and alarm callbacks

**Files:**
- Modify: `lib/services/alarm_kit_notifier.dart`
- Test: `test/services/alarm_kit_notifier_test.dart`

**Interfaces:**
- Consumes: `AlarmKitNotifier` from Tasks 1–2.
- Produces: channel methods `authorizationStatus` → `bool`, `requestAuthorization` → `bool`. Native→Dart call `openedFromAlarm` (no arguments) makes `onTap` emit.

- [ ] **Step 1: Write the failing test**

```dart
// append inside main() in test/services/alarm_kit_notifier_test.dart
  test('permission checks go to AlarmKit authorization', () async {
    mockChannel(respond: (call) => call.method == 'authorizationStatus');
    final svc = AlarmKitNotifier();

    expect(await svc.hasPermission(), true);
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

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      kAlarmChannel.name,
      kAlarmChannel.codec
          .encodeMethodCall(const MethodCall('openedFromAlarm')),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);

    expect(taps, hasLength(1));
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/alarm_kit_notifier_test.dart`
Expected: FAIL — `UnimplementedError: Task 3`.

- [ ] **Step 3: Write minimal implementation**

Replace `init()` and the two `Task 3` stubs:

```dart
  @override
  Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openedFromAlarm') _tapController.add(null);
      return null;
    });
  }

  @override
  Future<bool> hasPermission() async =>
      await _channel.invokeMethod<bool>('authorizationStatus') ?? false;

  @override
  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestAuthorization') ?? false;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/alarm_kit_notifier_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/alarm_kit_notifier.dart test/services/alarm_kit_notifier_test.dart
git commit -m "feat(ios): AlarmKit authorization and alarm callbacks"
```

---

### Task 4: Select AlarmKitNotifier on iOS

**Files:**
- Modify: `lib/services/notifier_factory_mobile.dart`
- Test: `test/services/notifier_factory_test.dart` (create)

**Interfaces:**
- Consumes: `AlarmKitNotifier` (Tasks 1–3), `NotificationService`.
- Produces: `createNotifier()` returns `AlarmKitNotifier` on iOS, `NotificationService` elsewhere.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/notifier_factory_test.dart
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:blink/services/alarm_kit_notifier.dart';
import 'package:blink/services/notification_service.dart';
import 'package:blink/services/notifier_factory.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iOS gets the AlarmKit notifier', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(createNotifier(), isA<AlarmKitNotifier>());
  });

  test('Android keeps the notification service', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(createNotifier(), isA<NotificationService>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/notifier_factory_test.dart`
Expected: FAIL — both return `NotificationService`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/services/notifier_factory_mobile.dart
import 'package:flutter/foundation.dart';

import 'alarm_kit_notifier.dart';
import 'notification_service.dart';

/// iOS drives breaks through AlarmKit so they run in system UI; Android keeps
/// local notifications.
Notifier createNotifier() => defaultTargetPlatform == TargetPlatform.iOS
    ? AlarmKitNotifier()
    : NotificationService();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test`
Expected: PASS — the new file plus every existing Android and web test.

- [ ] **Step 5: Commit**

```bash
git add lib/services/notifier_factory_mobile.dart test/services/notifier_factory_test.dart
git commit -m "feat(ios): route iOS to AlarmKitNotifier"
```

---

### Task 5: Xcode project setup (manual, macOS only)

**Files:**
- Modify (in Xcode, not by hand): `ios/Runner.xcodeproj/project.pbxproj`
- Modify: `ios/Runner/Info.plist`
- Modify: `ios/Runner/Runner.entitlements`

**Interfaces:**
- Produces: a widget extension target named `BlinkAlarmWidget` with bundle id `com.dhananjay.blink.BlinkAlarmWidget`, and an app group `group.com.dhananjay.blink` shared by both targets.

> **This task cannot be automated.** Editing `project.pbxproj` by hand to add an
> app-extension target reliably corrupts the project. Do these steps in Xcode.

- [ ] **Step 1: Raise the deployment target**

In Xcode, select the **Runner** project → each target → **Minimum Deployments** → set iOS **26.0**. Confirm all three `IPHONEOS_DEPLOYMENT_TARGET` entries in `project.pbxproj` now read `26.0`:

```bash
grep -n "IPHONEOS_DEPLOYMENT_TARGET" ios/Runner.xcodeproj/project.pbxproj | sort -u
```

- [ ] **Step 2: Add the widget extension target**

Xcode → **File → New → Target… → Widget Extension**. Name it `BlinkAlarmWidget`. Uncheck "Include Configuration App Intent". Check "Include Live Activity". When prompted to activate the scheme, choose **Cancel** (keep the Runner scheme active).

- [ ] **Step 3: Add the app group to both targets**

For **Runner** and **BlinkAlarmWidget**: Signing & Capabilities → **+ Capability → App Groups** → add `group.com.dhananjay.blink`. Both targets must have the identical group.

- [ ] **Step 4: Declare the AlarmKit usage string**

Add to `ios/Runner/Info.plist`, inside the top-level `<dict>`:

```xml
	<key>NSAlarmKitUsageDescription</key>
	<string>Blink uses alarms to tell you when to rest your eyes and to time each break.</string>
```

- [ ] **Step 5: Drop the now-unused notification entitlement**

iOS no longer sends local notifications, so `ios/Runner/Runner.entitlements` becomes:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
```

- [ ] **Step 6: Verify the project still builds**

Run: `flutter build ios --debug --no-codesign`
Expected: BUILD SUCCEEDED. If the widget target fails to find AlarmKit, confirm its own deployment target is also 26.0.

- [ ] **Step 7: Commit**

```bash
git add ios/
git commit -m "build(ios): add BlinkAlarmWidget target, require iOS 26"
```

---

### Task 6: Shared alarm metadata

**Files:**
- Create: `ios/Runner/BlinkAlarmMetadata.swift`

**Interfaces:**
- Produces: `struct BlinkAlarmMetadata: AlarmMetadata` and `typealias BlinkAlarmAttributes = AlarmAttributes<BlinkAlarmMetadata>`, used by both the plugin (Task 7) and the widget (Task 8).

- [ ] **Step 1: Write the shared type**

```swift
// ios/Runner/BlinkAlarmMetadata.swift
import AlarmKit
import Foundation

/// Shared between the app and the widget extension, so both describe the same
/// alarm shape. AlarmKit requires a metadata type even when it carries nothing.
nonisolated struct BlinkAlarmMetadata: AlarmMetadata {
  init() {}
}

typealias BlinkAlarmAttributes = AlarmAttributes<BlinkAlarmMetadata>
```

- [ ] **Step 2: Add the file to BOTH targets**

Select `BlinkAlarmMetadata.swift` in Xcode → File Inspector → **Target Membership** → tick **Runner** and **BlinkAlarmWidget**. Without both, the widget cannot decode the alarm and the system may dismiss it.

- [ ] **Step 3: Verify it compiles**

Run: `flutter build ios --debug --no-codesign`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add ios/Runner/BlinkAlarmMetadata.swift ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat(ios): shared AlarmKit metadata type"
```

---

### Task 7: Native AlarmKit plugin

**Files:**
- Create: `ios/Runner/AlarmKitPlugin.swift`
- Modify: `ios/Runner/AppDelegate.swift`

**Interfaces:**
- Consumes: `BlinkAlarmAttributes` (Task 6); the channel contract from Tasks 1–3 — `cancelAll`, `schedule({alarms:[{atEpochMs, lookAwaySeconds}]})`, `pendingCount`, `authorizationStatus`, `requestAuthorization`.
- Produces: `final class AlarmKitPlugin` with `init(messenger:)` and `register()`.

- [ ] **Step 1: Write the plugin**

```swift
// ios/Runner/AlarmKitPlugin.swift
import AlarmKit
import Flutter
import Foundation

/// Bridges `AlarmKitNotifier` to AlarmKit.
///
/// One alarm per break. It alerts at break time; its "Look away" button uses
/// `.countdown` behaviour so AlarmKit runs the look-away countdown itself as
/// the `postAlert` duration, rendered by BlinkAlarmWidget.
final class AlarmKitPlugin {
  private let channel: FlutterMethodChannel
  private var scheduled: [UUID] = []

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "blink/alarmkit", binaryMessenger: messenger)
  }

  func register() {
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      Task { await self.handle(call, result) }
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async {
    switch call.method {
    case "authorizationStatus":
      result(AlarmManager.shared.authorizationState == .authorized)

    case "requestAuthorization":
      do {
        let state = try await AlarmManager.shared.requestAuthorization()
        result(state == .authorized)
      } catch {
        result(false)
      }

    case "pendingCount":
      result(scheduled.count)

    case "cancelAll":
      cancelAll()
      result(nil)

    case "schedule":
      guard
        let args = call.arguments as? [String: Any],
        let alarms = args["alarms"] as? [[String: Any]]
      else {
        result(FlutterError(code: "bad_args", message: "alarms missing", details: nil))
        return
      }
      do {
        try await schedule(alarms)
        result(nil)
      } catch {
        result(FlutterError(code: "schedule_failed",
                            message: error.localizedDescription,
                            details: nil))
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func cancelAll() {
    for id in scheduled {
      try? AlarmManager.shared.cancel(id: id)
    }
    scheduled.removeAll()
  }

  private func schedule(_ alarms: [[String: Any]]) async throws {
    cancelAll()

    for alarm in alarms {
      guard
        let atMs = alarm["atEpochMs"] as? NSNumber,
        let lookAway = alarm["lookAwaySeconds"] as? NSNumber
      else { continue }

      let breakStart = Date(timeIntervalSince1970: atMs.doubleValue / 1000)

      let alert = AlarmPresentation.Alert(
        title: "Time to rest your eyes",
        stopButton: .init(text: "Skip",
                          textColor: .white,
                          systemImageName: "xmark"),
        secondaryButton: .init(text: "Look away",
                               textColor: .white,
                               systemImageName: "eye"),
        secondaryButtonBehavior: .countdown
      )

      let attributes = BlinkAlarmAttributes(
        presentation: AlarmPresentation(alert: alert),
        metadata: BlinkAlarmMetadata(),
        tintColor: .teal
      )

      let configuration = AlarmManager.AlarmConfiguration(
        schedule: .fixed(breakStart),
        attributes: attributes,
        countdownDuration: .init(preAlert: nil,
                                 postAlert: lookAway.doubleValue)
      )

      let id = UUID()
      _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
      scheduled.append(id)
    }
  }
}
```

> **On `openedFromAlarm`:** the plugin never sends it today, so `onTap` never
> fires on iOS. That is correct — `.countdown` handles the break in system UI
> without launching Blink. The Dart handler from Task 3 stays as the seam for a
> future custom App Intent that does open the app.

> **Signature check:** `AlarmManager.AlarmConfiguration`, `.schedule(id:configuration:)`,
> `authorizationState` and `AlarmButton`'s label all need confirming against Xcode
> autocomplete — AlarmKit shipped recently and these could not be compiled while
> planning. Keep the behaviour; adjust the calls.

- [ ] **Step 2: Register it on launch**

```swift
// ios/Runner/AppDelegate.swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var alarmKit: AlarmKitPlugin?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let plugin = AlarmKitPlugin(messenger: engineBridge.binaryMessenger)
    plugin.register()
    alarmKit = plugin
  }
}
```

> The `UNUserNotificationCenter` delegate line is deliberately gone: iOS no
> longer uses local notifications. If you still ship notifications on iOS for
> any reason, restore it — without it foreground notifications are silent.

- [ ] **Step 3: Verify it compiles**

Run: `flutter build ios --debug --no-codesign`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add ios/Runner/AlarmKitPlugin.swift ios/Runner/AppDelegate.swift
git commit -m "feat(ios): AlarmKit method channel plugin"
```

---

### Task 8: Countdown widget

**Files:**
- Modify: `ios/BlinkAlarmWidget/BlinkAlarmWidget.swift` (created by Xcode in Task 5)

**Interfaces:**
- Consumes: `BlinkAlarmAttributes` (Task 6).
- Produces: the Live Activity that renders the look-away countdown. Required — without it AlarmKit may dismiss countdown alarms.

- [ ] **Step 1: Replace the Xcode template with the countdown UI**

```swift
// ios/BlinkAlarmWidget/BlinkAlarmWidget.swift
import AlarmKit
import SwiftUI
import WidgetKit

struct BlinkAlarmWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: BlinkAlarmAttributes.self) { context in
      // Lock Screen and StandBy.
      HStack(spacing: 12) {
        Image(systemName: "eye")
          .font(.title2)
        VStack(alignment: .leading, spacing: 4) {
          Text("Look 20 feet away")
            .font(.headline)
          countdown(for: context.state)
            .font(.title3.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      .padding()
      .activityBackgroundTint(.black.opacity(0.85))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "eye").font(.title2)
        }
        DynamicIslandExpandedRegion(.trailing) {
          countdown(for: context.state).font(.title2.monospacedDigit())
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text("Look 20 feet away").font(.headline)
        }
      } compactLeading: {
        Image(systemName: "eye")
      } compactTrailing: {
        countdown(for: context.state).monospacedDigit()
      } minimal: {
        Image(systemName: "eye")
      }
      .keylineTint(.teal)
    }
  }

  /// AlarmKit hands the widget the countdown's end date; `Text(timerInterval:)`
  /// is rendered live by the system, so the widget needs no updates.
  @ViewBuilder
  private func countdown(for state: AlarmPresentationState) -> some View {
    if case let .countdown(countdown) = state.mode {
      Text(timerInterval: Date.now...countdown.fireDate, countsDown: true)
    } else {
      Text("--:--")
    }
  }
}
```

> **Signature check:** `AlarmPresentationState.mode` and its `.countdown`
> associated value (here `fireDate`) need confirming in Xcode. The rest of the
> layout is independent of that detail.

- [ ] **Step 2: Verify it compiles**

Run: `flutter build ios --debug --no-codesign`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add ios/BlinkAlarmWidget/
git commit -m "feat(ios): look-away countdown Live Activity"
```

---

### Task 9: Suppress the duplicate in-app chime on iOS

**Files:**
- Modify: `lib/main.dart`
- Test: `test/screens/look_away_screen_test.dart`

**Interfaces:**
- Consumes: `LookAwayLauncher` (unchanged).
- Produces: no chime callback on iOS, because AlarmKit's own end-of-break alert already sounds.

- [ ] **Step 1: Write the failing test**

Add to the imports at the top of the file:

```dart
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:blink/main.dart' show chimeCallback;
```

Then append inside `main()`:

```dart
  test('iOS has no in-app chime, since the alarm sounds instead', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(chimeCallback(), isNull);
  });

  test('Android keeps the in-app chime', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(chimeCallback(), isNotNull);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/look_away_screen_test.dart`
Expected: FAIL — `chimeCallback` is undefined.

- [ ] **Step 3: Write minimal implementation**

In `lib/main.dart`, add above `main()` and use it when building the launcher:

```dart
/// iOS ends a break with AlarmKit's own alert, so an in-app chime would double
/// up. Other platforms still chime.
VoidCallback? chimeCallback() => defaultTargetPlatform == TargetPlatform.iOS
    ? null
    : () => AudioPlayer().play(AssetSource('sounds/chime.mp3'));
```

```dart
  final lookAway = LookAwayLauncher(navigatorKey, onChime: chimeCallback());
```

Add `import 'package:flutter/foundation.dart';` if not already present.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test`
Expected: PASS, whole suite.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart test/screens/look_away_screen_test.dart
git commit -m "feat(ios): drop duplicate in-app chime"
```

---

### Task 10: Device verification

**Files:** none — this is manual QA on an iOS 26 device.

**Interfaces:** Consumes everything above. Resolves the open questions in spec §10.

- [ ] **Step 1: Authorization**

Fresh install → Start. Expected: the AlarmKit permission prompt appears once, quoting the `NSAlarmKitUsageDescription` string. Denying it shows Blink's existing permission banner on Home.

- [ ] **Step 2: Break alert**

Set interval to 1 minute. Lock the phone. Expected: at one minute the alarm alerts with sound and a persistent banner, **through** silent mode and a Focus mode, showing **Skip** and **Look away**.

- [ ] **Step 3: Countdown**

Tap **Look away**. Expected: a countdown appears on the Lock Screen and — on iPhone 14 Pro or later — in the Dynamic Island, ticking down the look-away seconds. Expected: it keeps ticking with Blink backgrounded and after force-quitting Blink.

- [ ] **Step 4: End of break**

Expected: at zero the alarm alerts again. **Record whether that second alert still offers "Look away"**, which would let a user start an unwanted second countdown (spec §10.5). If it does, set `secondaryButtonBehavior: .custom` on the repeat or drop the secondary button.

- [ ] **Step 5: Skip**

Trigger another break, tap **Skip**. Expected: no countdown, and the next break still arrives on schedule.

- [ ] **Step 6: Batch limits**

Set a 1-minute interval and Start. Expected: `kAlarmBatchSize` alarms schedule without error. **If AlarmKit rejects some, record the real limit** and clamp `kAlarmBatchSize` (spec §10.1).

- [ ] **Step 7: Top-up**

Leave a session running, force-quit Blink, reopen it after several breaks. Expected: the countdown cadence is unbroken and the batch refills.

- [ ] **Step 8: Record findings**

Update spec §10 with what each step resolved, then commit.

```bash
git add docs/superpowers/specs/2026-09-18-ios-alarmkit-lookaway-countdown-design.md
git commit -m "docs: record AlarmKit device findings"
```
