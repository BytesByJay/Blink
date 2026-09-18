# iOS AlarmKit Look-Away Countdown — Design Spec

**Date:** 2026-09-18
**Author:** Dhananjay Haridas
**Status:** Draft

## 1. Purpose

Move the look-away break out of the app and into iOS system UI. When a reminder
comes due, the Lock Screen and Dynamic Island show a live countdown for the
look-away duration, then alert when the break is over. The user completes a
whole break without opening Blink.

Today the break only exists inside `LookAwayScreen`, which requires tapping a
notification to reach. A standard iOS notification is static and cannot show a
countdown, so this needs AlarmKit (iOS 26).

## 2. Goals & Non-Goals

**Goals:**
- A break is followable start to finish from the Lock Screen or Dynamic Island.
- The countdown is rendered by the system and keeps running while Blink is
  suspended or terminated.
- No server. Blink stays fully offline and local.
- Android and web behaviour is unchanged.

**Non-Goals:**
- iOS below 26. The deployment target moves 15.0 → 26.0 and there is no
  pre-26 fallback path (explicit decision, see §9).
- A countdown in Android notifications. `usesChronometer` would give this
  cheaply but is out of scope for this spec.
- Replacing `LookAwayScreen`. It stays for users who open the app.
- Changing the reminder interval model, settings, or persistence.

## 3. Why AlarmKit and not a self-started Live Activity

`Activity.request()` cannot start a Live Activity while the app is suspended —
it requires the foreground or an ActivityKit push, which would mean APNs and a
backend. Blink's entire model is that the OS fires while the app is closed, so
a per-break Live Activity is exactly the thing that cannot happen.

An AlarmKit alarm is *scheduled*, so the system starts its Live Activity on
Blink's behalf. That is the only local mechanism that satisfies the goal.

## 4. Break Lifecycle

AlarmKit orders a countdown phase *before* an alert phase. Mapping the look-away
break onto `preAlert` would put the loud moment at the end of the break and
leave its start silent — the inverse of what Blink is for.

So the break is `postAlert`, not `preAlert`. `AlarmPresentation.Alert` takes a
`secondaryButton` with `secondaryButtonBehavior: .countdown`, which transitions
an alerting alarm back into the countdown state for `postAlert`.

One alarm per break:

```
schedule:          .fixed(breakStart)
countdownDuration: .init(postAlert: lookAwaySeconds)
presentation:      .alert(title: "Time to rest your eyes",
                          stopButton: "Skip",
                          secondaryButton: "Look away",
                          secondaryButtonBehavior: .countdown)
```

1. At `breakStart` the alarm **alerts** — sound and a persistent banner that cut
   through silent mode and Focus. This is the prompt to look away.
2. The user taps **Look away**. The alarm moves into its countdown state and the
   Dynamic Island, Lock Screen and StandBy show a live countdown for
   `lookAwaySeconds`, drawn by Blink's widget extension.
3. At zero the alarm alerts again, signalling the break is over.
4. **Skip** dismisses the break without running the countdown.

`preAlert` is unused, so nothing is displayed between breaks and Blink does not
occupy the Dynamic Island outside a break.

**Accepted trade-off:** the break is not hands-free — it takes one tap to begin.
An AlarmKit alert persists until acted on, so the user interacts with it either
way.

## 5. Architecture

The existing `Notifier` abstraction absorbs this without touching the app layer.

```
lib/services/
  notifier.dart               unchanged interface
  notifier_factory.dart       unchanged conditional export
  notifier_factory_mobile.dart  branches on Platform.isIOS
  alarm_kit_notifier.dart     NEW: Notifier over a MethodChannel
  notification_service.dart   unchanged, now Android-only
  web_notifier.dart           unchanged

ios/
  BlinkAlarmWidget/           NEW Widget Extension target
    BlinkAlarmWidget.swift    ActivityConfiguration over AlarmAttributes
  Runner/AppDelegate.swift    registers the AlarmKit MethodChannel
```

```dart
Notifier createNotifier() =>
    Platform.isIOS ? AlarmKitNotifier() : NotificationService();
```

`SessionService`, `HomeScreen`, `SettingsScreen` and the settings model need no
changes. That is the payoff of the interface already being in place.

**The widget extension is mandatory, not cosmetic.** Scheduling anything with a
`countdownDuration` without one risks the system dismissing alarms and failing
to alert.

## 6. Scheduling Model

AlarmKit supports one-time and weekly recurrence — not "every N minutes". Blink
pre-schedules a batch of upcoming breaks and tops it up when the app opens.

- `startRepeating(interval)` — cancel all, then schedule the next `N` breaks at
  `now + interval * k` for `k` in `1..N`.
- `resumeRepeating(startedAt, interval)` — count alarms the system still holds.
  If the batch is intact, top it back up to `N` from `startedAt`'s cadence and
  return `true`. If empty, fall through to `startRepeating` and return `false`.
  This matches the existing contract exactly.
- `cancelAll()` — cancel every scheduled alarm.

