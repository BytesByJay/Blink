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
