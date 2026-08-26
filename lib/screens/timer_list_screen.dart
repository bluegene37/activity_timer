import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signals/signals_flutter.dart';

import '../controllers/timer_list_controller.dart';
import '../models/activity_timer.dart';
import '../models/interval_phase.dart';
import '../services/locator.dart';
import '../theme/app_theme.dart';

class TimerListScreen extends StatefulWidget {
  const TimerListScreen({super.key, this.sequence});

  /// The routine to show, handed over by the route.
  final TimerSequence? sequence;

  @override
  State<TimerListScreen> createState() => _TimerListScreenState();
}

class _TimerListScreenState extends State<TimerListScreen> {
  @override
  void initState() {
    super.initState();
    // Handing the routine to the controller writes a signal, so it must not
    // happen during build.
    final incoming = widget.sequence;
    if (incoming != null) {
      locator<TimerListController>().load(incoming);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = locator<TimerListController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.chevron_back,
            color: colorScheme.onSurface,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: SignalBuilder(
          builder:
              (_) => Text(
                controller.sequence.value.name.isEmpty
                    ? 'Activity Detail'
                    : controller.sequence.value.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
        ),
        actions: [
          SignalBuilder(
            builder:
                (_) => IconButton(
                  icon: Icon(
                    CupertinoIcons.repeat,
                    color:
                        controller.sequence.value.defaultLoopEnabled
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                    size: 20,
                  ),
                  tooltip:
                      controller.sequence.value.defaultLoopEnabled
                          ? 'Disable Loop'
                          : 'Enable Loop',
                  onPressed: () {
                    unawaited(HapticFeedback.selectionClick());
                    controller.toggleDefaultLoop();
                  },
                ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Activity Summary Card (iOS Inset Grouped)
                    Container(
                      padding: const EdgeInsets.all(18),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          CupertinoIcons.flame_fill,
                                          color: colorScheme.primary,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 5),
                                        SignalBuilder(
                                          builder:
                                              (_) => Text(
                                                controller
                                                    .sequence
                                                    .value
                                                    .category
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  color: colorScheme.primary,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Prep countdown picker
                              PopupMenuButton<int>(
                                initialValue:
                                    controller
                                        .sequence
                                        .value
                                        .preparationSeconds,
                                onSelected: (val) {
                                  HapticFeedback.selectionClick();
                                  controller.updatePreparationSeconds(val);
                                },
                                tooltip: 'Lead-in Countdown',
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: SignalBuilder(
                                  builder:
                                      (_) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              colorScheme
                                                  .surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.pillRadius,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              CupertinoIcons.hourglass,
                                              size: 12,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Prep: ${controller.sequence.value.preparationSeconds}s',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    colorScheme
                                                        .onSurfaceVariant,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                ),
                                itemBuilder:
                                    (context) => const [
                                      PopupMenuItem(
                                        value: 0,
                                        child: Text('No Prep (0s)'),
                                      ),
                                      PopupMenuItem(
                                        value: 3,
                                        child: Text('3s Lead-in'),
                                      ),
                                      PopupMenuItem(
                                        value: 5,
                                        child: Text('5s Lead-in (Default)'),
                                      ),
                                      PopupMenuItem(
                                        value: 10,
                                        child: Text('10s Lead-in'),
                                      ),
                                    ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Duration',
                                      style: textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 2),
                                    SignalBuilder(
                                      builder:
                                          (_) => Text(
                                            controller.formatDuration(
                                              controller
                                                  .sequence
                                                  .value
                                                  .totalDuration,
                                            ),
                                            style: textTheme.titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 0.8,
                                height: 36,
                                color: AppTheme.separator(isDark: isDark),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Intervals',
                                      style: textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 2),
                                    SignalBuilder(
                                      builder:
                                          (_) => Text(
                                            '${controller.sequence.value.timers.length}',
                                            style: textTheme.titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Individual Timers Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Intervals & Steps',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SignalBuilder(
                          builder:
                              (_) => Text(
                                '${controller.sequence.value.timers.length} items',
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Timer List
                    SignalBuilder(
                      builder: (_) {
                        if (controller.sequence.value.timers.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                children: [
                                  Icon(
                                    CupertinoIcons.timer,
                                    size: 56,
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'No intervals added yet',
                                    style: textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: controller.sequence.value.timers.length,
                          onReorderItem: controller.reorderTimers,
                          proxyDecorator: (child, index, animation) {
                            return Material(
                              color: Colors.transparent,
                              child: child,
                            );
                          },
                          itemBuilder: (context, index) {
                            if (index < 0 ||
                                index >=
                                    controller.sequence.value.timers.length) {
                              return const SizedBox.shrink(
                                key: ValueKey('empty'),
                              );
                            }

                            final timer =
                                controller.sequence.value.timers[index];
                            final durationText = controller.formatDuration(
                              timer.durationInSeconds,
                            );
                            final phaseColor = timer.phase.defaultColor;

                            return Container(
                              key: ValueKey(timer.id),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBackground(isDark: isDark),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.separator(isDark: isDark),
                                  width: 0.8,
                                ),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  // Left Phase Icon Badge
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: phaseColor.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      timer.phase.icon,
                                      color: phaseColor,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Middle Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                timer.name,
                                                style: textTheme.titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: phaseColor.withValues(
                                                  alpha: 0.15,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                timer.phase.displayName
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: phaseColor,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '$durationText${timer.description != null && timer.description!.isNotEmpty ? ' • ${timer.description}' : ''}',
                                          style: textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Right Actions
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          CupertinoIcons.pencil,
                                          color: colorScheme.onSurfaceVariant,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          controller.editTimer(index);
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: Icon(
                                          CupertinoIcons.trash,
                                          color: colorScheme.onSurfaceVariant,
                                          size: 18,
                                        ),
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
                                                    'Delete Timer',
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
                                              controller.deleteTimer(index),
                                            );
                                          }
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        CupertinoIcons.line_horizontal_3,
                                        color: colorScheme.outlineVariant,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // Quick Add Phase Chips
                    const SizedBox(height: 14),
                    Text(
                      'Quick Add Phase',
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              unawaited(HapticFeedback.selectionClick());
                              controller.addTimer(phase: IntervalPhase.work);
                            },
                            icon: Icon(
                              CupertinoIcons.bolt_fill,
                              size: 13,
                              color: AppTheme.iosOrange,
                            ),
                            label: const Text(
                              '+ Work',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              unawaited(HapticFeedback.selectionClick());
                              controller.addTimer(phase: IntervalPhase.rest);
                            },
                            icon: Icon(
                              CupertinoIcons.moon_fill,
                              size: 13,
                              color: AppTheme.iosBlue,
                            ),
                            label: const Text(
                              '+ Rest',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              unawaited(HapticFeedback.selectionClick());
                              controller.addTimer(
                                phase: IntervalPhase.cooldown,
                              );
                            },
                            icon: Icon(
                              CupertinoIcons.snow,
                              size: 13,
                              color: AppTheme.iosGreen,
                            ),
                            label: const Text(
                              '+ Cool',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground(isDark: isDark),
                border: Border(
                  top: BorderSide(
                    color: AppTheme.separator(isDark: isDark),
                    width: 0.8,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    unawaited(HapticFeedback.selectionClick());
                    controller.startTimerSequence();
                  },
                  icon: const Icon(
                    CupertinoIcons.play_fill,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Start Activity',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
