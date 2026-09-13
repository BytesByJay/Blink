# Blink

A minimal cross-platform app that reminds you to rest your eyes on a set interval. Built around the **20-20-20 rule**: every 20 minutes, look 20 feet away for 20 seconds.

Runs on **iOS**, **Android**, and **desktop browsers** as an installable PWA: **[bytesbyjay.github.io/Blink](https://bytesbyjay.github.io/Blink/)**

## Features

- **Alarm-style reminders**: buzzer sound + vibration + notification. The phone's OS repeats them on its own, so they keep coming when you ignore one, lock the phone, or switch to another app (local notifications, no server needed).
- **Shows through Focus on iPhone**: reminders are Time Sensitive, so Do Not Disturb and other Focus modes don't hide them.
- **Full-screen look-away timer**: tap the notification to open a countdown that removes the temptation to keep staring at the screen; a gentle chime plays when the rest is done.
- **Configurable**: interval (1 / 5 / 10 / 15 / 20 / 30 / 45 / 60 min), look-away duration (10 / 20 / 30 / 45 / 60 s), sound on/off, vibration on/off.
- **Simple Start / Stop model**: you decide when a work session begins and ends. A running session survives the app being closed; reminders continue until you press Stop.
- **Web version (PWA)**: same app in Chrome, Edge, Firefox, or Safari on your computer. Install it as its own window; reminders fire while it is open, even in the background.

## Screens

- **Home**: large circular Start / Stop button and a live "next reminder in mm:ss" countdown.
- **Settings**: dropdowns for interval and look-away duration; toggles for sound and vibration.
- **Look-Away**: dark full-screen overlay with a countdown ring, "Look 20 feet away" prompt, chime on completion, and a Skip escape hatch.

## Tech Stack

- **Flutter** (Dart): iOS + Android + web from one codebase
- **provider**: state management
- **shared_preferences**: persist settings and the running session
- **flutter_local_notifications**: repeating OS-level reminders (mobile)
- **web**: browser Notification API (web)
- **audioplayers**: reminder sound (web) and end-chime
- **GitHub Actions + GitHub Pages**: web build and hosting

## Project Structure

```
lib/
  main.dart                    App entry, Provider setup, notification-tap routing
  models/settings.dart         Settings data class (interval, look-away, sound, vibration)
  services/
    settings_service.dart      Load/save settings and the running session via shared_preferences
    notifier.dart              Notifier interface shared by mobile and web
    notifier_factory.dart      Picks the mobile or web Notifier at compile time
    notification_service.dart  Mobile Notifier: repeating reminders via flutter_local_notifications
    web_notifier.dart          Web Notifier: in-page timer + browser notifications
    reminder_timer.dart        Repeating reminder timer (sleep-aware), used by web
    session_service.dart       Start/Stop, resume after restart, restart on setting changes
  screens/
    home_screen.dart           Start/Stop button + countdown
    settings_screen.dart       Interval, look-away, sound, vibration controls
    look_away_screen.dart      Full-screen countdown + chime
    look_away_launcher.dart    Opens Look-Away for a reminder without stacking a second one
  widgets/
    circular_button.dart       Reusable large button
    countdown_ring.dart        Animated ring for look-away countdown
assets/sounds/                 mixkit-warning-alarm-buzzer-991.wav (alarm), chime.mp3
ios/Runner/                    blink_alarm.wav (notification sound), Runner.entitlements (Time Sensitive)
android/app/src/main/res/raw/  blink_alarm.wav (notification sound), keep.xml
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

- **Alarm**: "Warning alarm buzzer" from [Mixkit](https://mixkit.co/free-sound-effects/alarm/) (Mixkit Free License), 8 seconds. The web version plays `assets/sounds/mixkit-warning-alarm-buzzer-991.wav`; iOS and Android notifications use the copies at `ios/Runner/blink_alarm.wav` and `android/app/src/main/res/raw/blink_alarm.wav`. To change the alarm, replace all three. iOS notification sounds must be under 30 seconds.
- **End chime**: `assets/sounds/chime.mp3` is still an **empty placeholder**. Replace it with real audio before shipping and keep the filename.

## Testing

36 tests cover the model, services, and screen widgets:

- `test/models/`: Settings defaults, `copyWith`, and JSON round-trip
- `test/services/`: persistence; notification details (alarm sound, silent mode, Time Sensitive, Android channels); session Start/Stop, reminders continuing when ignored, resume after an app restart; web reminder timer (repeating, wake-from-sleep)
- `test/screens/`: Home Start/Stop toggle, Settings controls (including the 1 min interval), Look-Away countdown, centring, Skip, and no stacked Look-Away screens

All run in pure Dart with `flutter_local_notifications` faked and `shared_preferences` mocked, so no device is required.

## Web Version (PWA)

**Live:** [bytesbyjay.github.io/Blink](https://bytesbyjay.github.io/Blink/)

- Click **Start** and allow notifications when the browser asks.
- In Chrome or Edge, use **Install Blink** in the address bar to get a standalone window that won't get lost among tabs.
- If the Blink tab is visible when a reminder is due, the look-away screen opens directly. If it's in the background, you get a desktop notification; click it to open the look-away screen.

**Limits (by browser design):**
- Reminders only fire while Blink is open. Closing the tab or window pauses them; reopening Blink picks the schedule back up. Until you click somewhere on the reopened page, the browser may block the alarm sound.
- Background tabs may deliver a reminder up to about a minute late.
- If the computer sleeps, the reminder fires within about 15 seconds of waking.
- Windows Focus Assist and macOS Focus hide browser notifications.
- Not meant for iPhone/iPad: iOS pauses web apps in the background, so reminders would not fire. Use the iOS app instead.

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

- **iOS silent mode** silences the notification sound; vibration still works. Expected system behavior. Ringing through silent mode would need Apple's Critical Alerts entitlement.
- **iOS Focus / Do Not Disturb**: reminders are Time Sensitive and show through Focus unless you turn off "Time Sensitive Notifications" for Blink in `Settings → Notifications → Blink`. Signing needs the Time Sensitive Notifications capability on your Apple developer team; if Xcode reports it isn't supported, remove `CODE_SIGN_ENTITLEMENTS` from the Runner target and reminders fall back to normal priority.
- **iOS notification permission** is requested on first launch. If denied, the app shows a persistent banner. Re-enable in `Settings → Notifications → Blink`.
- **Android 13+** requires the runtime `POST_NOTIFICATIONS` permission (also requested on first launch).
- **Web** asks for notification permission when you click Start (browsers block prompts that aren't triggered by a click). If blocked, Blink shows a banner; re-enable in the browser's site settings. The Vibration setting is hidden on web.

## License

Personal project. No license selected yet.
