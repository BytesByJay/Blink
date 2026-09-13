import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/look_away_launcher.dart';
import 'services/notifier_factory.dart';
import 'services/session_service.dart';
import 'services/settings_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  final lookAway = LookAwayLauncher(
    navigatorKey,
    onChime: () => AudioPlayer().play(AssetSource('sounds/chime.mp3')),
  );
  notifier.onTap.listen((_) => lookAway.show());
  final launchedFromReminder = await notifier.launchedFromReminder();

  runApp(ChangeNotifierProvider.value(value: session, child: const BlinkApp()));

  // A tap that launched the app is reported here rather than on onTap.
  if (launchedFromReminder) {
    WidgetsBinding.instance.addPostFrameCallback((_) => lookAway.show());
  }
}

class BlinkApp extends StatelessWidget {
  const BlinkApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Blink',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
