import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/interval_timer.dart';
import '../models/alarm_sound.dart';
import '../controllers/interval_timer_controller.dart';
import '../services/database_service.dart';
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

  Future<void> _addWorkplacePreset({
    required String name,
    required int intervalValue,
    required IntervalType intervalType,
    required int durationHours,
    AlarmSound alarmSound = AlarmSound.bell,
  }) async {
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, now.hour, 0);
    final endTime = startTime.add(Duration(hours: durationHours));

    final newTimer = IntervalTimer(
      name: name,
      startTime: startTime,
      endTime: endTime,
      intervalValue: intervalValue,
      intervalType: intervalType,
      alarmSoundName: alarmSound.name,
    );

    await DatabaseService().createIntervalTimer(newTimer);
    Get.find<IntervalTimerController>().refreshTimers();
    Get.snackbar(
      'Created $name',
      'Interval alarms active from ${DateFormat('h:mm a').format(startTime)} to ${DateFormat('h:mm a').format(endTime)}',
      snackPosition: SnackPosition.BOTTOM,
    );
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
                          'Periodic Check-ins & Repeated Alarms',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 1-Click Quick Presets for Workplace & Activity
              Text('Quick Check-in Presets', style: textTheme.titleSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPresetCard(
                      title: '💼 1-Hr Boss Check-in',
                      subtitle: 'Every 1 hr (8 hrs)',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                      onTap: () => _addWorkplacePreset(
                        name: 'Hourly Boss Check-in',
                        intervalValue: 1,
                        intervalType: IntervalType.hour,
                        durationHours: 8,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildPresetCard(
                      title: '💼 2-Hr Progress Report',
                      subtitle: 'Every 2 hrs (8 hrs)',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                      onTap: () => _addWorkplacePreset(
                        name: 'Bi-Hourly Status Report',
                        intervalValue: 2,
                        intervalType: IntervalType.hour,
                        durationHours: 8,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildPresetCard(
                      title: '💧 30-Min Hydration',
                      subtitle: 'Every 30 mins (6 hrs)',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                      onTap: () => _addWorkplacePreset(
                        name: 'Stand & Hydrate Ping',
                        intervalValue: 30,
                        intervalType: IntervalType.minute,
                        durationHours: 6,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildPresetCard(
                      title: '⚡ 15-Min Drills Ping',
                      subtitle: 'Every 15 mins (2 hrs)',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                      onTap: () => _addWorkplacePreset(
                        name: '15-Min Sprint Drills',
                        intervalValue: 15,
                        intervalType: IntervalType.minute,
                        durationHours: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Interval Timers',
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
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No interval timers yet',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap a quick preset above or press + to create one',
                            style: textTheme.bodySmall,
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
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final timer = controller.intervalTimers[index];
                    final timeFormat = DateFormat('h:mm a');

                    return Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                        border: Border.all(color: colorScheme.outlineVariant),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    timer.name,
                                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                                    const SizedBox(width: 16),
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
                            const SizedBox(height: 14),
                            
                            // Badges row
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
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
                                    color: colorScheme.secondary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.repeat, size: 14, color: colorScheme.secondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        timer.intervalString,
                                        style: TextStyle(fontSize: 12, color: colorScheme.secondary, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.notifications_active, size: 14, color: colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${timer.totalAlarms} alarms',
                                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            
                            // Open button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () => _startIntervalTimer(timer),
                                icon: const Icon(Icons.play_arrow, size: 18),
                                label: const Text('Start Periodic Session'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'interval_timer_list_fab',
        onPressed: _addNewIntervalTimer,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('New Interval', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPresetCard({
    required String title,
    required String subtitle,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
