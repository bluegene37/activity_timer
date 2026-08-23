import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/activity_list_controller.dart';
import '../models/activity_timer.dart';
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
                          'For Athletes & Focused Workers',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.file_download_outlined, color: colorScheme.onSurfaceVariant),
                    onPressed: () => _showImportDialog(context, controller),
                    tooltip: 'Import Routine JSON',
                  ),
                  IconButton(
                    icon: Icon(Icons.bar_chart, color: colorScheme.primary),
                    onPressed: () => _showStatsBottomSheet(context, controller),
                    tooltip: 'Session History & Stats',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search Bar
              TextField(
                onChanged: controller.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Search routines...',
                  prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant, size: 20),
                  filled: true,
                  fillColor: colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category Filter Bar
              Obx(() => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip(
                      label: 'All Routines',
                      icon: Icons.apps,
                      value: 'all',
                      selected: controller.selectedCategory.value == 'all',
                      onTap: () => controller.setCategory('all'),
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      label: '⚡ Fitness & Sports',
                      icon: Icons.fitness_center,
                      value: 'fitness',
                      selected: controller.selectedCategory.value == 'fitness',
                      onTap: () => controller.setCategory('fitness'),
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      label: '💼 Work & Focus',
                      icon: Icons.work_outline,
                      value: 'work',
                      selected: controller.selectedCategory.value == 'work',
                      onTap: () => controller.setCategory('work'),
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 24),

              // Routines Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Your Routines',
                      style: textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showPresetsBottomSheet(context, controller),
                    icon: Icon(Icons.auto_awesome, size: 18, color: colorScheme.primary),
                    label: Text(
                      'Explore Presets',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Activity List
              Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = controller.filteredSequences;

                if (list.isEmpty) {
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
                            controller.sequences.isEmpty
                                ? 'No routines created yet'
                                : 'No routines match your filter',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showPresetsBottomSheet(context, controller),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Add from Preset Library'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final sequence = list[index];
                    final originalIndex = controller.sequences.indexOf(sequence);
                    final totalDuration = controller.formatTotalDuration(sequence.totalDuration);
                    final isFitness = sequence.category == 'fitness';
                    final isWork = sequence.category == 'work';

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
                            // Card Top: Name + Category badge + Menu
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          sequence.name,
                                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildSmallCategoryBadge(
                                        isFitness ? 'FITNESS' : isWork ? 'WORK' : 'CUSTOM',
                                        isFitness ? const Color(0xFFFF6D00) : isWork ? const Color(0xFF00B0FF) : colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, size: 20, color: colorScheme.onSurfaceVariant),
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'edit':
                                        _showEditDialog(context, controller, originalIndex);
                                        break;
                                      case 'duplicate':
                                        controller.duplicateSequence(originalIndex);
                                        break;
                                      case 'share':
                                        controller.exportSequenceToClipboard(sequence);
                                        break;
                                      case 'delete':
                                        _showDeleteDialog(context, controller, originalIndex, sequence.name);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 18),
                                          SizedBox(width: 8),
                                          Text('Edit Name'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'duplicate',
                                      child: Row(
                                        children: [
                                          Icon(Icons.copy, size: 18),
                                          SizedBox(width: 8),
                                          Text('Duplicate Routine'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'share',
                                      child: Row(
                                        children: [
                                          Icon(Icons.share, size: 18),
                                          SizedBox(width: 8),
                                          Text('Copy JSON to Share'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                            const SizedBox(height: 14),

                            // Meta Info Row
                            Row(
                              children: [
                                Icon(Icons.timer_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  totalDuration,
                                  style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 12),
                                Text('•', style: textTheme.bodySmall),
                                const SizedBox(width: 12),
                                Icon(Icons.format_list_numbered, size: 14, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  '${sequence.timers.length} steps',
                                  style: textTheme.bodySmall,
                                ),
                                if (sequence.defaultLoopEnabled) ...[
                                  const SizedBox(width: 12),
                                  Text('•', style: textTheme.bodySmall),
                                  const SizedBox(width: 12),
                                  Icon(Icons.loop, size: 14, color: colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Loop',
                                    style: textTheme.bodySmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Open & Start Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => Get.toNamed('/timer-list', arguments: sequence),
                                    icon: const Icon(Icons.tune, size: 16),
                                    label: const Text('Customize'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      if (sequence.timers.isEmpty) {
                                        Get.toNamed('/timer-list', arguments: sequence);
                                      } else {
                                        Get.toNamed('/timer', arguments: sequence);
                                      }
                                    },
                                    icon: const Icon(Icons.play_arrow, size: 18),
                                    label: const Text('Start'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
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
        heroTag: 'activity_list_fab',
        onPressed: () => controller.addNewSequence(),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('New Routine', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required IconData icon,
    required String value,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallCategoryBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showImportDialog(BuildContext context, ActivityListController controller) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Routine JSON'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste a timer routine JSON string below to import it:'),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '{\n  "name": "My Shared Workout",\n  ...\n}',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final jsonStr = textController.text.trim();
              if (jsonStr.isNotEmpty) {
                Navigator.pop(dialogContext);
                await controller.importSequenceFromJson(jsonStr);
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _showPresetsBottomSheet(BuildContext context, ActivityListController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final db = DatabaseService();
    final allPresets = db.getPresetTemplates();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, scrollController) => DefaultTabController(
          length: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Preset Library', style: theme.textTheme.titleLarge),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '1-Click add tested templates for athletes and productivity.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TabBar(
                  labelColor: colorScheme.primary,
                  indicatorColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: '⚡ Fitness'),
                    Tab(text: '💼 Work'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPresetList(allPresets, controller, context, scrollController),
                      _buildPresetList(allPresets.where((p) => p.category == 'fitness').toList(), controller, context, scrollController),
                      _buildPresetList(allPresets.where((p) => p.category == 'work').toList(), controller, context, scrollController),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetList(
    List<TimerSequence> presets,
    ActivityListController controller,
    BuildContext context,
    ScrollController scrollController,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView.builder(
      controller: scrollController,
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final preset = presets[index];
        final isFitness = preset.category == 'fitness';
        final badgeColor = isFitness ? const Color(0xFFFF6D00) : const Color(0xFF00B0FF);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFitness ? Icons.fitness_center : Icons.work_outline,
                  color: badgeColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preset.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    if (preset.description != null)
                      Text(
                        preset.description!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${preset.timers.length} intervals • ${controller.formatTotalDuration(preset.totalDuration)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  controller.addPresetTemplate(preset);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(64, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
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

        final fitnessSeconds = historyList
            .where((s) => s.category == 'fitness')
            .fold(0, (sum, s) => sum + s.totalDurationInSeconds);
        final workSeconds = historyList
            .where((s) => s.category == 'work')
            .fold(0, (sum, s) => sum + s.totalDurationInSeconds);

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
                            Text('Active Logged', style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Category Time Breakdown
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6D00).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text('⚡ Fitness Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF6D00))),
                            const SizedBox(height: 2),
                            Text(controller.formatTotalDuration(fitnessSeconds), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF6D00))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B0FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text('💼 Work Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00B0FF))),
                            const SizedBox(height: 2),
                            Text(controller.formatTotalDuration(workSeconds), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00B0FF))),
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
                        'No completed sessions logged yet.\nComplete a workout or work timer to see it here!',
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
                        border: Border.all(color: colorScheme.outlineVariant),
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
