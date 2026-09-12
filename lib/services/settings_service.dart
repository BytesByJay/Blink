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
