import 'package:get_it/get_it.dart';

import '../controllers/activity_list_controller.dart';
import '../controllers/app_controller.dart';
import '../controllers/brew_controller.dart';
import '../controllers/interval_timer_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/timer_list_controller.dart';

/// Where controllers are looked up.
///
/// Lazy singletons: a controller is built the first time a screen asks for
/// it and reused after, so its lifetime follows the app rather than any one
/// route.
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

/// Drops every registration. Tests call this between cases so one case's
/// controller state cannot leak into the next.
Future<void> resetLocator() => locator.reset();
