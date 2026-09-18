import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blink/main.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iOS has no in-app chime, since the alarm sounds instead', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(chimeCallback(), isNull);
  });

  test('Android keeps the in-app chime', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(chimeCallback(), isNotNull);
  });
}
