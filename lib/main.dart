import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:get/get.dart';
import 'models/settings.dart';
import 'models/activity_timer.dart';
import 'models/interval_timer.dart';
import 'models/alarm_sound.dart';
import 'services/database_service.dart';
import 'routes/app_pages.dart';
import 'theme/for_ui.dart';
import 'controllers/app_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(AppSettingsDataAdapter());
  Hive.registerAdapter(ActivityTimerAdapter());
  Hive.registerAdapter(TimerSequenceAdapter());
  Hive.registerAdapter(IntervalTimerAdapter());
  Hive.registerAdapter(IntervalTypeAdapter());
  Hive.registerAdapter(AlarmSoundAdapter());

  // Initialize database service
  final databaseService = DatabaseService();
  await databaseService.init();
  await databaseService.insertDemoDataIfEmpty();

  // Load app settings
  final settings = AppSettings();
  await settings.loadSettings();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize the app controller
    final appController = Get.put(AppController());

    return Obx(
      () => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Activity Timer',
        theme: ForUI.getLightTheme(appController.themeColor.value),
        darkTheme: ForUI.getDarkTheme(appController.themeColor.value),
        themeMode: ThemeMode.system, // Always follow system or force dark/light
        initialRoute: '/home',
        getPages:
            AppPages
                .routes, // Assuming AppRoutes.pages is a typo and should be AppPages.routes
      ),
    );
  }
}
