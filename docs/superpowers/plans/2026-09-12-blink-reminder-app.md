# Blink Reminder App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter mobile app that fires alarm-style local notifications on a user-configured interval (default 20-20-20) to remind the user to rest their eyes.

**Architecture:** Single Flutter app targeting iOS + Android. Provider for state, `shared_preferences` for settings persistence, `flutter_local_notifications` for scheduled alarms, `audioplayers` for reminder sound and end-chime. Two services (`SettingsService`, `NotificationService`) sit behind a `SessionService` that owns Start/Stop and re-schedules on setting changes.

**Tech Stack:** Flutter (Dart), Provider, shared_preferences, flutter_local_notifications, audioplayers, timezone.

**Spec:** [docs/superpowers/specs/2026-09-12-blink-reminder-app-design.md](../specs/2026-09-12-blink-reminder-app-design.md)

## Global Constraints

- **Framework:** Flutter (Dart SDK ^3.4.0).
- **Target platforms:** iOS 12+, Android 8.0 (API 26)+.
- **Default settings:** intervalMinutes=20, lookAwaySeconds=20, soundEnabled=true, vibrationEnabled=true.
- **Notification model:** one-shot per reminder; next is scheduled when previous fires (or immediately on Start).
- **Test framework:** `flutter_test` for unit + widget tests; run via `flutter test`.
- **No cloud/network dependencies** in v1.

---

## File Structure

```
blink/
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── models/
│   │   └── settings.dart
│   ├── services/
│   │   ├── settings_service.dart
│   │   ├── notification_service.dart
│   │   └── session_service.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── settings_screen.dart
│   │   └── look_away_screen.dart
│   └── widgets/
│       ├── circular_button.dart
│       └── countdown_ring.dart
├── assets/
│   └── sounds/
│       ├── alarm.mp3
│       └── chime.mp3
└── test/
    ├── models/
    │   └── settings_test.dart
    ├── services/
    │   ├── settings_service_test.dart
    │   ├── notification_service_test.dart
    │   └── session_service_test.dart
    └── screens/
        ├── home_screen_test.dart
        ├── settings_screen_test.dart
        └── look_away_screen_test.dart
```

---

## Task 1: Project scaffolding & dependencies

**Files:**
- Create: `pubspec.yaml`, `lib/main.dart`, `.gitignore`, `README.md`

**Interfaces:**
- Consumes: nothing (fresh project).
- Produces: a runnable, empty Flutter app that `flutter test` can execute against.

- [ ] **Step 1: Initialize Flutter project**

Run from the parent of the target directory:
```bash
cd /home/dhananjay/projects
flutter create --org com.dhananjay --project-name blink --platforms=android,ios blink
cd blink
```

- [ ] **Step 2: Add dependencies to `pubspec.yaml`**

Edit `pubspec.yaml` — under `dependencies:` add (keep `flutter: sdk: flutter` and `cupertino_icons` as generated):

```yaml
  provider: ^6.1.2
  shared_preferences: ^2.3.2
  flutter_local_notifications: ^17.2.3
  audioplayers: ^6.1.0
  timezone: ^0.9.4
  permission_handler: ^11.3.1
```

Under `flutter:` add the asset directory:
```yaml
  assets:
    - assets/sounds/
```

- [ ] **Step 3: Install packages**

Run: `flutter pub get`
Expected: exits 0, `pubspec.lock` written.

- [ ] **Step 4: Create asset directory with placeholder sounds**

```bash
mkdir -p assets/sounds
# Placeholders until Task 10 replaces them:
touch assets/sounds/alarm.mp3 assets/sounds/chime.mp3
```

- [ ] **Step 5: Verify baseline test runs**

Run: `flutter test`
Expected: PASS (the default counter test that `flutter create` produced).

- [ ] **Step 6: Initialize git and commit**

```bash
git init
git add .
git commit -m "chore: scaffold Flutter project with dependencies"
```

---

## Task 2: Settings model + SettingsService

**Files:**
- Create: `lib/models/settings.dart`
- Create: `lib/services/settings_service.dart`
- Create: `test/models/settings_test.dart`
- Create: `test/services/settings_service_test.dart`

**Interfaces:**
- Consumes: `shared_preferences` package.
- Produces:
  - `class Settings { int intervalMinutes; int lookAwaySeconds; bool soundEnabled; bool vibrationEnabled; Settings copyWith({...}); Map<String, dynamic> toMap(); Settings.fromMap(Map<String, dynamic>); const Settings.defaults(); }`
  - `class SettingsService { Future<Settings> load(); Future<void> save(Settings s); }`

- [ ] **Step 1: Write the failing model test**

