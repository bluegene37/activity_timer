import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:signals/signals_flutter.dart';

import '../controllers/interval_timer_controller.dart';
import '../models/alarm_sound.dart';
import '../models/interval_timer.dart';
import '../routes/app_pages.dart';
import '../routes/app_routes.dart';
import '../services/database_service.dart';
import '../services/locator.dart';
import '../services/ui_messenger.dart';
import '../theme/app_theme.dart';

class IntervalTimerListScreen extends StatelessWidget {
  const IntervalTimerListScreen({super.key});

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
    unawaited(locator<IntervalTimerController>().refreshTimers());
    UiMessenger().showMessage(
      'Interval alarms active from ${DateFormat('h:mm a').format(startTime)} '
      'to ${DateFormat('h:mm a').format(endTime)}',
      title: 'Created $name',
    );
  }

  Future<void> _editIntervalTimer(IntervalTimer timer) async {
    final result = await AppPages.push<dynamic>(
      Routes.editIntervalTimer,
      extra: (timer: timer, isNew: false),
    );

    if (result == true) {
      unawaited(locator<IntervalTimerController>().refreshTimers());
    }
  }

  void _startIntervalTimer(IntervalTimer timer) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(AppPages.push<void>(Routes.intervalTimer, extra: timer));
  }

  @override
  Widget build(BuildContext context) {
    final controller = locator<IntervalTimerController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 12.0,
            bottom: 100.0,
          ),
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

              // Your Interval Timers Section Header with Quick Presets Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Your Interval Timers',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    child: TextButton.icon(
                      onPressed: () => _showPresetsBottomSheet(context),
                      icon: Icon(
                        CupertinoIcons.sparkles,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      label: Text(
                        'Quick Presets',
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              SignalBuilder(
                builder: (_) {
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
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.4,
                              ),
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
                              'Choose a quick preset or tap + to create one',
                              style: textTheme.bodySmall,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showPresetsBottomSheet(context),
                              icon: const Icon(
                                CupertinoIcons.sparkles,
                                size: 18,
                              ),
                              label: const Text('Add from Presets'),
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
                    separatorBuilder:
                        (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final timer = controller.intervalTimers[index];
                      final timeFormat = DateFormat('h:mm a');

                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground(isDark: isDark),
                          borderRadius: BorderRadius.circular(
                            AppTheme.cardRadius,
                          ),
                          border: Border.all(
                            color: AppTheme.separator(isDark: isDark),
                            width: 0.8,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                        icon: Icon(
                                          CupertinoIcons.pencil,
                                          size: 18,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        onPressed:
                                            () => _editIntervalTimer(timer),
                                      ),
                                      const SizedBox(width: 14),
                                      IconButton(
                                        icon: Icon(
                                          CupertinoIcons.trash,
                                          size: 18,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        onPressed: () async {
                                          final confirm = await showDialog<
                                            bool
                                          >(
                                            context: context,
                                            builder:
                                                (dialogContext) => AlertDialog(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          18,
                                                        ),
                                                  ),
                                                  title: const Text(
                                                    'Delete Interval Timer',
                                                  ),
                                                  content: Text(
                                                    'Are you sure you want to delete "${timer.name}"?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            dialogContext,
                                                            false,
                                                          ),
                                                      child: const Text(
                                                        'Cancel',
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            dialogContext,
                                                            true,
                                                          ),
                                                      child: const Text(
                                                        'Delete',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          );
                                          if (confirm == true) {
                                            unawaited(
                                              controller.deleteIntervalTimer(
                                                timer.id,
                                              ),
                                            );
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.clock,
                                          size: 13,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${timeFormat.format(timer.startTime)} - ${timeFormat.format(timer.endTime)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.iosBlue.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.repeat,
                                          size: 13,
                                          color: AppTheme.iosBlue,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          timer.intervalString,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.iosBlue,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.bell_fill,
                                          size: 13,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${timer.totalAlarms} alarms',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          ),
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
                                  icon: const Icon(
                                    CupertinoIcons.play_fill,
                                    size: 16,
                                  ),
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
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPresetsBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredPresets =
                _presets.where((p) {
                  if (searchQuery.isEmpty) return true;
                  final q = searchQuery.toLowerCase();
                  return p.name.toLowerCase().contains(q) ||
                      p.description.toLowerCase().contains(q) ||
                      p.category.toLowerCase().contains(q) ||
                      '${p.intervalValue}'.contains(q);
                }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.92,
              minChildSize: 0.45,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // iOS modal drag bar
                      Center(
                        child: Container(
                          width: 36,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Interval Presets',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              CupertinoIcons.xmark_circle_fill,
                              size: 22,
                            ),
                            color: colorScheme.onSurfaceVariant,
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      Text(
                        '1-Click recurring interval alarms for work, focus, and health.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Search Bar
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground(isDark: isDark),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.separator(isDark: isDark),
                            width: 0.8,
                          ),
                        ),
                        child: TextField(
                          onChanged: (val) {
                            setSheetState(() {
                              searchQuery = val.trim();
                            });
                          },
                          style: TextStyle(
                            fontSize: 15,
                            color: colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Search presets (e.g. 1-hr, hydration, work)...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            prefixIcon: Icon(
                              CupertinoIcons.search,
                              color: colorScheme.onSurfaceVariant,
                              size: 18,
                            ),
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child:
                            filteredPresets.isEmpty
                                ? Center(
                                  child: Text(
                                    'No presets match "$searchQuery"',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  controller: scrollController,
                                  itemCount: filteredPresets.length,
                                  itemBuilder: (context, index) {
                                    final preset = filteredPresets[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cardBackground(
                                          isDark: isDark,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppTheme.separator(
                                            isDark: isDark,
                                          ),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              preset.icon,
                                              color: colorScheme.primary,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  preset.name,
                                                  style: textTheme.titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  preset.description,
                                                  style: textTheme.bodySmall,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  preset.intervalBadge,
                                                  style: textTheme.bodySmall
                                                      ?.copyWith(
                                                        color:
                                                            colorScheme.primary,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () {
                                              HapticFeedback.selectionClick();
                                              Navigator.pop(sheetContext);
                                              _addWorkplacePreset(
                                                name: preset.name,
                                                intervalValue:
                                                    preset.intervalValue,
                                                intervalType:
                                                    preset.intervalType,
                                                durationHours:
                                                    preset.durationHours,
                                                alarmSound: preset.alarmSound,
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text('Add'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  static const List<_IntervalPresetTemplate> _presets = [
    _IntervalPresetTemplate(
      name: 'Hourly Boss Check-in',
      description: 'Regular hourly check-ins during work hours',
      category: 'Work',
      intervalValue: 1,
      intervalType: IntervalType.hour,
      durationHours: 8,
      alarmSound: AlarmSound.bell,
      icon: CupertinoIcons.briefcase_fill,
    ),
    _IntervalPresetTemplate(
      name: 'Bi-Hourly Status Report',
      description: 'Progress report ping every 2 hours',
      category: 'Work',
      intervalValue: 2,
      intervalType: IntervalType.hour,
      durationHours: 8,
      alarmSound: AlarmSound.bell,
      icon: CupertinoIcons.chart_bar_alt_fill,
    ),
    _IntervalPresetTemplate(
      name: 'Stand & Hydrate Ping',
      description: 'Regular reminders to hydrate and stretch',
      category: 'Wellness',
      intervalValue: 30,
      intervalType: IntervalType.minute,
      durationHours: 6,
      alarmSound: AlarmSound.chime,
      icon: CupertinoIcons.drop_fill,
    ),
    _IntervalPresetTemplate(
      name: '15-Min Sprint Drills',
      description: 'Short high-intensity interval drills',
      category: 'Fitness',
      intervalValue: 15,
      intervalType: IntervalType.minute,
      durationHours: 2,
      alarmSound: AlarmSound.alert,
      icon: CupertinoIcons.bolt_fill,
    ),
    _IntervalPresetTemplate(
      name: 'Pomodoro Focus Interval',
      description: 'Focused work interval with scheduled alerts',
      category: 'Work',
      intervalValue: 25,
      intervalType: IntervalType.minute,
      durationHours: 4,
      alarmSound: AlarmSound.beep,
      icon: CupertinoIcons.timer,
    ),
    _IntervalPresetTemplate(
      name: '20-20-20 Eye Rest Ping',
      description: 'Look 20ft away for 20s to reduce digital eye strain',
      category: 'Wellness',
      intervalValue: 20,
      intervalType: IntervalType.minute,
      durationHours: 8,
      alarmSound: AlarmSound.chime,
      icon: CupertinoIcons.eye_fill,
    ),
  ];
}

class _IntervalPresetTemplate {
  const _IntervalPresetTemplate({
    required this.name,
    required this.description,
    required this.category,
    required this.intervalValue,
    required this.intervalType,
    required this.durationHours,
    this.alarmSound = AlarmSound.bell,
    required this.icon,
  });

  final String name;
  final String description;
  final String category;
  final int intervalValue;
  final IntervalType intervalType;
  final int durationHours;
  final AlarmSound alarmSound;
  final IconData icon;

  String get intervalBadge {
    final unit =
        intervalValue == 1 ? intervalType.name : '${intervalType.name}s';
    return 'Every $intervalValue $unit • ${durationHours}h duration';
  }
}
