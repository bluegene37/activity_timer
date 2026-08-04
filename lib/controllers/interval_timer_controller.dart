import 'package:get/get.dart';
import '../models/interval_timer.dart';
import '../services/database_service.dart';

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
      Get.snackbar('Error', 'Failed to load interval timers: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteIntervalTimer(String id) async {
    try {
      await _databaseService.deleteIntervalTimer(id);
      intervalTimers.removeWhere((timer) => timer.id == id);
      
      // Delay snackbar slightly to ensure any dialog has closed
      await Future.delayed(const Duration(milliseconds: 100));
      Get.snackbar('Success', 'Interval timer deleted');
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 100));
      Get.snackbar('Error', 'Failed to delete interval timer: $e');
    }
  }

  Future<void> refreshTimers() async {
    await loadIntervalTimers();
  }
}
