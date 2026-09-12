import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/look_away_screen.dart';
import 'services/notification_service.dart';
import 'services/session_service.dart';
import 'services/settings_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notifier = NotificationService();
  await notifier.init();

  final settingsService = SettingsService();
  final session = SessionService(
    notifier: notifier,
    settingsService: settingsService,
  );
  await session.loadSettings();

  notifier.onTap.listen((_) async {
    await session.onReminderFired();
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => LookAwayScreen(
        onChime: () => AudioPlayer().play(AssetSource('sounds/chime.mp3')),
      ),
    ));
  });

  runApp(
    ChangeNotifierProvider.value(
      value: session,
      child: const BlinkApp(),
    ),
  );
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
