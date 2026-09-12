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
