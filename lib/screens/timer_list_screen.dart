import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/timer_list_controller.dart';
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
        title: const Text('Activity Detail'),
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
                            color: Colors.black.withOpacity(0.02),
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
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(Icons.timer, color: colorScheme.onPrimary, size: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ACTIVITY SUMMARY',
                                    style: textTheme.bodySmall?.copyWith(letterSpacing: 1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
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
                                    Text('Total Timers', style: textTheme.bodySmall),
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
                    const SizedBox(height: 32),

                    // Individual Timers Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Individual Timers',
                          style: textTheme.titleLarge,
                        ),
                        Obx(() => Text(
                          '${controller.sequence.value.timers.length} items',
                          style: textTheme.bodyMedium,
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),

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
                                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No timers added yet',
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
                        onReorder: controller.reorderTimers,
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

                          return Container(
                            key: ValueKey(timer.id),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Left Index Circle
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Middle Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        timer.name,
                                        style: textTheme.titleSmall,
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
                                    const SizedBox(width: 16),
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
                                    Icon(Icons.drag_handle, color: colorScheme.surfaceContainerHighest, size: 20),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),

                    // Quick add interval button
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: controller.addTimer,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.surfaceContainerHighest,
                            width: 1.5,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle, color: colorScheme.onSurfaceVariant, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Quick add interval',
                              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: controller.addTimer,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colorScheme.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Add Timer',
                        style: textTheme.titleSmall?.copyWith(color: colorScheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
