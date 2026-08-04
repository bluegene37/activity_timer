import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/activity_list_controller.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class ActivityListScreen extends StatelessWidget {
  const ActivityListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ActivityListController());
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
                      Icons.timer,
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
                          'Activity Timer',
                          style: textTheme.headlineSmall,
                        ),
                        Text(
                          'Ready for your Activity?',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.bar_chart, color: colorScheme.primary),
                    onPressed: () => _showStatsBottomSheet(context, controller),
                    tooltip: 'Session History & Stats',
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Your Routine Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Routines',
                    style: textTheme.titleLarge,
                  ),
                  TextButton.icon(
                    onPressed: () => _showPresetsBottomSheet(context, controller),
                    icon: Icon(Icons.dashboard_outlined, size: 18, color: colorScheme.primary),
                    label: Text(
                      'Presets',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Activity List
              Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.sequences.isEmpty) {
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
                            'No routines yet',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showPresetsBottomSheet(context, controller),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Explore Presets'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.sequences.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 24),
                  itemBuilder: (context, index) {
                    final sequence = controller.sequences[index];
                    final totalDuration = controller.formatTotalDuration(sequence.totalDuration);

                    return Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Content area
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        sequence.name,
                                        style: textTheme.titleMedium,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit, size: 20, color: colorScheme.onSurfaceVariant),
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                          onPressed: () => _showEditDialog(context, controller, index),
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: Icon(Icons.delete, size: 20, color: colorScheme.onSurfaceVariant),
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                          onPressed: () => _showDeleteDialog(context, controller, index, sequence.name),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                
                                if (sequence.description != null && sequence.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    sequence.description!,
                                    style: textTheme.bodyMedium,
                                  ),
                                ],
                                
                                const SizedBox(height: 16),
                                
                                Row(
                                  children: [
                                    Icon(Icons.timer_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(
                                      totalDuration,
                                      style: textTheme.bodyMedium,
                                    ),
                                    const SizedBox(width: 12),
                                    Text('•', style: textTheme.bodyMedium),
                                    const SizedBox(width: 12),
                                    Icon(Icons.list, size: 14, color: colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${sequence.timers.length} items',
                                      style: textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                
                                // Open button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: () => Get.toNamed('/timer-list', arguments: sequence),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
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
                                          'Open Routine',
                                          style: textTheme.titleSmall?.copyWith(color: colorScheme.primary),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(Icons.arrow_forward, size: 18, color: colorScheme.primary),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
        heroTag: 'activity_list_fab',
        onPressed: () => controller.addNewSequence(),
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  void _showPresetsBottomSheet(BuildContext context, ActivityListController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final presets = DatabaseService().getPresetTemplates();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Preset Routine Library', style: theme.textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '1-Click add pre-built activity sequences for work, fitness, and relaxation.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              ...presets.map(
                (preset) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.auto_awesome, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(preset.name, style: theme.textTheme.titleSmall),
                            if (preset.description != null)
                              Text(preset.description!, style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 4),
                            Text(
                              '${preset.timers.length} steps • ${controller.formatTotalDuration(preset.totalDuration)}',
                              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          controller.addPresetTemplate(preset);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(80, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatsBottomSheet(BuildContext context, ActivityListController controller) {
    controller.loadSessionHistory();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MMM d, h:mm a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Obx(() {
        final historyList = controller.sessionHistory;
        int totalSeconds = historyList.fold(0, (sum, s) => sum + s.totalDurationInSeconds);
        final formattedTotalTime = controller.formatTotalDuration(totalSeconds);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: ListView(
              controller: scrollController,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Activity Stats & History', style: theme.textTheme.titleLarge),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            Text('Completed', style: theme.textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text(
                              '${historyList.length}',
                              style: theme.textTheme.headlineMedium?.copyWith(color: colorScheme.primary),
                            ),
                            Text('Sessions', style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            Text('Total Time', style: theme.textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text(
                              formattedTotalTime,
                              style: theme.textTheme.headlineMedium?.copyWith(color: colorScheme.primary),
                            ),
                            Text('Active', style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Recent History', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                if (historyList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No completed sessions logged yet.\nComplete an activity or interval timer to see it here!',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  ...historyList.map(
                    (session) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            session.sessionType == 'interval' ? Icons.schedule : Icons.task_alt,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(session.title, style: theme.textTheme.titleSmall),
                                Text(
                                  '${controller.formatTotalDuration(session.totalDurationInSeconds)} • ${dateFormat.format(session.completedAt)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showEditDialog(BuildContext context, ActivityListController controller, int index) async {
    final sequence = controller.sequences[index];
    final nameController = TextEditingController(text: sequence.name);
    final descController = TextEditingController(text: sequence.description ?? '');

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final result = await Get.dialog<Map<String, String>>(
      AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Activity'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Activity Name',
                  filled: true,
                  fillColor: colorScheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  filled: true,
                  fillColor: colorScheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back(result: {
                'name': nameController.text.trim(),
                'description': descController.text.trim(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // Completely defer destruction until well after navigation has settled.
    Future.delayed(const Duration(seconds: 1), () {
      nameController.dispose();
      descController.dispose();
    });

    if (result != null && result['name'] != null) {
      controller.editSequence(index, result['name']!, result['description']!);
    }
  }

  void _showDeleteDialog(BuildContext context, ActivityListController controller, int index, String name) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Activity'),
        content: Text('Are you sure you want to delete "$name"?'),
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
      controller.deleteSequence(index);
    }
  }
}
