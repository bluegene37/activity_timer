import 'package:get_it/get_it.dart';

import '../controllers/activity_list_controller.dart';
import '../controllers/app_controller.dart';
import '../controllers/brew_controller.dart';
import '../controllers/interval_timer_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/timer_list_controller.dart';

/// Where controllers are looked up, replacing `Get.put` / `Get.find`.
///
/// Lazy singletons, so a controller is built the first time a screen asks
/// for it and reused after — the behavior `Get.lazyPut` gave us, without
/// tying controller lifetime to a route.
final GetIt locator = GetIt.instance;

/// Called once at startup, and again by tests between cases.
void setUpLocator() {
  if (locator.isRegistered<AppController>()) {
    return;
  }
  locator
    ..registerLazySingleton<AppController>(() => AppController()..onInit())
    ..registerLazySingleton<ActivityListController>(
      () => ActivityListController()..onInit(),
    )
    ..registerLazySingleton<IntervalTimerController>(
      () => IntervalTimerController()..onInit(),
    )
    ..registerLazySingleton<TimerListController>(
      () => TimerListController()..onInit(),
    )
    ..registerLazySingleton<BrewController>(() => BrewController()..onInit())
    ..registerLazySingleton<SettingsController>(
      () => SettingsController()..onInit(),
    );
}

/// Drops every registration. Tests call this between cases the way they
/// used to call `Get.reset()`.
Future<void> resetLocator() => locator.reset();
