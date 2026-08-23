import '../models/interval_timer.dart';

/// Named routes served by `AppPages.routes`.
abstract final class Routes {
  static const home = '/home';
  static const timerList = '/timer-list';
  static const timer = '/timer';
  static const editTimer = '/edit-timer';
  static const intervalTimer = '/interval-timer';
  static const editIntervalTimer = '/edit-interval-timer';
  static const settings = '/settings';
}

/// Arguments accepted by [Routes.editIntervalTimer].
typedef EditIntervalTimerArgs = ({IntervalTimer timer, bool isNew});
