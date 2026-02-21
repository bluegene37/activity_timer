import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/activity_list_controller.dart';
import '../components/for_ui_card.dart';
import '../components/for_ui_button.dart';
import '../theme/for_ui.dart';

class ActivityListScreen extends StatelessWidget {
  const ActivityListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ActivityListController());
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Timer'), centerTitle: true),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.sequences.isEmpty) {
          return ForUI.emptyState(
            title: 'No Activities Yet',
            message:
                'Create your first activity to get started with timed sequences.',
            buttonText: 'Create Activity',
            onButtonPressed: controller.addNewSequence,
            icon: Icons.timer,
          );
        }

        return ListView.builder(
          itemCount: controller.sequences.length,
          padding: const EdgeInsets.all(ForUI.spacing),
          itemBuilder: (context, index) {
            final sequence = controller.sequences[index];
            final totalDuration = sequence.totalDuration;

            return ForUICard(
              onTap: () => Get.toNamed('/timer-list', arguments: sequence),
              padding: const EdgeInsets.all(ForUI.spacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Hero(
                          tag: 'sequence_name_${sequence.id}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Text(
                              sequence.name,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          sequence.defaultLoopEnabled
                              ? Icons.repeat_on
                              : Icons.repeat,
                          color:
                              sequence.defaultLoopEnabled
                                  ? theme.colorScheme.primary
                                  : null,
                          size: 20,
                        ),
                        onPressed: () => controller.toggleDefaultLoop(index),
                        tooltip:
                            sequence.defaultLoopEnabled
                                ? 'Disable loop by default'
                                : 'Enable loop by default',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed:
                            () => _showEditDialog(context, controller, index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed:
                            () => _showDeleteDialog(
                              context,
                              controller,
                              index,
                              sequence.name,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ForUI.spacingSmall),
                  Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${sequence.timers.length} timers',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        controller.formatTotalDuration(totalDuration),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  if (sequence.defaultLoopEnabled) ...[
                    const SizedBox(height: ForUI.spacingSmall),
                    ForUI.badge(
                      text: 'Loop Enabled',
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.1,
                      ),
                      textColor: theme.colorScheme.primary,
                    ),
                  ],
                  const SizedBox(height: ForUI.spacing),
                  ForUIButton(
                    text: 'START',
                    icon: Icons.play_arrow,
                    onPressed:
                        () => Get.toNamed('/timer-list', arguments: sequence),
                    isFullWidth: true,
                  ),
                ],
              ),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        heroTag: 'activity_list_fab',
        onPressed: () => Get.find<ActivityListController>().addNewSequence(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    ActivityListController controller,
    int index,
  ) {
    final textController = TextEditingController(
      text: controller.sequences[index].name,
    );

    Get.dialog(
      AlertDialog(
        title: const Text('Edit Activity Name'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(labelText: 'Activity Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              controller.editSequenceName(index, textController.text);
              Get.back();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    ActivityListController controller,
    int index,
    String name,
  ) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Activity'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              controller.deleteSequence(index);
              Get.back();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
