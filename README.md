# Blink

A minimal cross-platform mobile app that reminds you to rest your eyes on a set interval. Built around the **20-20-20 rule**: every 20 minutes, look 20 feet away for 20 seconds.

## Features

- **Alarm-style reminders** — sound + vibration + notification, fires even when the phone is locked or the app is backgrounded (via local notifications, no server needed).
- **Full-screen look-away timer** — tap the notification to open a countdown that removes the temptation to keep staring at the screen; a gentle chime plays when the rest is done.
- **Configurable** — interval (5 / 10 / 15 / 20 / 30 / 45 / 60 min), look-away duration (10 / 20 / 30 / 45 / 60 s), sound on/off, vibration on/off.
- **Simple Start / Stop model** — you decide when a work session begins and ends. No always-on background chatter.

## Screens

- **Home** — large circular Start / Stop button and a live "next reminder in mm:ss" countdown.
- **Settings** — dropdowns for interval and look-away duration; toggles for sound and vibration.
- **Look-Away** — dark full-screen overlay with a countdown ring, "Look 20 feet away" prompt, chime on completion, and a Skip escape hatch.

## Tech Stack

- **Flutter** (Dart) — iOS + Android from one codebase
- **provider** — state management
- **shared_preferences** — persist settings
- **flutter_local_notifications** — scheduled OS-level alarms
- **audioplayers** — reminder sound and end-chime
- **timezone** — exact scheduling across timezones

## Project Structure

```
lib/
  main.dart                    App entry, Provider setup, notification-tap routing
  models/settings.dart         Settings data class (interval, look-away, sound, vibration)
  services/
    settings_service.dart      Load/save settings via shared_preferences
    notification_service.dart  Notifier abstraction + flutter_local_notifications wrapper
    session_service.dart       Start/Stop, rescheduling on setting changes
  screens/
    home_screen.dart           Start/Stop button + countdown
    settings_screen.dart       Interval, look-away, sound, vibration controls
    look_away_screen.dart      Full-screen countdown + chime
  widgets/
    circular_button.dart       Reusable large button
    countdown_ring.dart        Animated ring for look-away countdown
assets/sounds/                 alarm.mp3, chime.mp3
test/                          Unit tests for services and widget tests for screens
docs/superpowers/              Design spec and implementation plan
```

## Getting Started

Prerequisites:
- Flutter SDK 3.13.3 or newer ([install guide](https://docs.flutter.dev/get-started/install))
- For Android: Android Studio + Android SDK
- For iOS: a Mac with Xcode installed

Setup:

```bash
git clone git@github.com:BytesByJay/Blink.git
cd Blink
flutter pub get
```

Run on a connected device or emulator:

```bash
flutter run
```

Run the test suite:

```bash
flutter test
```

## Sound Assets

The repo ships with **empty placeholder files** at `assets/sounds/alarm.mp3` and `assets/sounds/chime.mp3`. Replace them with real audio before shipping — [pixabay.com/sound-effects](https://pixabay.com/sound-effects) has royalty-free options. Keep the filenames identical.

## Testing

17 tests cover the model, services, and screen widgets:

- `test/models/` — Settings defaults, `copyWith`, and JSON round-trip
- `test/services/` — persistence, notification scheduling, session Start/Stop, reschedule on setting changes
- `test/screens/` — Home Start/Stop toggle, Settings controls, Look-Away countdown and Skip

All run in pure Dart with `flutter_local_notifications` and `shared_preferences` mocked, so no device is required.

## Design Documents

- [Design spec](docs/superpowers/specs/2026-09-12-blink-reminder-app-design.md) — goals, non-goals, screens, data model, behavior
- [Implementation plan](docs/superpowers/plans/2026-09-12-blink-reminder-app.md) — 10 tasks, TDD steps, and code

## Roadmap (out of scope for v1)

- Camera-based blink detection
- Scheduled active-hours window (auto-start / auto-stop by time of day)
- Custom sound picker
- Reminder history and stats
- App Store / Play Store submission
- Cross-device settings sync

## Platform Notes

- **iOS silent mode** silences the notification sound; vibration still works. Expected system behavior.
- **iOS notification permission** is requested on first launch. If denied, the app shows a persistent banner. Re-enable in `Settings → Notifications → Blink`.
- **Android 13+** requires the runtime `POST_NOTIFICATIONS` permission (also requested on first launch).

## License

Personal project — no license selected yet.
