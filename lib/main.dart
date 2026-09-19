import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/look_away_launcher.dart';
import 'services/notifier_factory.dart';
import 'services/session_service.dart';
import 'services/settings_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// iOS ends a break with AlarmKit's own alert, so an in-app chime would double
/// up. Every other platform still chimes.
VoidCallback? chimeCallback() => defaultTargetPlatform == TargetPlatform.iOS
    ? null
    : () => AudioPlayer().play(AssetSource('sounds/chime.mp3'));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notifier = createNotifier();
  await notifier.init();

  final settingsService = SettingsService();
  final session = SessionService(
    notifier: notifier,
    settingsService: settingsService,
  );
  // Also resumes a session that was running when the app was last closed.
  await session.loadSettings();

  final lookAway = LookAwayLauncher(navigatorKey, onChime: chimeCallback());
  notifier.onTap.listen((_) => lookAway.show());
  final launchedFromReminder = await notifier.launchedFromReminder();

  runApp(
    ChangeNotifierProvider.value(
      value: session,
      child: BlinkApp(navigatorKey: navigatorKey, lookAway: lookAway),
    ),
  );

  // A tap that launched the app is reported here rather than on onTap.
  if (launchedFromReminder) {
    WidgetsBinding.instance.addPostFrameCallback((_) => lookAway.show());
  }
}

class BlinkApp extends StatefulWidget {
  const BlinkApp({
    super.key,
    required this.navigatorKey,
    required this.lookAway,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final LookAwayLauncher lookAway;

  @override
  State<BlinkApp> createState() => _BlinkAppState();
}

class _BlinkAppState extends State<BlinkApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Covers a cold launch that lands mid-break.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openBreakIfRunning());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _openBreakIfRunning();
  }

  /// iOS hands the break to AlarmKit, which alerts in system UI and reports
  /// nothing back, so opening Blink from that alert has to be noticed here:
  /// the Look-Away screen picks up what is left of the break instead of the
  /// Home screen counting down to the next interval.
  void _openBreakIfRunning() {
    if (!mounted) return;
    final left = context.read<SessionService>().breakRemaining;
    if (left == null) return;
    widget.lookAway.show(
      remainingSeconds: (left.inMilliseconds / 1000).ceil(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      title: 'Blink',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
