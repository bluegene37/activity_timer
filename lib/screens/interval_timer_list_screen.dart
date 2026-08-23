import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/interval_timer_controller.dart';
import '../models/alarm_sound.dart';
import '../models/interval_timer.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class IntervalTimerListScreen extends StatelessWidget {
  const IntervalTimerListScreen({super.key});

  Future<void> _addNewIntervalTimer() async {
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, now.hour, 0);
    final endTime = startTime.add(const Duration(hours: 8));

    final result = await Get.toNamed<dynamic>(
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
      unawaited(Get.find<IntervalTimerController>().refreshTimers());
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
    unawaited(Get.find<IntervalTimerController>().refreshTimers());
    Get.snackbar(
      'Created $name',
      'Interval alarms active from ${DateFormat('h:mm a').format(startTime)} to ${DateFormat('h:mm a').format(endTime)}',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _editIntervalTimer(IntervalTimer timer) async {
    final result = await Get.toNamed<dynamic>(
      '/edit-interval-timer',
      arguments: {'timer': timer, 'isNew': false},
    );

    if (result == true) {
      unawaited(Get.find<IntervalTimerController>().refreshTimers());
    }
  }

  void _startIntervalTimer(IntervalTimer timer) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(Get.toNamed<dynamic>('/interval-timer', arguments: timer));
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<IntervalTimerController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12.0, bottom: 100.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.stopwatch_fill,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Interval Timers',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Periodic Check-ins & Repeated Alarms',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // 1-Click Quick Presets for Workplace & Activity
              Text(
                'Quick Check-in Presets',
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
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
                      isDark: isDark,
                      onTap: () => _addWorkplacePreset(
                        name: 'Hourly Boss Check-in',
                        intervalValue: 1,
                        intervalType: IntervalType.hour,
                        durationHours: 8,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildPresetCard(
                      title: '💼 2-Hr Progress Report',
                      subtitle: 'Every 2 hrs (8 hrs)',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                      isDark: isDark,
                      onTap: () => _addWorkplacePreset(
                        name: 'Bi-Hourly Status Report',
                        intervalValue: 2,
                        intervalType: IntervalType.hour,
                        durationHours: 8,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildPresetCard(
                      title: '💧 30-Min Hydration',
                      subtitle: 'Every 30 mins (6 hrs)',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                      isDark: isDark,
                      onTap: () => _addWorkplacePreset(
                        name: 'Stand & Hydrate Ping',
                        intervalValue: 30,
                        intervalType: IntervalType.minute,
                        durationHours: 6,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildPresetCard(
                      title: '⚡ 15-Min Drills Ping',
                      subtitle: 'Every 15 mins (2 hrs)',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                      isDark: isDark,
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
              const SizedBox(height: 24),
              
              Text(
                'Your Interval Timers',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),

              Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CupertinoActivityIndicator(radius: 14),
                    ),
                  );
                }

                if (controller.intervalTimers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.clock,
                            size: 56,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No interval timers yet',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final timer = controller.intervalTimers[index];
                    final timeFormat = DateFormat('h:mm a');

                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                        border: Border.all(
                          color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
                          width: 0.8,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    timer.name,
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(CupertinoIcons.pencil, size: 18, color: colorScheme.onSurfaceVariant),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _editIntervalTimer(timer),
                                    ),
                                    const SizedBox(width: 14),
                                    IconButton(
                                      icon: Icon(CupertinoIcons.trash, size: 18, color: colorScheme.onSurfaceVariant),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      onPressed: () async {
                                        final confirm = await Get.dialog<bool>(
                                          AlertDialog(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                            title: const Text('Delete Interval Timer'),
                                            content: Text('Are you sure you want to delete "${timer.name}"?'),
                                            actions: [
                                              TextButton(onPressed: () => Get.back<bool>(result: false), child: const Text('Cancel')),
                                              TextButton(
                                                onPressed: () => Get.back<bool>(result: true),
                                                child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          unawaited(controller.deleteIntervalTimer(timer.id));
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Badges row
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.clock, size: 13, color: colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${timeFormat.format(timer.startTime)} - ${timeFormat.format(timer.endTime)}',
                                        style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.iosBlue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.repeat, size: 13, color: AppTheme.iosBlue),
                                      const SizedBox(width: 4),
                                      Text(
                                        timer.intervalString,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.iosBlue, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.bell_fill, size: 13, color: colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${timer.totalAlarms} alarms',
                                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Open button
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: () => _startIntervalTimer(timer),
                                icon: const Icon(CupertinoIcons.play_fill, size: 16),
                                label: const Text('Start Periodic Session'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
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
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 50.0),
        child: FloatingActionButton.extended(
          heroTag: 'interval_timer_list_fab',
          onPressed: () {
            HapticFeedback.selectionClick();
            _addNewIntervalTimer();
          },
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(CupertinoIcons.plus, size: 18),
          label: const Text('New Interval', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2)),
        ),
      ),
    );
  }

  Widget _buildPresetCard({
    required String title,
    required String subtitle,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
