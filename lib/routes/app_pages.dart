import 'package:go_router/go_router.dart';

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
import '../services/ui_messenger.dart';
import 'app_routes.dart';

/// The app's router.
///
/// Routes carry their argument in go_router's `extra`. Pushes are typed:
/// `push<T>` returns `Future<T?>`, so a screen's result comes back as the
/// type it was declared with.
abstract final class AppPages {
  static const initial = Routes.home;

  /// The app's router. Built once for the running app.
  static final GoRouter router = createRouter();

  /// A fresh router over the same routes.
  ///
  /// Each one owns its route-information state, so tests that mount several
  /// apps in a row do not inherit the previous one's location — or its
  /// `extra`, which comes back as a decoded map rather than the object that
  /// was pushed.
  static GoRouter createRouter({String initialLocation = initial}) => GoRouter(
    // Shared with UiMessenger so controllers can raise dialogs and route
    // without a BuildContext.
    navigatorKey: UiMessenger().navigatorKey,
    initialLocation: initialLocation,
    routes: routes,
  );

  static final List<RouteBase> routes = [
    GoRoute(
      path: Routes.home,
      builder: (context, state) => const MainNavigation(),
    ),
    GoRoute(
      path: Routes.timerList,
      builder:
          (context, state) =>
              TimerListScreen(sequence: state.extra as TimerSequence?),
    ),
    GoRoute(
      path: Routes.timer,
      builder:
          (context, state) =>
              TimerScreen(sequence: state.extra! as TimerSequence),
    ),
    GoRoute(
      path: Routes.editTimer,
      builder:
          (context, state) =>
              EditTimerScreen(timer: state.extra! as ActivityTimer),
    ),
    GoRoute(
      path: Routes.intervalTimer,
      builder:
          (context, state) =>
              IntervalTimerScreen(timer: state.extra! as IntervalTimer),
    ),
    GoRoute(
      path: Routes.editIntervalTimer,
      builder: (context, state) {
        final args = state.extra! as EditIntervalTimerArgs;
        return EditIntervalTimerScreen(timer: args.timer, isNew: args.isNew);
      },
    ),
    GoRoute(
      path: Routes.editBrew,
      builder: (context, state) {
        final args = state.extra! as EditBrewArgs;
        return BrewEditScreen(recipe: args.recipe, isNew: args.isNew);
      },
    ),
    GoRoute(
      path: Routes.brew,
      builder:
          (context, state) => BrewRunScreen(recipe: state.extra! as BrewRecipe),
    ),
    GoRoute(
      path: Routes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
  ];

  /// Pushes a route from anywhere, including code with no `BuildContext`.
  ///
  /// Returns null when there is no live router (a widget test that pumped a
  /// bare screen), so callers degrade instead of throwing.
  static Future<T?> push<T>(String path, {Object? extra}) {
    final context = UiMessenger().navigatorKey.currentContext;
    if (context == null) {
      return Future<T?>.value();
    }
    return GoRouter.of(context).push<T>(path, extra: extra);
  }
}
