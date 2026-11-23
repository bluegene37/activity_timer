// Gene - Nov, 22, 2026: Shared wakelock coordinator so finishing or pausing one timer never disables screen wakelock while a concurrent Activity, Interval, or Brew session is still running.
import 'package:wakelock_plus/wakelock_plus.dart';

import 'activity_session_service.dart';
import 'brew_session_service.dart';
import 'interval_session_service.dart';

class WakelockCoordinator {
  static bool get anySessionRunning {
    final activityRunning =
        ActivitySessionService().active.value?.isRunning.value ?? false;
    final intervalRunning =
        IntervalSessionService().active.value?.isRunning.value ?? false;
    final brewRunning =
        BrewSessionService().active.value?.isRunning.value ?? false;
    return activityRunning || intervalRunning || brewRunning;
  }

  static Future<void> sync() async {
    try {
      if (anySessionRunning) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  static Future<void> releaseIfIdle() async {
    try {
      if (!anySessionRunning) {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }
}
