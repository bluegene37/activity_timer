import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/interval_timer.dart';
import '../controllers/interval_timer_controller.dart';
import '../theme/app_theme.dart';

class IntervalTimerListScreen extends StatelessWidget {
  const IntervalTimerListScreen({super.key});

  Future<void> _addNewIntervalTimer() async {
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, now.hour, 0);
    final endTime = startTime.add(const Duration(hours: 8));

    final result = await Get.toNamed(
      '/edit-interval-timer',
      arguments: {
        'timer': IntervalTimer(
          name: 'New Interval Timer',
          startTime: startTime,
          endTime: endTime,
          intervalValue: 1,
          intervalType: IntervalType.hour,
        ),
        'isNew': true,
      },
    );

    if (result == true) {
      Get.find<IntervalTimerController>().refreshTimers();
    }
  }

  Future<void> _editIntervalTimer(IntervalTimer timer) async {
    final result = await Get.toNamed(
      '/edit-interval-timer',
      arguments: {'timer': timer, 'isNew': false},
    );

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
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.schedule,
                      color: colorScheme.onPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Interval Timers',
                          style: textTheme.headlineSmall,
                        ),
                        Text(
                          'Keep track of your intervals',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Intervals',
                    style: textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.intervalTimers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 64,
                            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No intervals yet',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.intervalTimers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 24),
                  itemBuilder: (context, index) {
                    final timer = controller.intervalTimers[index];
                    final timeFormat = DateFormat('h:mm a');

                    return Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    timer.name,
                                    style: textTheme.titleMedium,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit, size: 20, color: colorScheme.onSurfaceVariant),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _editIntervalTimer(timer),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: Icon(Icons.delete, size: 20, color: colorScheme.onSurfaceVariant),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      onPressed: () async {
                                        final confirm = await Get.dialog<bool>(
                                          AlertDialog(
                                            title: const Text('Delete Interval Timer'),
                                            content: Text('Are you sure you want to delete "${timer.name}"?'),
                                            actions: [
                                              TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
                                              TextButton(
                                                onPressed: () => Get.back(result: true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          controller.deleteIntervalTimer(timer.id);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Badges row
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.access_time, size: 14, color: colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${timeFormat.format(timer.startTime)} - ${timeFormat.format(timer.endTime)}',
                                        style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.repeat, size: 14, color: colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        timer.intervalString,
                                        style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.notifications, size: 14, color: colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${timer.totalAlarms} alarms',
                                        style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // Open button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () => _startIntervalTimer(timer),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                                  foregroundColor: colorScheme.primary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Start',
                                      style: textTheme.titleSmall?.copyWith(color: colorScheme.primary),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.play_arrow, size: 18, color: colorScheme.primary),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'interval_timer_list_fab',
        onPressed: _addNewIntervalTimer,
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