Create `test/models/settings_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:blink/models/settings.dart';

void main() {
  test('defaults match 20-20-20 spec', () {
    const s = Settings.defaults();
    expect(s.intervalMinutes, 20);
    expect(s.lookAwaySeconds, 20);
    expect(s.soundEnabled, true);
    expect(s.vibrationEnabled, true);
  });

  test('copyWith replaces only supplied fields', () {
    const s = Settings.defaults();
    final s2 = s.copyWith(intervalMinutes: 30, soundEnabled: false);
    expect(s2.intervalMinutes, 30);
    expect(s2.lookAwaySeconds, 20);
    expect(s2.soundEnabled, false);
    expect(s2.vibrationEnabled, true);
  });

  test('toMap / fromMap round-trip preserves all fields', () {
    const s = Settings(
      intervalMinutes: 15,
      lookAwaySeconds: 30,
      soundEnabled: false,
      vibrationEnabled: true,
    );
    final restored = Settings.fromMap(s.toMap());
    expect(restored, s);
  });
}
```

- [ ] **Step 2: Run — expect fail**

Run: `flutter test test/models/settings_test.dart`
Expected: FAIL — `Settings` not defined.

- [ ] **Step 3: Implement `Settings`**

Create `lib/models/settings.dart`:
```dart
class Settings {
  final int intervalMinutes;
  final int lookAwaySeconds;
  final bool soundEnabled;
  final bool vibrationEnabled;

  const Settings({
    required this.intervalMinutes,
    required this.lookAwaySeconds,
    required this.soundEnabled,
    required this.vibrationEnabled,
  });

  const Settings.defaults()
      : intervalMinutes = 20,
        lookAwaySeconds = 20,
        soundEnabled = true,
        vibrationEnabled = true;

  Settings copyWith({
    int? intervalMinutes,
    int? lookAwaySeconds,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) => Settings(
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
        lookAwaySeconds: lookAwaySeconds ?? this.lookAwaySeconds,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      );

  Map<String, dynamic> toMap() => {
        'intervalMinutes': intervalMinutes,
        'lookAwaySeconds': lookAwaySeconds,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
      };

  factory Settings.fromMap(Map<String, dynamic> m) => Settings(
        intervalMinutes: m['intervalMinutes'] as int,
        lookAwaySeconds: m['lookAwaySeconds'] as int,
        soundEnabled: m['soundEnabled'] as bool,
        vibrationEnabled: m['vibrationEnabled'] as bool,
      );

  @override
  bool operator ==(Object other) =>
      other is Settings &&
      other.intervalMinutes == intervalMinutes &&
      other.lookAwaySeconds == lookAwaySeconds &&
      other.soundEnabled == soundEnabled &&
      other.vibrationEnabled == vibrationEnabled;

  @override
  int get hashCode => Object.hash(
      intervalMinutes, lookAwaySeconds, soundEnabled, vibrationEnabled);
}
```

- [ ] **Step 4: Run — expect pass**

Run: `flutter test test/models/settings_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing service test**

Create `test/services/settings_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blink/models/settings.dart';
import 'package:blink/services/settings_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load returns defaults when no values stored', () async {
    final svc = SettingsService();
    expect(await svc.load(), const Settings.defaults());
  });

  test('save then load round-trips modified settings', () async {
    final svc = SettingsService();
    const custom = Settings(
      intervalMinutes: 45,
      lookAwaySeconds: 30,
      soundEnabled: false,
      vibrationEnabled: false,
    );
    await svc.save(custom);
    expect(await svc.load(), custom);
  });
}
```

- [ ] **Step 6: Run — expect fail**

Run: `flutter test test/services/settings_service_test.dart`
Expected: FAIL — `SettingsService` not defined.

- [ ] **Step 7: Implement `SettingsService`**

Create `lib/services/settings_service.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';

