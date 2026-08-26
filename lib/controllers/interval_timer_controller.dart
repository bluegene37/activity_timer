import 'package:get/get.dart';

import '../models/interval_timer.dart';
import '../routes/app_routes.dart';
import '../services/database_service.dart';
import '../services/ui_messenger.dart';

class IntervalTimerController extends GetxController {
  final _databaseService = DatabaseService();

  // Reactive variables
  final RxList<IntervalTimer> intervalTimers = <IntervalTimer>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadIntervalTimers();
  }

  Future<void> loadIntervalTimers() async {
    isLoading.value = true;
    try {
      final timers = await _databaseService.getAllIntervalTimers();
      timers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      intervalTimers.assignAll(timers);
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

    // GetX builds every named route as `GetPageRoute<dynamic>`, so pushing with
    // a concrete result type throws inside `Navigator.pushNamed`. Push untyped
    // and narrow the result here.
    final result = await Get.toNamed<dynamic>(
      Routes.editIntervalTimer,
      arguments: (
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
