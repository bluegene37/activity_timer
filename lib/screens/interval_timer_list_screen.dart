import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/interval_timer.dart';
import '../controllers/interval_timer_controller.dart';
import '../components/for_ui_card.dart';
import '../components/for_ui_button.dart';
import '../theme/for_ui.dart';
import 'edit_interval_timer_screen.dart';
import 'interval_timer_screen.dart';

class IntervalTimerListScreen extends StatelessWidget {
  const IntervalTimerListScreen({super.key});

  Future<void> _addNewIntervalTimer() async {
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, now.hour, 0);
    final endTime = startTime.add(const Duration(hours: 8));
    
    final result = await Get.toNamed('/edit-interval-timer', arguments: {
      'timer': IntervalTimer(
        name: 'New Interval Timer',
        startTime: startTime,
        endTime: endTime,
        intervalValue: 1,
        intervalType: IntervalType.hour,
      ),
      'isNew': true,
    });
    
    if (result == true) {
      Get.find<IntervalTimerController>().refreshTimers();
    }
  }

  Future<void> _editIntervalTimer(IntervalTimer timer) async {
    final result = await Get.toNamed('/edit-interval-timer', arguments: {
      'timer': timer,
      'isNew': false,
    });
    
    if (result == true) {
      Get.find<IntervalTimerController>().refreshTimers();
    }
  }

  void _startIntervalTimer(IntervalTimer timer) {
    Get.toNamed('/interval-timer', arguments: timer);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<IntervalTimerController>();
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interval Timers'),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (controller.intervalTimers.isEmpty) {
          return ForUI.emptyState(
            title: 'No Interval Timers Yet',
            message: 'Create your first interval timer to get started with timed alerts.',
            buttonText: 'Create Interval Timer',
            onButtonPressed: _addNewIntervalTimer,
            icon: Icons.schedule,
          );
        }
        
        return ListView.builder(
          itemCount: controller.intervalTimers.length,
          padding: const EdgeInsets.all(ForUI.spacing),
          itemBuilder: (context, index) {
            final timer = controller.intervalTimers[index];
            final timeFormat = DateFormat('h:mm a');
            
            return ForUICard(
              padding: const EdgeInsets.all(ForUI.spacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          timer.name,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editIntervalTimer(timer),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () {
                          Get.dialog(
                            AlertDialog(
                              title: const Text('Delete Interval Timer'),
                              content: Text(
                                'Are you sure you want to delete "${timer.name}"?'
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Get.back(),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    controller.deleteIntervalTimer(timer.id);
                                    Get.back();
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: ForUI.spacingSmall),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${timeFormat.format(timer.startTime)} - ${timeFormat.format(timer.endTime)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: ForUI.spacingSmall),
                  Row(
                    children: [
                      Icon(
                        Icons.repeat,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timer.intervalString,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: ForUI.spacingSmall),
                  Row(
                    children: [
                      Icon(
                        Icons.notifications,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${timer.totalAlarms} alarms',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: ForUI.spacing),
                  ForUIButton(
                    text: 'START',
                    icon: Icons.play_arrow,
                    onPressed: () => _startIntervalTimer(timer),
                    isFullWidth: true,
                  ),
                ],
              ),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewIntervalTimer,
        child: const Icon(Icons.add),
      ),
    );
  }
}
