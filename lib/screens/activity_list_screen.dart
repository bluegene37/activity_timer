import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/activity_list_controller.dart';
import '../models/activity_timer.dart';
import '../routes/app_routes.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

/// Actions offered in a routine card's overflow menu.
enum _RoutineAction {
  edit('Edit Name', CupertinoIcons.pencil),
  duplicate('Duplicate Routine', CupertinoIcons.doc_on_doc),
  share('Copy JSON to Share', CupertinoIcons.share),
  delete('Delete', CupertinoIcons.trash, isDestructive: true);

  const _RoutineAction(this.label, this.icon, {this.isDestructive = false});

  final String label;
  final IconData icon;
  final bool isDestructive;
}

class ActivityListScreen extends StatelessWidget {
  const ActivityListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ActivityListController());
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
              // iOS Large Header
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
                      CupertinoIcons.flame_fill,
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
                          'Activity Timer',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'For Athletes & Focused Workers',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      CupertinoIcons.square_arrow_down,
                      color: colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    onPressed: () => _showImportDialog(context, controller),
                    tooltip: 'Import Routine JSON',
                  ),
                  IconButton(
                    icon: Icon(
                      CupertinoIcons.chart_bar_alt_fill,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                    onPressed: () => _showStatsBottomSheet(context, controller),
                    tooltip: 'Session History & Stats',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // iOS Styled Search Bar
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
                  onChanged: controller.setSearchQuery,
                  style: TextStyle(fontSize: 15, color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search routines...',
                    hintStyle: TextStyle(
                      fontSize: 15,
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
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Category Filter Bar (iOS Pill Tabs)
              Obx(
                () => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip(
                        label: 'All Routines',
                        icon: CupertinoIcons.square_grid_2x2,
                        value: 'all',
                        selected: controller.selectedCategory.value == 'all',
                        onTap: () => controller.setCategory('all'),
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(width: 8),
                      _buildCategoryChip(
                        label: '⚡ Fitness & Sports',
                        icon: CupertinoIcons.bolt_fill,
                        value: 'fitness',
                        selected:
                            controller.selectedCategory.value == 'fitness',
                        onTap: () => controller.setCategory('fitness'),
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(width: 8),
                      _buildCategoryChip(
                        label: '💼 Work & Focus',
                        icon: CupertinoIcons.briefcase_fill,
                        value: 'work',
                        selected: controller.selectedCategory.value == 'work',
                        onTap: () => controller.setCategory('work'),
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Routines Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Your Routines',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed:
                        () => _showPresetsBottomSheet(context, controller),
                    icon: Icon(
                      CupertinoIcons.sparkles,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    label: Text(
                      'Explore Presets',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Activity List (iOS Inset Grouped style)
              Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CupertinoActivityIndicator(radius: 14),
                    ),
                  );
                }

                final list = controller.filteredSequences;

                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.timer,
                            size: 56,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(height: 14),
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
                            onPressed:
                                () => _showPresetsBottomSheet(
                                  context,
                                  controller,
                                ),
                            icon: const Icon(CupertinoIcons.sparkles, size: 18),
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
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final sequence = list[index];
                    final originalIndex = controller.sequences.indexOf(
                      sequence,
                    );
                    final totalDuration = controller.formatTotalDuration(
                      sequence.totalDuration,
                    );
                    final isFitness = sequence.category == 'fitness';
                    final isWork = sequence.category == 'work';

                    final categoryColor =
                        isFitness
                            ? AppTheme.iosOrange
                            : isWork
                            ? AppTheme.iosBlue
                            : colorScheme.primary;

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
                            // Card Top: Name + Category badge + Menu
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          sequence.name,
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.2,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildSmallCategoryBadge(switch (sequence
                                          .category
                                          .toLowerCase()) {
                                        'fitness' => 'FITNESS',
                                        'work' => 'WORK',
                                        _ => 'CUSTOM',
                                      }, categoryColor),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<_RoutineAction>(
                                  icon: Icon(
                                    CupertinoIcons.ellipsis,
                                    size: 18,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  onSelected: (action) {
                                    switch (action) {
                                      case _RoutineAction.edit:
                                        _showEditDialog(
                                          context,
                                          controller,
                                          originalIndex,
                                        );
                                      case _RoutineAction.duplicate:
                                        controller.duplicateSequence(
                                          originalIndex,
                                        );
                                      case _RoutineAction.share:
                                        controller.exportSequenceToClipboard(
                                          sequence,
                                        );
                                      case _RoutineAction.delete:
                                        _showDeleteDialog(
                                          context,
                                          controller,
                                          originalIndex,
                                          sequence.name,
                                        );
                                    }
                                  },
                                  itemBuilder:
                                      (context) => [
                                        for (final action
                                            in _RoutineAction.values)
                                          PopupMenuItem(
                                            value: action,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  action.icon,
                                                  size: 18,
                                                  color:
                                                      action.isDestructive
                                                          ? Colors.red
                                                          : null,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  action.label,
                                                  style:
                                                      action.isDestructive
                                                          ? const TextStyle(
                                                            color: Colors.red,
                                                          )
                                                          : null,
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                ),
                              ],
                            ),

                            if (sequence.description != null &&
                                sequence.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                sequence.description!,
                                style: textTheme.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Meta Info Row
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.stopwatch,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  totalDuration,
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text('•', style: textTheme.bodySmall),
                                const SizedBox(width: 10),
                                Icon(
                                  CupertinoIcons.list_number,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${sequence.timers.length} steps',
                                  style: textTheme.bodySmall,
                                ),
                                if (sequence.defaultLoopEnabled) ...[
                                  const SizedBox(width: 10),
                                  Text('•', style: textTheme.bodySmall),
                                  const SizedBox(width: 10),
                                  Icon(
                                    CupertinoIcons.repeat,
                                    size: 14,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Loop',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Open & Start Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        () => Get.toNamed<void>(
                                          Routes.timerList,
                                          arguments: sequence,
                                        ),
                                    icon: const Icon(
                                      CupertinoIcons.slider_horizontal_3,
                                      size: 15,
                                    ),
                                    label: const Text('Customize'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      unawaited(
                                        HapticFeedback.selectionClick(),
                                      );
                                      if (sequence.timers.isEmpty) {
                                        Get.toNamed<void>(
                                          Routes.timerList,
                                          arguments: sequence,
                                        );
                                      } else {
                                        Get.toNamed<void>(
                                          Routes.timer,
                                          arguments: sequence,
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      CupertinoIcons.play_fill,
                                      size: 15,
                                    ),
                                    label: const Text('Start'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
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
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 50.0),
        child: FloatingActionButton.extended(
          heroTag: 'activity_list_fab',
          onPressed: () {
            HapticFeedback.selectionClick();
            controller.addNewSequence();
          },
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(CupertinoIcons.plus, size: 18),
          label: const Text(
            'New Routine',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
          ),
        ),
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
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : colorScheme.onSurface,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallCategoryBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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

  void _showImportDialog(
    BuildContext context,
    ActivityListController controller,
  ) {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text('Import Routine JSON'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste a timer routine JSON string below to import it:',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: '{\n  "name": "My Shared Workout",\n  ...\n}',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

  void _showPresetsBottomSheet(
    BuildContext context,
    ActivityListController controller,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final db = DatabaseService();
    final allPresets = db.getPresetTemplates();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            maxChildSize: 0.95,
            builder:
                (context, scrollController) => DefaultTabController(
                  length: 3,
                  child: Padding(
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
                            Text(
                              'Preset Library',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                CupertinoIcons.xmark_circle_fill,
                                size: 22,
                              ),
                              color: colorScheme.onSurfaceVariant,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        Text(
                          '1-Click add tested templates for athletes and productivity.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
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
                        const SizedBox(height: 14),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildPresetList(
                                allPresets,
                                controller,
                                context,
                                scrollController,
                              ),
                              _buildPresetList(
                                allPresets
                                    .where((p) => p.category == 'fitness')
                                    .toList(),
                                controller,
                                context,
                                scrollController,
                              ),
                              _buildPresetList(
                                allPresets
                                    .where((p) => p.category == 'work')
                                    .toList(),
                                controller,
                                context,
                                scrollController,
                              ),
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
    final isDark = theme.brightness == Brightness.dark;

    return ListView.builder(
      controller: scrollController,
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final preset = presets[index];
        final isFitness = preset.category == 'fitness';
        final badgeColor = isFitness ? AppTheme.iosOrange : AppTheme.iosBlue;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground(isDark: isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.separator(isDark: isDark),
              width: 0.8,
            ),
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
                  isFitness
                      ? CupertinoIcons.bolt_fill
                      : CupertinoIcons.briefcase_fill,
                  color: badgeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (preset.description != null)
                      Text(
                        preset.description!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 3),
                    Text(
                      '${preset.timers.length} intervals • ${controller.formatTotalDuration(preset.totalDuration)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  controller.addPresetTemplate(preset);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(60, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStatsBottomSheet(
    BuildContext context,
    ActivityListController controller,
  ) {
    controller.loadSessionHistory();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM d, h:mm a');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Obx(() {
            final historyList = controller.sessionHistory;
            final int totalSeconds = historyList.fold(
              0,
              (sum, s) => sum + s.totalDurationInSeconds,
            );
            final formattedTotalTime = controller.formatTotalDuration(
              totalSeconds,
            );

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
              builder:
                  (context, scrollController) => Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: ListView(
                      controller: scrollController,
                      children: [
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
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Activity Stats & History',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                CupertinoIcons.xmark_circle_fill,
                                size: 22,
                              ),
                              color: colorScheme.onSurfaceVariant,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBackground(
                                    isDark: isDark,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.cardRadius,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.separator(isDark: isDark),
                                    width: 0.8,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Completed',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${historyList.length}',
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    Text(
                                      'Sessions',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBackground(
                                    isDark: isDark,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.cardRadius,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.separator(isDark: isDark),
                                    width: 0.8,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Total Time',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formattedTotalTime,
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    Text(
                                      'Active Logged',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Category Time Breakdown (Apple Activity Style)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.iosOrange.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      '⚡ Fitness Time',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.iosOrange,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      controller.formatTotalDuration(
                                        fitnessSeconds,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.iosOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.iosBlue.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      '💼 Work Time',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.iosBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      controller.formatTotalDuration(
                                        workSeconds,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.iosBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        Text(
                          'Recent History',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
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
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBackground(isDark: isDark),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.separator(isDark: isDark),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    session.sessionType == 'interval'
                                        ? CupertinoIcons.stopwatch
                                        : CupertinoIcons
                                            .check_mark_circled_solid,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          session.title,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
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

  Future<void> _showEditDialog(
    BuildContext context,
    ActivityListController controller,
    int index,
  ) async {
    final sequence = controller.sequences[index];
    final nameController = TextEditingController(text: sequence.name);
    final descController = TextEditingController(
      text: sequence.description ?? '',
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final result = await Get.dialog<({String name, String description})>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                  fillColor: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back<({String name, String description})>,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back(
                result: (
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                ),
              );
            },
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    Future<void>.delayed(const Duration(seconds: 1), () {
      nameController.dispose();
      descController.dispose();
    });

    if (result case (name: final name, description: final description)) {
      unawaited(controller.editSequence(index, name, description));
    }
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    ActivityListController controller,
    int index,
    String name,
  ) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Activity'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back<bool>(result: true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      unawaited(controller.deleteSequence(index));
    }
  }
}
