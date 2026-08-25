import 'package:get/get.dart';

import '../controllers/activity_list_controller.dart';
import '../controllers/interval_timer_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/timer_list_controller.dart';
import '../models/activity_timer.dart';
import '../models/brew_recipe.dart';
import '../models/interval_timer.dart';
import '../navigation/main_navigation.dart';
import '../screens/brew_edit_screen.dart';
import '../screens/brew_run_screen.dart';
import '../screens/edit_interval_timer_screen.dart';
import '../screens/edit_timer_screen.dart';
import '../screens/interval_timer_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/timer_list_screen.dart';
import '../screens/timer_screen.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static const initial = Routes.home;

  static final List<GetPage<dynamic>> routes = [
    GetPage<void>(
      name: Routes.home,
      page: () => const MainNavigation(),
      bindings: [
        BindingsBuilder<void>(() {
          Get.lazyPut<ActivityListController>(ActivityListController.new);
          Get.lazyPut<IntervalTimerController>(IntervalTimerController.new);
          Get.lazyPut<SettingsController>(SettingsController.new);
        }),
      ],
    ),
    GetPage<void>(
      name: Routes.timerList,
      page: () => const TimerListScreen(),
      binding: BindingsBuilder<void>(() {
        Get.lazyPut<TimerListController>(TimerListController.new);
      }),
    ),
    GetPage<void>(
      name: Routes.timer,
      page: () => TimerScreen(sequence: Get.arguments as TimerSequence),
    ),
    GetPage<ActivityTimer>(
      name: Routes.editTimer,
      page: () => EditTimerScreen(timer: Get.arguments as ActivityTimer),
    ),
    GetPage<void>(
      name: Routes.intervalTimer,
      page: () => IntervalTimerScreen(timer: Get.arguments as IntervalTimer),
    ),
    GetPage<bool>(
      name: Routes.editIntervalTimer,
      page: () {
        final args = Get.arguments as EditIntervalTimerArgs;
        return EditIntervalTimerScreen(timer: args.timer, isNew: args.isNew);
      },
    ),
    GetPage<void>(
      name: Routes.editBrew,
      page: () {
        final args = Get.arguments as EditBrewArgs;
        return BrewEditScreen(recipe: args.recipe, isNew: args.isNew);
      },
    ),
    GetPage<void>(
      name: Routes.brew,
      page: () => BrewRunScreen(recipe: Get.arguments as BrewRecipe),
    ),
    GetPage<void>(
      name: Routes.settings,
      page: () => const SettingsScreen(),
      binding: BindingsBuilder<void>(() {
        Get.lazyPut<SettingsController>(SettingsController.new);
      }),
    ),
  ];
}
