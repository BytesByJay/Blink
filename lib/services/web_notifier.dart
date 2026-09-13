import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:audioplayers/audioplayers.dart';
import 'package:web/web.dart' as web;

import 'notifier.dart';
import 'reminder_timer.dart';

/// [Notifier] for desktop browsers.
///
/// Reminders are driven by an in-page timer, so they only fire while Blink is
/// open in a tab or installed window.
class WebNotifier implements Notifier {
  final _timer = ReminderTimer();
  final _tapController = StreamController<void>.broadcast();
  final _alarm = AudioPlayer();
  web.Notification? _shown;
  bool _sound = true;

  bool get _supported => web.window.has('Notification');

  @override
  Stream<void> get onTap => _tapController.stream;

  @override
  Future<void> init() async {
    _timer.onFired.listen((_) => _deliver());
  }

  @override
  Future<void> startRepeating(
    Duration interval, {
    required bool sound,
    required bool vibration,
  }) async {
    _sound = sound;
    _timer.start(DateTime.now(), interval);
  }

  /// The page's timers died with the previous page, so the schedule is always
  /// re-created on its original times.
  @override
  Future<bool> resumeRepeating(
    DateTime startedAt,
    Duration interval, {
    required bool sound,
    required bool vibration,
  }) async {
    _sound = sound;
    _timer.start(startedAt, interval);
    return true;
  }

  @override
  Future<void> cancelAll() async {
    _timer.cancel();
    _shown?.close();
    _shown = null;
  }

  @override
  Future<bool> launchedFromReminder() async => false;

  @override
  Future<bool> hasPermission() async =>
      _supported && web.Notification.permission == 'granted';

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart == 'granted';
  }

  void _deliver() {
    if (_sound) {
      unawaited(
        _alarm
            .play(AssetSource('sounds/mixkit-warning-alarm-buzzer-991.wav'))
            .catchError((Object _) {}),
      );
    }

    // Visible page: go straight to the look-away screen.
    if (web.document.visibilityState == 'visible') {
      _tapController.add(null);
      return;
    }

    if (!_supported || web.Notification.permission != 'granted') return;
    _shown?.close();
    final notification = web.Notification(
      'Time to rest your eyes',
      web.NotificationOptions(
        body: 'Look 20 feet away for a moment',
        icon: 'icons/Icon-192.png',
        tag: 'blink-reminder',
        requireInteraction: true,
      ),
    );
    notification.onclick = ((web.Event _) {
      web.window.focus();
      notification.close();
      _tapController.add(null);
    }).toJS;
    _shown = notification;
  }
}
