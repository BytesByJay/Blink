import 'package:flutter/foundation.dart';

import '../models/settings.dart';
import 'notifier.dart';
import 'reminder_timer.dart';
import 'settings_service.dart';

class SessionService extends ChangeNotifier {
  final Notifier _notifier;
  final SettingsService _settingsService;
  final DateTime Function() _clock;

  /// When the running session's reminder schedule started; null when stopped.
  DateTime? _startedAt;

  /// The break the user has already seen out, so reopening Blink during it
  /// does not put the Look-Away screen back up.
  DateTime? _dismissedBreakAt;
  Settings _settings = const Settings.defaults();

  SessionService({
    required Notifier notifier,
    required SettingsService settingsService,
    DateTime Function() clock = DateTime.now,
  }) : _notifier = notifier,
       _settingsService = settingsService,
       _clock = clock;

  bool get isActive => _startedAt != null;
  Settings get settings => _settings;

  DateTime? get nextReminderAt {
    final startedAt = _startedAt;
    if (startedAt == null) return null;
    return nextReminderAfter(startedAt, _interval, _clock());
  }

  Duration get _interval => Duration(minutes: _settings.intervalMinutes);

  /// How much of the break that is running right now is left, or null when no
  /// break is. iOS hands the break to AlarmKit and reports nothing back, so
  /// Blink works out from the schedule alone whether it is opening mid-break.
  Duration? get breakRemaining {
    final startedAt = _startedAt;
    if (startedAt == null) return null;
    final now = _clock();
    final startedBreakAt = lastReminderAtOrBefore(startedAt, _interval, now);
    if (startedBreakAt == null || startedBreakAt == _dismissedBreakAt) {
      return null;
    }
    final endsAt = startedBreakAt.add(
      Duration(seconds: _settings.lookAwaySeconds),
    );
    return endsAt.isAfter(now) ? endsAt.difference(now) : null;
  }

  /// Marks the running break as seen out, whether it was skipped or finished.
  void dismissCurrentBreak() {
    final startedAt = _startedAt;
    if (startedAt == null) return;
    _dismissedBreakAt = lastReminderAtOrBefore(startedAt, _interval, _clock());
  }

  /// Loads settings and resumes the session that was running when the app
  /// last closed, if any.
  Future<void> loadSettings() async {
    _settings = await _settingsService.load();
    final savedStart = await _settingsService.loadSessionStart();
    if (savedStart != null) {
      final intact = await _notifier.resumeRepeating(
        savedStart,
        _interval,
        lookAwaySeconds: _settings.lookAwaySeconds,
        sound: _settings.soundEnabled,
        vibration: _settings.vibrationEnabled,
      );
      _startedAt = intact ? savedStart : _clock();
      if (!intact) await _settingsService.saveSessionStart(_startedAt);
    }
    notifyListeners();
  }

  Future<void> start() async {
    _settings = await _settingsService.load();
    await _startSchedule();
    notifyListeners();
  }

  Future<void> stop() async {
    _startedAt = null;
    _dismissedBreakAt = null;
    await _notifier.cancelAll();
    await _settingsService.saveSessionStart(null);
    notifyListeners();
  }

  Future<void> applySettings(Settings s) async {
    _settings = s;
    await _settingsService.save(s);
    if (isActive) await _startSchedule();
    notifyListeners();
  }

  Future<bool> checkNotificationPermission() => _notifier.hasPermission();
  Future<bool> requestNotificationPermission() => _notifier.requestPermission();

  Future<void> _startSchedule() async {
    _startedAt = _clock();
    _dismissedBreakAt = null;
    await _notifier.startRepeating(
      _interval,
      lookAwaySeconds: _settings.lookAwaySeconds,
      sound: _settings.soundEnabled,
      vibration: _settings.vibrationEnabled,
    );
    await _settingsService.saveSessionStart(_startedAt);
  }
}