class SettingsService {
  static const _kInterval = 'intervalMinutes';
  static const _kLookAway = 'lookAwaySeconds';
  static const _kSound = 'soundEnabled';
  static const _kVibration = 'vibrationEnabled';

  Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    const def = Settings.defaults();
    return Settings(
      intervalMinutes: p.getInt(_kInterval) ?? def.intervalMinutes,
      lookAwaySeconds: p.getInt(_kLookAway) ?? def.lookAwaySeconds,
      soundEnabled: p.getBool(_kSound) ?? def.soundEnabled,
      vibrationEnabled: p.getBool(_kVibration) ?? def.vibrationEnabled,
    );
  }

  Future<void> save(Settings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kInterval, s.intervalMinutes);
    await p.setInt(_kLookAway, s.lookAwaySeconds);
    await p.setBool(_kSound, s.soundEnabled);
    await p.setBool(_kVibration, s.vibrationEnabled);
  }
}
```

- [ ] **Step 8: Run — expect pass**

Run: `flutter test test/services/settings_service_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/models/settings.dart lib/services/settings_service.dart test/models/ test/services/settings_service_test.dart
git commit -m "feat: add Settings model and SettingsService with tests"
```

---

## Task 3: NotificationService

**Files:**
- Create: `lib/services/notification_service.dart`
- Create: `test/services/notification_service_test.dart`

**Interfaces:**
- Consumes: `flutter_local_notifications`, `timezone`.
- Produces:
  - `abstract class Notifier { Future<void> init(); Future<void> scheduleAt(DateTime when, {required bool sound, required bool vibration}); Future<void> cancelAll(); Stream<void> get onTap; }`
  - `class NotificationService implements Notifier { ... }` (real implementation)
  - `class FakeNotifier implements Notifier { List<DateTime> scheduled; int cancelCount; void triggerTap(); ... }` (test double, in same test file — kept out of production lib)

Task 4 depends on `Notifier` only, so it can accept the fake in tests.

- [ ] **Step 1: Write the failing test**

Create `test/services/notification_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:blink/services/notification_service.dart';