`N` is bounded by AlarmKit's pending-alarm limit (§10). With a 20-minute
interval, `N = 24` covers eight hours, which comfortably exceeds the gap between
app opens for a working-day app.

## 7. Permissions

A second authorization, separate from notifications:

- `NSAlarmKitUsageDescription` in `Info.plist`.
- `AlarmManager.shared.requestAuthorization()`.
- `hasPermission()` / `requestPermission()` map onto it; `HomeScreen`'s existing
  permission banner and prompt keep working unchanged.

`com.apple.developer.usernotifications.time-sensitive` in `Runner.entitlements`
becomes dead on iOS once notifications are gone from that platform, and is
removed.

## 8. What Changes for `LookAwayScreen` on iOS

The break now runs in system UI, so the in-app screen is no longer the primary
path. It stays reachable by opening the app, but:

- Its chime would double up with the alarm's own alert. On iOS the chime is
  suppressed; the alarm provides the end-of-break signal.
- `onTap` still opens it when the user taps through from the alarm.
- The in-app `ReminderTimer` added for the foreground case stays on Android and
  web. On iOS the system owns break timing, so `AlarmKitNotifier` does not run
  one.

## 9. Risks & Accepted Trade-offs

| Risk | Note |
|---|---|
| **Break needs a tap to start** | The countdown begins when the user taps "Look away", not automatically at break time. A behaviour change from today's automatic `LookAwayScreen`, accepted because an AlarmKit alert must be dismissed either way. |
| **Dynamic Island is iPhone 14 Pro+** | Every other device gets Lock Screen and banner only. "iOS 26" and "has a Dynamic Island" are different populations. |
| **iOS 26 minimum drops users** | No fallback path by explicit decision. Anyone below iOS 26, or on hardware iOS 26 does not support, can no longer install or update Blink. |
| **Custom sound may not work** | AlarmKit custom sounds are reported broken on iOS 26.0. Blink may be stuck with the default alarm sound until Apple fixes it, making `blink_alarm.wav` iOS-dead. |
| **Alarm semantics** | AlarmKit is an attention-demanding alarm API. A 20-minute eye-break cadence is a heavier use than a one-off alarm; users may revoke authorization if it feels intrusive. |
| **No CI coverage** | The widget extension and Island rendering are device-only. CI (`flutter test`) covers the Dart side alone. |
| **Batch drift** | If the app is not opened for longer than the batch covers, reminders stop until it is. Bounded by `N`. |

## 10. Open Questions for Implementation

1. **Pending-alarm limit.** AlarmKit's maximum scheduled-alarm count is
   unconfirmed; it sets `N` in §6. Verify on device and clamp.
2. **Custom alert sound.** `AlertConfiguration.AlertSound` accepts sounds from
   the app bundle or `Library/Sounds`, but custom sounds are reported broken on
   iOS 26.0 (a system error tone plays instead). Verify on the target OS
   version; if broken, ship the default alarm sound and revisit. See §12.
3. **Sound and vibration settings.** `Settings.soundEnabled` /
   `vibrationEnabled` may have no AlarmKit equivalent, since alarms
   deliberately cut through silent mode. If unsupported, both toggles are
   hidden on iOS rather than silently ignored.
4. **Flutter bridge.** Check for an existing AlarmKit plugin before hand-rolling
   the MethodChannel.
5. **End-of-break alert buttons.** The second alert (step 3 in §4) is the same
   alarm, so it may still offer "Look away" and allow an unwanted second
   countdown. Confirm on device and adjust the presentation if so.

## 11. Testing

- **Dart:** `AlarmKitNotifier` unit-tested against a fake `MethodChannel`,
  asserting the scheduled batch times, top-up behaviour, and cancellation —
  same shape as the existing `_FakePlugin` tests.
- **Factory:** `createNotifier()` returns `AlarmKitNotifier` on iOS and
  `NotificationService` on Android.
- **Regression:** existing Android and web tests must pass untouched.
- **Manual, device-only:** the alarm alerts at break time through Focus and
  silent mode; "Look away" starts a visible countdown on the Lock Screen and
  Dynamic Island; the countdown survives backgrounding and force-quit; the
  second alert fires at zero; "Skip" dismisses without a countdown; the batch
  tops up on app open.

## 12. Alarm Sound Selection

iOS does not expose the system ringtone or alarm tone library to third-party
apps. There is no picker API and no way to enumerate the tones the Clock app
offers, so users cannot choose from their own device tones.

What is possible is a Blink-supplied set: bundle several sounds, add a picker to
Settings, and pass the choice to `AlertConfiguration.AlertSound`. Given the
iOS 26.0 custom-sound bug (§10.2), this is **deferred out of this spec** and
the alarm ships with the system default sound.

## 13. Out of Scope

- Android chronometer countdown.
- Any pre-iOS-26 fallback.
- Snoozing or repeating a break more than once.
- A user-selectable alarm sound (see §12).
- Server-driven or push-to-start Live Activities.
