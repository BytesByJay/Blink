# Blink Reminder App — Design Spec

**Date:** 2026-09-12
**Author:** Dhananjay Haridas
**Status:** Draft for review

## 1. Purpose

A cross-platform mobile app (iOS primary, Android secondary) that reminds users to rest their eyes at a set interval, following the **20-20-20 rule**: every 20 minutes, look 20 feet away for 20 seconds. All parameters are user-configurable.

The app fires alarm-style notifications (sound + vibration + banner) and, when tapped, opens a full-screen countdown that removes the temptation to keep staring at the screen during the rest period.

## 2. Goals & Non-Goals

**Goals:**
- Reliable local notifications on iOS and Android, firing even when the app is backgrounded or the phone is locked.
- Simple Start / Stop model — user controls sessions explicitly.
- Configurable interval, look-away duration, sound, and vibration.
- Full-screen "look away" overlay with a countdown and end-chime.

**Non-Goals (v1):**
- Actual blink detection (via camera).
- Cloud sync of settings across devices.
- Statistics / history of reminders.
- Scheduled "active hours" (deferred; Start/Stop button is enough for v1).
- App-store publishing (deferred; internal / TestFlight only initially).

## 3. Platform & Stack

- **Framework:** Flutter (Dart).
- **Notifications:** `flutter_local_notifications` package.
- **State management:** `Provider` package.
- **Persistence:** `shared_preferences` package.
- **Audio:** `audioplayers` package for reminder sound and end chime.
- **Development host:** Windows/Linux (day-to-day). Mac (borrowed) required only for iOS build & test.

**Rationale for Flutter:** cross-platform, one codebase for iOS + Android, mature local-notification support, no Mac required for daily development.

## 4. User Flow

1. **First launch** → app requests notification permission → Home screen.
2. **Home screen** shows a large circular **Start** button.
3. User taps **Start** → button becomes **Stop**, countdown ("Next reminder in 19:47") appears, first reminder scheduled for 20 minutes out.
4. When the reminder time arrives → local notification fires (sound + vibration per settings) → next reminder is scheduled.
5. User taps the notification → **Look-Away** full-screen overlay opens → 20-second countdown → gentle chime → auto-dismiss back to Home.
6. Loop until user taps **Stop** → all pending notifications cancelled.

## 5. Screens

### 5.1 Home Screen
- App title "Blink" at top.
- Centered large circular button — **Start** (idle) / **Stop** (active).
- When active: countdown text below button showing time to next reminder.
- Status line: current interval + look-away duration (tap → Settings).
- Gear icon top-right → Settings.

### 5.2 Settings Screen
- **Interval** — dropdown: 5 / 10 / 15 / 20 / 30 / 45 / 60 min. Default: 20.
- **Look-away duration** — dropdown: 10 / 20 / 30 / 45 / 60 sec. Default: 20.
- **Sound** — toggle + "Test" preview button. Default: on.
- **Vibration** — toggle. Default: on.
- Back arrow returns to Home. If a session is active when a setting changes, the currently-pending reminder is cancelled and re-scheduled using the new values (behavior specified in §8.1).

### 5.3 Look-Away Overlay
- Full-screen dark background (deep blue/black).
- Centered text: "Look 20 feet away".
- Animated countdown ring + numeric countdown (e.g., 20 → 0).
- On reaching 0: chime plays, screen shows "Done ✓" for 2 s, then auto-dismisses.
- Small "Skip" text button at the bottom.

## 6. Data Model

Persisted via `shared_preferences` as individual keys (no JSON blob needed for such a small schema):

```
Settings {
  intervalMinutes:   int   (default 20)
  lookAwaySeconds:   int   (default 20)
  soundEnabled:      bool  (default true)
  vibrationEnabled:  bool  (default true)
}
```

In-memory only (not persisted):

```
SessionState {
  isActive:         bool
  nextReminderAt:   DateTime?
}
```

## 7. Project Structure

```
lib/
  main.dart                    // MaterialApp + Provider setup
  models/
    settings.dart
  services/
    notification_service.dart  // wraps flutter_local_notifications
    session_service.dart       // Start/Stop, schedules next reminder
    settings_service.dart      // shared_preferences wrapper
  screens/
    home_screen.dart
    settings_screen.dart
    look_away_screen.dart
  widgets/
    circular_button.dart
    countdown_ring.dart
assets/
  sounds/
    alarm.mp3
    chime.mp3
```

## 8. Key Behaviors

### 8.1 Notification scheduling
- Each reminder is scheduled as a **single one-shot notification** at `now + intervalMinutes`.
- When a reminder fires, the app schedules the *next* one. This keeps the interval exact and honours Stop cleanly.
- On **Stop**: all pending notifications are cancelled via `flutter_local_notifications`.
- On **settings change while active**: cancel pending + re-schedule using new interval.

### 8.2 Look-away overlay trigger
- **App in foreground when reminder fires** → overlay appears automatically.
- **App backgrounded** → tapping the notification opens the app directly to the overlay (via notification payload).
- **User ignores notification** → overlay does not appear; next reminder still scheduled.

### 8.3 Permissions
- On first launch, request notification permission (iOS + Android 13+).
- If denied, Home screen shows a persistent banner: "Notifications are disabled. Enable them in Settings for reminders to work."

## 9. Testing

- **Unit tests:**
  - `SettingsService`: save/load round-trip for each field, default values.
  - `SessionService`: `start()` schedules a notification; `stop()` cancels; interval change re-schedules.
- **Widget tests:**
  - Home screen renders Start button when idle, Stop when active, countdown updates.
  - Settings screen: toggling a value persists it.
- **Manual test (iOS, on borrowed Mac):**
  - Notification fires when app is backgrounded.
  - Notification fires when phone is locked.
  - Tapping notification opens the look-away overlay.
  - Vibration works when phone is on silent.
  - Sound is muted (expected) when phone is on silent.

## 10. Risks & Open Questions

- **iOS silent mode:** system silences notification sound. Vibration still works. Documented in-app on the Sound setting.
- **iOS notification permission denied:** app is functionally useless; banner explains how to re-enable.
- **App icon & branding:** placeholder for v1; final design deferred.
- **Distribution:** v1 is developer builds only. TestFlight and Play Store submission deferred.

## 11. Out of Scope for This Spec

The following are intentionally deferred and will be tracked as follow-up work if desired after v1:
- Camera-based blink detection.
- Cross-device sync.
- Reminder history / stats.
- Scheduled active-hours window.
- Custom sounds.