void main() {
  test('Notifier abstraction defines the expected API', () {
    // Compile-time contract check: the interface must exist and be
    // implementable. If any method is missing, this file won't compile.
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
}
```

- [ ] **Step 2: Run — expect fail**

Run: `flutter test test/services/notification_service_test.dart`
Expected: FAIL — `Notifier` not defined.

- [ ] **Step 3: Implement `Notifier` and `NotificationService`**

Create `lib/services/notification_service.dart`:
```dart
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

abstract class Notifier {
  Future<void> init();
  Future<void> scheduleAt(DateTime when,
      {required bool sound, required bool vibration});
  Future<void> cancelAll();
  Stream<void> get onTap;
}

class NotificationService implements Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _tapController = StreamController<void>.broadcast();
  static const _id = 1001;
  static const _channelId = 'blink_reminders';
  static const _channelName = 'Blink Reminders';

  @override
  Stream<void> get onTap => _tapController.stream;

  @override
  Future<void> init() async {
    tzdata.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (_) => _tapController.add(null),
    );
  }

  @override
  Future<void> scheduleAt(DateTime when,
      {required bool sound, required bool vibration}) async {
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
      playSound: sound,
      enableVibration: vibration,
    );
    final ios = DarwinNotificationDetails(
      presentSound: sound,
    );
    await _plugin.zonedSchedule(
      _id,
      'Time to rest your eyes',
      'Look 20 feet away for a moment',
      tzWhen,
      NotificationDetails(android: android, iOS: ios),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
```

- [ ] **Step 4: Run — expect pass**

Run: `flutter test test/services/notification_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/notification_service.dart test/services/notification_service_test.dart
git commit -m "feat: add NotificationService with Notifier abstraction"
```

---

## Task 4: SessionService (Start/Stop + scheduling)

**Files:**
- Create: `lib/services/session_service.dart`
- Create: `test/services/session_service_test.dart`

**Interfaces:**
- Consumes: `Notifier` from Task 3, `SettingsService` from Task 2, `Settings` from Task 2.
- Produces:
  - `class SessionService extends ChangeNotifier { bool get isActive; DateTime? get nextReminderAt; Future<void> start(); Future<void> stop(); Future<void> onReminderFired(); Future<void> applySettings(Settings s); SessionService({required Notifier notifier, required SettingsService settingsService, DateTime Function() clock = DateTime.now}); }`

- [ ] **Step 1: Write the failing test**

Create `test/services/session_service_test.dart`:
```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blink/models/settings.dart';
import 'package:blink/services/notification_service.dart';
import 'package:blink/services/session_service.dart';
import 'package:blink/services/settings_service.dart';

class FakeNotifier implements Notifier {
  final scheduled = <DateTime>[];
  int cancelCount = 0;
  final _tap = StreamController<void>.broadcast();

  @override
  Future<void> init() async {}
  @override
  Future<void> scheduleAt(DateTime when,
      {required bool sound, required bool vibration}) async {
    scheduled.add(when);
  }
  @override
  Future<void> cancelAll() async {
    cancelCount++;
  }
  @override
  Stream<void> get onTap => _tap.stream;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('start schedules a notification at now + interval', () async {
    final n = FakeNotifier();
    final fixed = DateTime(2026, 1, 1, 12, 0, 0);
    final svc = SessionService(
      notifier: n,
      settingsService: SettingsService(),
      clock: () => fixed,
    );

    await svc.start();

    expect(svc.isActive, true);
    expect(n.scheduled.single, fixed.add(const Duration(minutes: 20)));
    expect(svc.nextReminderAt, fixed.add(const Duration(minutes: 20)));
  });

  test('stop cancels notifications and clears state', () async {
    final n = FakeNotifier();
    final svc = SessionService(
      notifier: n,
      settingsService: SettingsService(),
    );

    await svc.start();
    await svc.stop();

    expect(svc.isActive, false);
    expect(svc.nextReminderAt, isNull);
    expect(n.cancelCount, greaterThanOrEqualTo(1));
  });

  test('onReminderFired reschedules next reminder', () async {
    final n = FakeNotifier();
    var now = DateTime(2026, 1, 1, 12, 0, 0);
    final svc = SessionService(
      notifier: n,
      settingsService: SettingsService(),
      clock: () => now,
    );

    await svc.start();
    now = DateTime(2026, 1, 1, 12, 20, 0);
    await svc.onReminderFired();

    expect(n.scheduled.length, 2);
    expect(n.scheduled.last, now.add(const Duration(minutes: 20)));
  });

  test('applySettings while active re-schedules with new interval', () async {
    final n = FakeNotifier();
    final fixed = DateTime(2026, 1, 1, 12, 0, 0);
    final svc = SessionService(
      notifier: n,
      settingsService: SettingsService(),
      clock: () => fixed,
    );

    await svc.start();
    await svc.applySettings(const Settings.defaults().copyWith(intervalMinutes: 5));

    expect(n.cancelCount, greaterThanOrEqualTo(1));
    expect(n.scheduled.last, fixed.add(const Duration(minutes: 5)));
  });

  test('applySettings while idle only persists', () async {
    final n = FakeNotifier();
    final svc = SessionService(
      notifier: n,
      settingsService: SettingsService(),
    );

    await svc.applySettings(const Settings.defaults().copyWith(intervalMinutes: 10));

    expect(svc.isActive, false);
    expect(n.scheduled, isEmpty);
  });
}
```

- [ ] **Step 2: Run — expect fail**

Run: `flutter test test/services/session_service_test.dart`
Expected: FAIL — `SessionService` not defined.

- [ ] **Step 3: Implement `SessionService`**

Create `lib/services/session_service.dart`:
```dart
import 'package:flutter/foundation.dart';
import '../models/settings.dart';
import 'notification_service.dart';
import 'settings_service.dart';

class SessionService extends ChangeNotifier {
  final Notifier _notifier;
  final SettingsService _settingsService;
  final DateTime Function() _clock;

  bool _isActive = false;
  DateTime? _nextReminderAt;
  Settings _settings = const Settings.defaults();

  SessionService({
    required Notifier notifier,
    required SettingsService settingsService,
    DateTime Function() clock = DateTime.now,
  })  : _notifier = notifier,
        _settingsService = settingsService,
        _clock = clock;

  bool get isActive => _isActive;
  DateTime? get nextReminderAt => _nextReminderAt;
  Settings get settings => _settings;

  Future<void> loadSettings() async {
    _settings = await _settingsService.load();
    notifyListeners();
  }

  Future<void> start() async {
    _settings = await _settingsService.load();
    _isActive = true;
    await _scheduleNext();
    notifyListeners();
  }

  Future<void> stop() async {
    _isActive = false;
    _nextReminderAt = null;
    await _notifier.cancelAll();
    notifyListeners();
  }

  Future<void> onReminderFired() async {
    if (!_isActive) return;
    await _scheduleNext();
    notifyListeners();
  }

  Future<void> applySettings(Settings s) async {
    _settings = s;
    await _settingsService.save(s);
    if (_isActive) {
      await _notifier.cancelAll();
      await _scheduleNext();
    }
    notifyListeners();
  }

  Future<void> _scheduleNext() async {
    final when = _clock().add(Duration(minutes: _settings.intervalMinutes));
    _nextReminderAt = when;
    await _notifier.scheduleAt(
      when,
      sound: _settings.soundEnabled,
      vibration: _settings.vibrationEnabled,
    );
  }
}
```

- [ ] **Step 4: Run — expect pass**

Run: `flutter test test/services/session_service_test.dart`
Expected: PASS (all 5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/session_service.dart test/services/session_service_test.dart
git commit -m "feat: add SessionService with Start/Stop and rescheduling logic"
```

---

## Task 5: Home Screen widget

**Files:**
- Create: `lib/screens/home_screen.dart`
- Create: `lib/widgets/circular_button.dart`
- Create: `test/screens/home_screen_test.dart`

**Interfaces:**
- Consumes: `SessionService` from Task 4 (via `Provider`).
- Produces: `HomeScreen` — a `StatelessWidget` that renders Start/Stop and a countdown, and a `CircularButton({required String label, required VoidCallback onTap, required Color color})` widget.

- [ ] **Step 1: Write the failing widget test**

Create `test/screens/home_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blink/screens/home_screen.dart';
import 'package:blink/services/notification_service.dart';
import 'package:blink/services/session_service.dart';
import 'package:blink/services/settings_service.dart';

class _FakeNotifier implements Notifier {
  @override Future<void> init() async {}
  @override Future<void> scheduleAt(DateTime when,
      {required bool sound, required bool vibration}) async {}
  @override Future<void> cancelAll() async {}
  @override Stream<void> get onTap => const Stream.empty();
}

Widget _wrap(SessionService svc) => ChangeNotifierProvider.value(
      value: svc,
      child: const MaterialApp(home: HomeScreen()),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows Start when idle', (t) async {
    final svc = SessionService(
      notifier: _FakeNotifier(),
      settingsService: SettingsService(),
    );
    await t.pumpWidget(_wrap(svc));
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Stop'), findsNothing);
  });

  testWidgets('tapping Start toggles to Stop', (t) async {
    final svc = SessionService(
      notifier: _FakeNotifier(),
      settingsService: SettingsService(),
    );
    await t.pumpWidget(_wrap(svc));
    await t.tap(find.text('Start'));
    await t.pumpAndSettle();
    expect(find.text('Stop'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run — expect fail**

Run: `flutter test test/screens/home_screen_test.dart`
Expected: FAIL — `HomeScreen` not defined.

- [ ] **Step 3: Implement `CircularButton`**

Create `lib/widgets/circular_button.dart`:
```dart
import 'package:flutter/material.dart';

class CircularButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const CircularButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement `HomeScreen`**

Create `lib/screens/home_screen.dart`:
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_service.dart';
import '../widgets/circular_button.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatCountdown(DateTime? target) {
    if (target == null) return '';
    final left = target.difference(DateTime.now());
    if (left.isNegative) return '00:00';
    final m = left.inMinutes.toString().padLeft(2, '0');
    final s = (left.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SessionService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blink'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SettingsScreen(),
            )),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularButton(
              label: svc.isActive ? 'Stop' : 'Start',
              color: svc.isActive ? Colors.redAccent : Colors.teal,
              onTap: () => svc.isActive ? svc.stop() : svc.start(),
            ),
            const SizedBox(height: 32),
            if (svc.isActive)
              Text(
                'Next reminder in ${_formatCountdown(svc.nextReminderAt)}',
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 12),
            Text(
              '${svc.settings.intervalMinutes} min interval · '
              '${svc.settings.lookAwaySeconds} sec look-away',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
```

Note: `SettingsScreen` is stubbed by Task 6; create a temporary placeholder to allow compilation:

Create a minimal `lib/screens/settings_screen.dart` (Task 6 will fully implement):
```dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('Settings')));
}
```

- [ ] **Step 5: Run — expect pass**

Run: `flutter test test/screens/home_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home_screen.dart lib/screens/settings_screen.dart lib/widgets/circular_button.dart test/screens/home_screen_test.dart
git commit -m "feat: add HomeScreen with Start/Stop button and live countdown"
```

---

## Task 6: Settings Screen widget

**Files:**
- Modify: `lib/screens/settings_screen.dart` (replace stub from Task 5)
- Create: `test/screens/settings_screen_test.dart`

**Interfaces:**
- Consumes: `SessionService`, `Settings`.
- Produces: A screen with 2 dropdowns (interval, look-away) and 2 switches (sound, vibration) wired to `SessionService.applySettings(...)`.

- [ ] **Step 1: Write the failing widget test**

Create `test/screens/settings_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blink/screens/settings_screen.dart';
import 'package:blink/services/notification_service.dart';
import 'package:blink/services/session_service.dart';
import 'package:blink/services/settings_service.dart';

