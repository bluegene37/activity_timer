import 'package:signals/signals_flutter.dart';

import '../models/interval_timer.dart';
import '../routes/app_pages.dart';
import '../routes/app_routes.dart';
import '../services/database_service.dart';
import '../services/ui_messenger.dart';

class IntervalTimerController {
  final _databaseService = DatabaseService();

  // Reactive variables
  final intervalTimers = listSignal<IntervalTimer>([]);
  final isLoading = signal(true);

  void onInit() {
    loadIntervalTimers();
  }

  Future<void> loadIntervalTimers() async {
    isLoading.value = true;
    try {
      final timers = await _databaseService.getAllIntervalTimers();
      timers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      intervalTimers.value = List.of(timers);
    } catch (e) {
      UiMessenger().showMessage(
        'Failed to load interval timers: $e',
        title: 'Error',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addNewIntervalTimer() async {
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, now.hour, 0);
    final endTime = startTime.add(const Duration(hours: 8));

    final result = await AppPages.push<dynamic>(
      Routes.editIntervalTimer,
      extra: (
        timer: IntervalTimer(
          name: 'New Interval Timer',
          startTime: startTime,
          endTime: endTime,
          intervalValue: 1,
          intervalType: IntervalType.hour,
        ),
        isNew: true,
      ),
    );

    if (result == true) {
      await refreshTimers();
    }
  }

  Future<void> deleteIntervalTimer(String id) async {
    try {
      await _databaseService.deleteIntervalTimer(id);
      intervalTimers.removeWhere((timer) => timer.id == id);

      // Delay snackbar slightly to ensure any dialog has closed
      await Future<void>.delayed(const Duration(milliseconds: 100));
      UiMessenger().showMessage('Interval timer deleted', title: 'Success');
    } catch (e) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      UiMessenger().showMessage(
        'Failed to delete interval timer: $e',
        title: 'Error',
      );
    }
  }

  Future<void> refreshTimers() async {
    await loadIntervalTimers();
  }
}
