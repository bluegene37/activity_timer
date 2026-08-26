import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:signals/signals_flutter.dart';

import 'controllers/app_controller.dart';
import 'hive_registrar.g.dart';
import 'models/settings.dart';
import 'routes/app_pages.dart';
import 'services/database_service.dart';
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
  setUpLocator();
  locator<AppController>();

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
