import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/timer_list_controller.dart';
import '../models/interval_phase.dart';
import '../theme/app_theme.dart';

class TimerListScreen extends StatelessWidget {
  const TimerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(TimerListController());
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Get.back(),
        ),
        title: Obx(() => Text(controller.sequence.value.name.isEmpty ? 'Activity Detail' : controller.sequence.value.name)),
        actions: [
          Obx(() => IconButton(
            icon: Icon(
              controller.sequence.value.defaultLoopEnabled ? Icons.repeat_on : Icons.repeat,
              color: controller.sequence.value.defaultLoopEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            tooltip: controller.sequence.value.defaultLoopEnabled ? 'Disable Loop' : 'Enable Loop',
            onPressed: () {
              controller.toggleDefaultLoop();
            },
          )),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Activity Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                        border: Border.all(color: colorScheme.outlineVariant),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
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
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.timer, color: colorScheme.primary, size: 14),
                                        const SizedBox(width: 6),
                                        Obx(() => Text(
                                          controller.sequence.value.category.toUpperCase(),
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        )),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Prep countdown picker
                              PopupMenuButton<int>(
                                initialValue: controller.sequence.value.preparationSeconds,
                                onSelected: controller.updatePreparationSeconds,
                                tooltip: 'Lead-in Countdown',
                                child: Obx(() => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.hourglass_top, size: 12, color: colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Prep: ${controller.sequence.value.preparationSeconds}s',
                                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )),
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 0, child: Text('No Prep (0s)')),
                                  PopupMenuItem(value: 3, child: Text('3s Lead-in')),
                                  PopupMenuItem(value: 5, child: Text('5s Lead-in (Default)')),
                                  PopupMenuItem(value: 10, child: Text('10s Lead-in')),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Duration', style: textTheme.bodySmall),
                                    const SizedBox(height: 4),
                                    Obx(() => Text(
                                      controller.formatDuration(controller.sequence.value.totalDuration),
                                      style: textTheme.titleLarge,
                                    )),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 40, color: colorScheme.outlineVariant),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Intervals', style: textTheme.bodySmall),
                                    const SizedBox(height: 4),
                                    Obx(() => Text(
                                      '${controller.sequence.value.timers.length}',
                                      style: textTheme.titleLarge,
                                    )),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Individual Timers Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Intervals & Steps',
                          style: textTheme.titleLarge,
                        ),
                        Obx(() => Text(
                          '${controller.sequence.value.timers.length} items',
                          style: textTheme.bodyMedium,
                        )),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Timer List
                    Obx(() {
                      if (controller.sequence.value.timers.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.timer_off_outlined,
                                  size: 64,
                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
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
                          if (index < 0 || index >= controller.sequence.value.timers.length) {
                            return const SizedBox.shrink(key: ValueKey('empty'));
                          }

                          final timer = controller.sequence.value.timers[index];
                          final durationText = controller.formatDuration(timer.durationInSeconds);
                          final phaseColor = timer.phase.defaultColor;

                          return Container(
                            key: ValueKey(timer.id),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colorScheme.outlineVariant),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Left Phase Icon Badge
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: phaseColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(timer.phase.icon, color: phaseColor, size: 20),
                                ),
                                const SizedBox(width: 14),
                                
                                // Middle Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              timer.name,
                                              style: textTheme.titleSmall,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: phaseColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              timer.phase.displayName.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: phaseColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$durationText${timer.description != null && timer.description!.isNotEmpty ? ' • ${timer.description}' : ''}',
                                        style: textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Right Actions
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit, color: colorScheme.onSurfaceVariant, size: 20),
                                      onPressed: () => controller.editTimer(index),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: colorScheme.onSurfaceVariant, size: 20),
                                      onPressed: () async {
                                        final confirm = await Get.dialog<bool>(
                                          AlertDialog(
                                            title: const Text('Delete Timer'),
                                            content: Text('Are you sure you want to delete "${timer.name}"?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Get.back(result: false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Get.back(result: true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          controller.deleteTimer(index);
                                        }
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.drag_handle, color: colorScheme.outlineVariant, size: 20),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),

                    // Quick Add Phase Chips
                    const SizedBox(height: 12),
                    Text('Quick Add Phase', style: textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => controller.addTimer(phase: IntervalPhase.work),
                            icon: Icon(Icons.fitness_center, size: 14, color: IntervalPhase.work.defaultColor),
                            label: const Text('+ Work', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => controller.addTimer(phase: IntervalPhase.rest),
                            icon: Icon(Icons.bedtime_outlined, size: 14, color: IntervalPhase.rest.defaultColor),
                            label: const Text('+ Rest', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => controller.addTimer(phase: IntervalPhase.cooldown),
                            icon: Icon(Icons.ac_unit, size: 14, color: IntervalPhase.cooldown.defaultColor),
                            label: const Text('+ Cool', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: controller.startTimerSequence,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow, size: 24, color: colorScheme.onPrimary),
                      const SizedBox(width: 8),
                      Text(
                        'Start Activity',
                        style: textTheme.titleSmall?.copyWith(color: colorScheme.onPrimary),
                      ),
                    ],
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
