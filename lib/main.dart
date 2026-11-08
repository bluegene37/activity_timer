import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:signals/signals_flutter.dart';

import 'controllers/app_controller.dart';
import 'hive_registrar.g.dart';
import 'models/settings.dart';
import 'routes/app_pages.dart';
// Gene - Nov, 06, 2026: Added session services and alarm scheduler imports for session restoration on app startup.
import 'services/activity_session_service.dart';
import 'services/alarm_scheduler.dart';
// Gene - Nov, 7, 2026: Added BrewSessionService import so active brew sessions restore on cold startup alongside activity and interval sessions.
import 'services/brew_session_service.dart';
import 'services/database_service.dart';
import 'services/interval_session_service.dart';
import 'services/locator.dart';
import 'services/ui_messenger.dart';
import 'theme/app_theme.dart';
import 'theme/brew_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapters();

  // Initialize database service
  final databaseService = DatabaseService();
  await databaseService.init();
  await databaseService.insertDemoDataIfEmpty();

  // Load app settings
  final settings = AppSettings();
  await settings.loadSettings();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Register controllers strictly after settings have loaded from the
  // database, so the first frame draws with the saved theme instead of
  // flashing defaults.
  // Gene - Nov, 06, 2026: Preserved original controller setup and runApp sequence.
  // setUpLocator();
  // locator<AppController>();
  //
  // runApp(const MyApp());

  // Gene - Nov, 06, 2026: Restored active activity and interval sessions and initialized notification launch handling so background runs revive seamlessly upon notification tap.
  setUpLocator();
  locator<AppController>();

  await ActivitySessionService().restoreSessionIfActive();
  await IntervalSessionService().restoreSessionIfActive();
  // Gene - Nov, 7, 2026: Restore active brew session on startup so its floating pill revives upon notification launch.
  await BrewSessionService().restoreSessionIfActive();
  await LocalNotificationAlarmScheduler.initializeAndCheckLaunch();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Find the app controller that was injected during main()
    final appController = locator<AppController>();

    return SignalBuilder(
      builder:
          (_) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Activity Timer',
            // Lets controllers report failures without reaching for a
            // global BuildContext. The navigator key lives on the router.
            scaffoldMessengerKey: UiMessenger().messengerKey,
            theme:
                appController.themeStyle.value == AppThemeStyle.coffee
                    ? BrewTheme.themeFor(Brightness.light)
                    : AppTheme.getLightTheme(appController.themeColor.value),
            darkTheme:
                appController.themeStyle.value == AppThemeStyle.coffee
                    ? BrewTheme.themeFor(Brightness.dark)
                    : AppTheme.getDarkTheme(appController.themeColor.value),
            themeMode:
                appController
                    .themeMode
                    .value, // Follow exactly what's chosen in settings
            routerConfig: AppPages.router,
          ),
    );
  }
}