class _FakeNotifier implements Notifier {
  @override Future<void> init() async {}
  @override Future<void> scheduleAt(DateTime when,
      {required bool sound, required bool vibration}) async {}
  @override Future<void> cancelAll() async {}
  @override Stream<void> get onTap => const Stream.empty();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders Interval and Sound controls', (t) async {
    final svc = SessionService(
      notifier: _FakeNotifier(),
      settingsService: SettingsService(),
    );
    await svc.loadSettings();

    await t.pumpWidget(ChangeNotifierProvider.value(
      value: svc,
      child: const MaterialApp(home: SettingsScreen()),
    ));

    expect(find.text('Interval'), findsOneWidget);
    expect(find.text('Look-away duration'), findsOneWidget);
    expect(find.text('Sound'), findsOneWidget);
    expect(find.text('Vibration'), findsOneWidget);
  });

  testWidgets('toggling Sound switch persists value', (t) async {
    final svc = SessionService(
      notifier: _FakeNotifier(),
      settingsService: SettingsService(),
    );
    await svc.loadSettings();

    await t.pumpWidget(ChangeNotifierProvider.value(
      value: svc,
      child: const MaterialApp(home: SettingsScreen()),
    ));

    final soundSwitch = find.byKey(const ValueKey('sound_switch'));
    expect(tester(soundSwitch).widget<Switch>().value, true);

    await t.tap(soundSwitch);
    await t.pumpAndSettle();

    expect(svc.settings.soundEnabled, false);
  });
}

