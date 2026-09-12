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
