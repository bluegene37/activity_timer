import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/timer_list_controller.dart';
import '../components/for_ui_card.dart';
import '../components/for_ui_button.dart';
import '../theme/for_ui.dart';

class TimerListScreen extends StatelessWidget {
  const TimerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(TimerListController());
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.sequence.value.name)),
        centerTitle: true,
        actions: [
          Obx(() => IconButton(
            icon: Icon(
              controller.sequence.value.defaultLoopEnabled 
                  ? Icons.repeat_on 
                  : Icons.repeat,
              color: controller.sequence.value.defaultLoopEnabled
                  ? theme.colorScheme.primary
                  : null,
            ),
            onPressed: controller.toggleDefaultLoop,
            tooltip: controller.sequence.value.defaultLoopEnabled
                ? 'Disable loop by default'
                : 'Enable loop by default',
          )),
        ],
      ),
      body: Column(
        children: [
          // Activity summary
          Padding(
            padding: const EdgeInsets.all(ForUI.spacing),
            child: Obx(() => ForUICard(
              padding: const EdgeInsets.all(ForUI.spacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity Summary',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: ForUI.spacingSmall),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${controller.sequence.value.timers.length} timers',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              controller.formatTotalDuration(controller.sequence.value.totalDuration),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (controller.sequence.value.defaultLoopEnabled) ...[
                    const SizedBox(height: ForUI.spacingSmall),
                    ForUI.badge(
                      text: 'Loop Mode Enabled',
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      textColor: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            )),
          ),
          
          // Timer list
          Expanded(
            child: Obx(() {
              if (controller.sequence.value.timers.isEmpty) {
                return ForUI.emptyState(
                  title: 'No Timers Yet',
                  message: 'Add timers to create your activity sequence.',
                  buttonText: 'Add Timer',
                  onButtonPressed: controller.addTimer,
                  icon: Icons.timer_outlined,
                );
              }
              
              return ReorderableListView.builder(
                itemCount: controller.sequence.value.timers.length,
                padding: const EdgeInsets.symmetric(horizontal: ForUI.spacing),
                onReorder: controller.reorderTimers,
                itemBuilder: (context, index) {
                  final timer = controller.sequence.value.timers[index];
                  return ForUICard(
                    key: Key(timer.id),
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      title: Text(timer.name),
                      subtitle: Text(
                        '${controller.formatDuration(timer.durationInSeconds)}${timer.description != null ? ' • ${timer.description}' : ''}'
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => controller.editTimer(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => controller.deleteTimer(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
          
          // Bottom buttons
          Padding(
            padding: const EdgeInsets.all(ForUI.spacing),
            child: Row(
              children: [
                Expanded(
                  child: ForUIButton(
                    text: 'Add Timer',
                    icon: Icons.add,
                    onPressed: controller.addTimer,
                    isPrimary: false,
                  ),
                ),
                const SizedBox(width: ForUI.spacing),
                Expanded(
                  child: ForUIButton(
                    text: 'START ACTIVITY',
                    icon: Icons.play_arrow,
                    onPressed: controller.startTimerSequence,
                    isPrimary: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
