# Blink

A minimal cross-platform app that reminds you to rest your eyes on a set interval. Built around the **20-20-20 rule**: every 20 minutes, look 20 feet away for 20 seconds.

Runs on **iOS**, **Android**, and **desktop browsers** as an installable PWA: **[bytesbyjay.github.io/Blink](https://bytesbyjay.github.io/Blink/)**

## Features

- **Alarm-style reminders**: sound + vibration + notification, fires even when the phone is locked or the app is backgrounded (via local notifications, no server needed).
- **Full-screen look-away timer**: tap the notification to open a countdown that removes the temptation to keep staring at the screen; a gentle chime plays when the rest is done.
- **Configurable**: interval (1 / 5 / 10 / 15 / 20 / 30 / 45 / 60 min), look-away duration (10 / 20 / 30 / 45 / 60 s), sound on/off, vibration on/off.
- **Simple Start / Stop model**: you decide when a work session begins and ends. No always-on background chatter.
- **Web version (PWA)**: same app in Chrome, Edge, Firefox, or Safari on your computer. Install it as its own window; reminders fire while it is open, even in the background.

## Screens

- **Home**: large circular Start / Stop button and a live "next reminder in mm:ss" countdown.
- **Settings**: dropdowns for interval and look-away duration; toggles for sound and vibration.
- **Look-Away**: dark full-screen overlay with a countdown ring, "Look 20 feet away" prompt, chime on completion, and a Skip escape hatch.

## Tech Stack

- **Flutter** (Dart): iOS + Android + web from one codebase
- **provider**: state management
- **shared_preferences**: persist settings
- **flutter_local_notifications**: scheduled OS-level alarms (mobile)
- **web**: browser Notification API (web)
- **audioplayers**: reminder sound and end-chime
- **timezone**: exact scheduling across timezones
- **GitHub Actions + GitHub Pages**: web build and hosting

## Project Structure

```
lib/
  main.dart                    App entry, Provider setup, reminder and notification-tap routing
  models/settings.dart         Settings data class (interval, look-away, sound, vibration)
  services/
    settings_service.dart      Load/save settings via shared_preferences
    notifier.dart              Notifier interface shared by mobile and web
    notifier_factory.dart      Picks the mobile or web Notifier at compile time
    notification_service.dart  Mobile Notifier: flutter_local_notifications wrapper
    web_notifier.dart          Web Notifier: in-page timer + browser notifications
    reminder_timer.dart        One-shot reminder timer (sleep-aware), used by web
    session_service.dart       Start/Stop, rescheduling on setting changes
  screens/
    home_screen.dart           Start/Stop button + countdown
    settings_screen.dart       Interval, look-away, sound, vibration controls
    look_away_screen.dart      Full-screen countdown + chime
  widgets/
    circular_button.dart       Reusable large button
    countdown_ring.dart        Animated ring for look-away countdown
assets/sounds/                 mixkit-warning-alarm-buzzer-991.wav (alarm), chime.mp3
web/                           PWA shell: index.html, manifest.json, icons
.github/workflows/             deploy-web.yml: test, build, publish to GitHub Pages
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

Run the web version locally (from WSL, open the printed URL in your Windows browser):

```bash
flutter run -d web-server --web-port 8080
```

Run the test suite:

```bash
flutter test
```

## Sound Assets

- **Alarm** (web): `assets/sounds/mixkit-warning-alarm-buzzer-991.wav`, "Warning alarm buzzer" from [Mixkit](https://mixkit.co/free-sound-effects/alarm/) (Mixkit Free License). On iOS and Android the reminder uses the system notification sound.
- **End chime**: `assets/sounds/chime.mp3` is still an **empty placeholder**. Replace it with real audio before shipping and keep the filename.

## Testing

26 tests cover the model, services, and screen widgets:

- `test/models/`: Settings defaults, `copyWith`, and JSON round-trip
- `test/services/`: persistence, notification scheduling, session Start/Stop, reschedule on setting changes, duplicate-trigger guard, web reminder timer (including wake-from-sleep)
- `test/screens/`: Home Start/Stop toggle, Settings controls, Look-Away countdown and Skip

All run in pure Dart with `flutter_local_notifications` and `shared_preferences` mocked, so no device is required.

## Web Version (PWA)

**Live:** [bytesbyjay.github.io/Blink](https://bytesbyjay.github.io/Blink/)

- Click **Start** and allow notifications when the browser asks.
- In Chrome or Edge, use **Install Blink** in the address bar to get a standalone window that won't get lost among tabs.
- If the Blink tab is visible when a reminder is due, the look-away screen opens directly. If it's in the background, you get a desktop notification; click it to open the look-away screen.

**Limits (by browser design):**
- Reminders only fire while Blink is open. Closing the tab or window stops them.
- Background tabs may deliver a reminder up to about a minute late.
- If the computer sleeps, the reminder fires within about 15 seconds of waking.
- Windows Focus Assist and macOS Focus hide browser notifications.
- Not meant for iPhone/iPad: iOS pauses web apps in the background, so reminders would not fire.

**Deployment:** every push to `main` runs `.github/workflows/deploy-web.yml`, which runs the tests, builds with `flutter build web --release --base-href /Blink/`, and publishes to GitHub Pages. One-time setup: in the repo, **Settings → Pages → Source: GitHub Actions**.

## Design Documents

- [Design spec](docs/superpowers/specs/2026-09-12-blink-reminder-app-design.md): goals, non-goals, screens, data model, behavior
- [Implementation plan](docs/superpowers/plans/2026-09-12-blink-reminder-app.md): 10 tasks, TDD steps, and code
- [PWA design spec](docs/superpowers/specs/2026-09-13-blink-pwa-design.md): web target, reminder flow, hosting

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
- **Web** asks for notification permission when you click Start (browsers block prompts that aren't triggered by a click). If blocked, Blink shows a banner; re-enable in the browser's site settings. The Vibration setting is hidden on web.

## License

Personal project. No license selected yet.
