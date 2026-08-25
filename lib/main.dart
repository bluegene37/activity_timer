import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'controllers/app_controller.dart';
import 'hive_registrar.g.dart';
import 'models/settings.dart';
import 'routes/app_pages.dart';
import 'services/database_service.dart';
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

  // Inject the app controller strictly after settings have fully loaded from DB
  // so the UI immediately draws using the saved theme color, avoiding flashes of defaults.
  Get.put(AppController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Find the app controller that was injected during main()
    final appController = Get.find<AppController>();

    return Obx(
      () => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Activity Timer',
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
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
      ),
    );
  }
}