// Helper: pytest-style access to widget by finder
Element tester(Finder f) => f.evaluate().single;

extension _Widget on Element {
  T widget<T>() => (this as dynamic).widget as T;
}
```

- [ ] **Step 2: Run — expect fail**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: FAIL — Settings controls not found.

- [ ] **Step 3: Implement `SettingsScreen`**

Replace `lib/screens/settings_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/settings.dart';
import '../services/session_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _intervals = [5, 10, 15, 20, 30, 45, 60];
  static const _lookAways = [10, 20, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SessionService>();
    final s = svc.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Interval'),
            subtitle: const Text('Minutes between reminders'),
            trailing: DropdownButton<int>(
              value: s.intervalMinutes,
              items: _intervals
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v min')))
                  .toList(),
              onChanged: (v) {
                if (v != null) svc.applySettings(s.copyWith(intervalMinutes: v));
              },
            ),
          ),
          ListTile(
            title: const Text('Look-away duration'),
            subtitle: const Text('Seconds to rest your eyes'),
            trailing: DropdownButton<int>(
              value: s.lookAwaySeconds,
              items: _lookAways
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v sec')))
                  .toList(),
              onChanged: (v) {
                if (v != null) svc.applySettings(s.copyWith(lookAwaySeconds: v));
              },
            ),
          ),
          SwitchListTile(
            key: const ValueKey('sound_switch'),
            title: const Text('Sound'),
            value: s.soundEnabled,
            onChanged: (v) => svc.applySettings(s.copyWith(soundEnabled: v)),
          ),
          SwitchListTile(
            key: const ValueKey('vibration_switch'),
            title: const Text('Vibration'),
            value: s.vibrationEnabled,
            onChanged: (v) => svc.applySettings(s.copyWith(vibrationEnabled: v)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run — expect pass**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings_screen.dart test/screens/settings_screen_test.dart
git commit -m "feat: implement Settings screen with interval, look-away, sound, vibration"
```

---

## Task 7: Look-Away Screen (countdown + chime)

**Files:**
- Create: `lib/screens/look_away_screen.dart`
- Create: `lib/widgets/countdown_ring.dart`
- Create: `test/screens/look_away_screen_test.dart`

**Interfaces:**
- Consumes: `SessionService` (for `lookAwaySeconds`), an injectable audio hook (for testability).
- Produces:
  - `class LookAwayScreen extends StatefulWidget { const LookAwayScreen({super.key, this.onChime}); final VoidCallback? onChime; }` — `onChime` is invoked when the countdown hits zero; production wires it to `audioplayers`, tests supply a spy.
  - `class CountdownRing extends StatelessWidget { const CountdownRing({required this.progress, required this.label}); final double progress; final String label; }`

- [ ] **Step 1: Write the failing widget test**

Create `test/screens/look_away_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blink/screens/look_away_screen.dart';
import 'package:blink/services/notification_service.dart';
import 'package:blink/services/session_service.dart';
import 'package:blink/services/settings_service.dart';

class _FakeNotifier implements Notifier {
  @override Future<void> init() async {}
  @override Future<void> scheduleAt(DateTime when,
      {required bool sound, required bool vibration}) async {}
  @override Future<void> cancelAll() async {}
  @override Stream<void> get onTap => const Stream.empty();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'lookAwaySeconds': 2,
      }));

  testWidgets('countdown decrements and fires chime at zero', (t) async {
    final svc = SessionService(
      notifier: _FakeNotifier(),
      settingsService: SettingsService(),
    );
    await svc.loadSettings();

    var chimed = false;
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: svc,
      child: MaterialApp(
        home: LookAwayScreen(onChime: () => chimed = true),
      ),
    ));

    expect(find.text('2'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('1'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    expect(chimed, true);
  });

  testWidgets('Skip button dismisses the screen', (t) async {
    final svc = SessionService(
      notifier: _FakeNotifier(),
      settingsService: SettingsService(),
    );
    await svc.loadSettings();

    await t.pumpWidget(ChangeNotifierProvider.value(
      value: svc,
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(ctx).push(MaterialPageRoute(
                builder: (_) => const LookAwayScreen(),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Skip'), findsOneWidget);

    await t.tap(find.text('Skip'));
    await t.pumpAndSettle();
    expect(find.text('Skip'), findsNothing);
  });
}
```

- [ ] **Step 2: Run — expect fail**

Run: `flutter test test/screens/look_away_screen_test.dart`
Expected: FAIL — `LookAwayScreen` not defined.

- [ ] **Step 3: Implement `CountdownRing`**

Create `lib/widgets/countdown_ring.dart`:
```dart
import 'package:flutter/material.dart';

class CountdownRing extends StatelessWidget {
  final double progress; // 0.0 -> 1.0
  final String label;

  const CountdownRing({super.key, required this.progress, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.tealAccent),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.w300),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement `LookAwayScreen`**

Create `lib/screens/look_away_screen.dart`:
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_service.dart';
import '../widgets/countdown_ring.dart';

class LookAwayScreen extends StatefulWidget {
  final VoidCallback? onChime;
  const LookAwayScreen({super.key, this.onChime});

  @override
  State<LookAwayScreen> createState() => _LookAwayScreenState();
}

class _LookAwayScreenState extends State<LookAwayScreen> {
  late int _total;
  late int _remaining;
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _total = context.read<SessionService>().settings.lookAwaySeconds;
    _remaining = _total;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        _done = true;
        widget.onChime?.call();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).maybePop();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total == 0 ? 1.0 : (_total - _remaining) / _total;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Text(
              'Look 20 feet away',
              style: TextStyle(color: Colors.white, fontSize: 22),
            ),
            const SizedBox(height: 24),
            CountdownRing(
              progress: progress,
              label: _done ? '✓' : '$_remaining',
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Skip',
                  style: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run — expect pass**

Run: `flutter test test/screens/look_away_screen_test.dart`
Expected: PASS (both tests).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/look_away_screen.dart lib/widgets/countdown_ring.dart test/screens/look_away_screen_test.dart
git commit -m "feat: add LookAwayScreen with countdown ring and injectable chime"
```

---

## Task 8: App shell — main.dart, Provider wiring, notification tap → look-away

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `NotificationService`, `SettingsService`, `SessionService`, `HomeScreen`, `LookAwayScreen`.
- Produces: a runnable app that (a) initialises the notification plugin, (b) provides `SessionService` app-wide, (c) navigates to `LookAwayScreen` when a reminder notification is tapped or fires while the app is foregrounded.

- [ ] **Step 1: Replace `lib/main.dart`**

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/look_away_screen.dart';
import 'services/notification_service.dart';
import 'services/session_service.dart';
import 'services/settings_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notifier = NotificationService();
  await notifier.init();

  final settingsService = SettingsService();
  final session = SessionService(
    notifier: notifier,
    settingsService: settingsService,
  );
  await session.loadSettings();

  notifier.onTap.listen((_) async {
    await session.onReminderFired();
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => LookAwayScreen(
        onChime: () => AudioPlayer().play(AssetSource('sounds/chime.mp3')),
      ),
    ));
  });

  runApp(
    ChangeNotifierProvider.value(
      value: session,
      child: const BlinkApp(),
    ),
  );
}

class BlinkApp extends StatelessWidget {
  const BlinkApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Blink',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
```

- [ ] **Step 2: Ensure existing tests still pass**

Run: `flutter test`
Expected: all previously-added tests PASS. (No new test in this task — the wiring is verified manually in Step 3.)

- [ ] **Step 3: Manual smoke check (Android emulator or physical device)**

```bash
flutter run -d <deviceId>
```
Expected: app launches to Home screen, tapping Start toggles to Stop, gear icon opens Settings. Notification delivery on iOS is verified separately in Task 10.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire app shell with Provider, notifications, and look-away routing"
```

---

## Task 9: Notification permission handling + denied banner

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/services/notification_service.dart` (add `Future<bool> hasPermission()`)
- Create: `test/services/notification_permission_test.dart` (skipped on host; documents behavior)

**Interfaces:**
- Consumes: `permission_handler`.
- Produces: `Future<bool> Notifier.hasPermission()` and a `Notifier.requestPermission()`.

- [ ] **Step 1: Extend `Notifier` and `NotificationService`**

In `lib/services/notification_service.dart`, add two methods to the abstract class and implementation:

```dart
// In abstract class Notifier:
Future<bool> hasPermission();
Future<bool> requestPermission();
```

In `NotificationService`:
```dart
@override
Future<bool> hasPermission() async {
  final ios = _plugin.resolvePlatformSpecificImplementation<
      IOSFlutterLocalNotificationsPlugin>();
  if (ios != null) {
    final granted = await ios.checkPermissions();
    return granted?.isEnabled ?? false;
  }
  final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (android != null) {
    return await android.areNotificationsEnabled() ?? false;
  }
  return true;
}

@override
Future<bool> requestPermission() async {
  final ios = _plugin.resolvePlatformSpecificImplementation<
      IOSFlutterLocalNotificationsPlugin>();
  if (ios != null) {
    return await ios.requestPermissions(alert: true, sound: true) ?? false;
  }
  final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (android != null) {
    return await android.requestNotificationsPermission() ?? true;
  }
  return true;
}
```

Update every existing `implements Notifier` (in tests) to add stubs:
```dart
@override Future<bool> hasPermission() async => true;
@override Future<bool> requestPermission() async => true;
```

Files to update (search-and-add the two stub methods):
- `test/services/notification_service_test.dart` (`_NoopNotifier`)
- `test/services/session_service_test.dart` (`FakeNotifier`)
- `test/screens/home_screen_test.dart` (`_FakeNotifier`)
- `test/screens/settings_screen_test.dart` (`_FakeNotifier`)
- `test/screens/look_away_screen_test.dart` (`_FakeNotifier`)

- [ ] **Step 2: Expose permission checks via `SessionService`**

Add to `lib/services/session_service.dart`:
```dart
Future<bool> checkNotificationPermission() => _notifier.hasPermission();
Future<bool> requestNotificationPermission() => _notifier.requestPermission();
```

- [ ] **Step 3: Add permission check and banner to `HomeScreen`**

In `lib/screens/home_screen.dart`:

Add a state field to `_HomeScreenState`:
```dart
bool _permissionOk = true;
```

Extend `initState` to check permission after first frame:
```dart
@override
void initState() {
  super.initState();
  _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted) setState(() {});
  });
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final svc = context.read<SessionService>();
    final ok = await svc.checkNotificationPermission();
    if (!ok) {
      final granted = await svc.requestNotificationPermission();
      if (mounted) setState(() => _permissionOk = granted);
    }
  });
}
```

In the `build` method's `Column` children, insert the banner as the first child (before `CircularButton`):
```dart
if (!_permissionOk)
  Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 24),
    color: Colors.orange.shade100,
    child: const Text(
      'Notifications are disabled. Enable them in Settings for reminders to work.',
    ),
  ),
```

- [ ] **Step 4: Run all tests**

Run: `flutter test`
Expected: all PASS. If any fail due to missing `hasPermission`/`requestPermission` stubs, add them to the fake classes.

- [ ] **Step 5: Commit**

```bash
git add lib/services/notification_service.dart lib/services/session_service.dart lib/screens/home_screen.dart test/
git commit -m "feat: request notification permission on launch and show banner if denied"
```

---

## Task 10: Sound assets & iOS platform config

**Files:**
- Replace: `assets/sounds/alarm.mp3`, `assets/sounds/chime.mp3` (real audio files)
- Modify: `ios/Runner/Info.plist`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: real audio files.
- Produces: working sound + platform permissions declared.

- [ ] **Step 1: Add real sound files**

Source two royalty-free sounds (~1 s alarm chime, ~2 s soft end chime). Save to `assets/sounds/alarm.mp3` and `assets/sounds/chime.mp3`. Suggestion: pixabay.com/sound-effects (filter by license).

- [ ] **Step 2: Configure iOS `Info.plist`**

Add inside the top-level `<dict>` in `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>remote-notification</string>
</array>
```

- [ ] **Step 3: Configure Android manifest**

Add permissions in `android/app/src/main/AndroidManifest.xml`, above `<application>`:
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

Inside `<application>` block, add the receivers required by `flutter_local_notifications` (per its README):
```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
  </intent-filter>
</receiver>
```

- [ ] **Step 4: Run app on Android emulator**

```bash
flutter run -d <android-emulator-id>
```

Verify:
- Tap Start → notification arrives ~20 min later (temporarily set intervalMinutes=1 in Settings to test faster).
- Tap notification → LookAwayScreen opens → countdown → chime plays → auto-dismiss.

- [ ] **Step 5: Run app on iOS (on borrowed Mac)**

```bash
open ios/Runner.xcworkspace   # on Mac
# In Xcode: sign with your Apple ID, run on connected iPhone or simulator.
# From CLI on Mac:
flutter run -d <ios-device-id>
```

Verify same flow. Confirm notification fires when phone is locked.

- [ ] **Step 6: Full test suite pass**

Run: `flutter test`
Expected: all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add assets/sounds/ ios/ android/
git commit -m "feat: add sound assets and iOS/Android notification config"
```

---

## Wrap-up

At this point:
- `flutter test` passes.
- The app runs on Android and iOS (via borrowed Mac).
- Reminders fire at the configured interval, tapping opens the look-away screen, countdown + chime + auto-dismiss.
- Settings persist across app launches.
- Permission denial shows a banner.

Next candidates (out of scope for v1, tracked as follow-ups if desired): active-hours scheduler, custom sounds, statistics, camera-based blink detection, App Store submission.
