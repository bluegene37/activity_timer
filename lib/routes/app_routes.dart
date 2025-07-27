abstract class Routes {
  Routes._();
  
  static const HOME = _Paths.HOME;
  static const TIMER_LIST = _Paths.TIMER_LIST;
  static const TIMER = _Paths.TIMER;
  static const EDIT_TIMER = _Paths.EDIT_TIMER;
  static const INTERVAL_TIMER = _Paths.INTERVAL_TIMER;
  static const EDIT_INTERVAL_TIMER = _Paths.EDIT_INTERVAL_TIMER;
  static const SETTINGS = _Paths.SETTINGS;
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