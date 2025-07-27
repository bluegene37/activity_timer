import 'package:get/get.dart';
import '../navigation/main_navigation.dart';
import '../screens/timer_list_screen.dart';
import '../screens/timer_screen.dart';
import '../screens/edit_timer_screen.dart';
import '../screens/interval_timer_screen.dart';
import '../screens/edit_interval_timer_screen.dart';
import '../screens/settings_screen.dart';
import '../controllers/activity_list_controller.dart';
import '../controllers/timer_list_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/interval_timer_controller.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.HOME;

  static final routes = [
    GetPage(
      name: _Paths.HOME,
      page: () => const MainNavigation(),
      bindings: [
        BindingsBuilder(() {
          Get.lazyPut<ActivityListController>(() => ActivityListController());
          Get.lazyPut<IntervalTimerController>(() => IntervalTimerController());
          Get.lazyPut<SettingsController>(() => SettingsController());
        }),
      ],
    ),
    GetPage(
      name: _Paths.TIMER_LIST,
      page: () => const TimerListScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut<TimerListController>(() => TimerListController());
      }),
    ),
    GetPage(
      name: _Paths.TIMER,
      page: () {
        final sequence = Get.arguments;
        return TimerScreen(sequence: sequence);
      },
    ),
    GetPage(
      name: _Paths.EDIT_TIMER,
      page: () {
        final timer = Get.arguments;
        return EditTimerScreen(timer: timer);
      },
    ),
    GetPage(
      name: _Paths.INTERVAL_TIMER,
      page: () {
        final timer = Get.arguments;
        return IntervalTimerScreen(timer: timer);
      },
    ),
    GetPage(
      name: _Paths.EDIT_INTERVAL_TIMER,
      page: () {
        final args = Get.arguments as Map<String, dynamic>;
        return EditIntervalTimerScreen(
          timer: args['timer'],
          isNew: args['isNew'],
        );
      },
    ),
    GetPage(
      name: _Paths.SETTINGS,
      page: () => const SettingsScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut<SettingsController>(() => SettingsController());
      }),
    ),
  ];
}

abstract class _Paths {
  _Paths._();
  
  static const HOME = '/home';
  static const TIMER_LIST = '/timer-list';
  static const TIMER = '/timer';
  static const EDIT_TIMER = '/edit-timer';
  static const INTERVAL_TIMER = '/interval-timer';
  static const EDIT_INTERVAL_TIMER = '/edit-interval-timer';
  static const SETTINGS = '/settings';
}