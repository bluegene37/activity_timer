import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signals/signals_flutter.dart';

import '../controllers/activity_list_controller.dart';
import '../controllers/activity_run_controller.dart';
import '../controllers/brew_controller.dart';
import '../controllers/brew_run_controller.dart';
import '../controllers/interval_run_controller.dart';
import '../controllers/interval_timer_controller.dart';
import '../routes/app_pages.dart';
import '../routes/app_routes.dart';
import '../screens/activity_list_screen.dart';
import '../screens/brew_list_screen.dart';
import '../screens/interval_timer_list_screen.dart';
import '../screens/settings_screen.dart';
import '../services/activity_session_service.dart';
import '../services/brew_session_service.dart';
import '../services/interval_session_service.dart';
import '../services/locator.dart';
import '../theme/app_theme.dart';
import '../theme/brew_theme.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ActivityListScreen(),
    const BrewListScreen(),
    const IntervalTimerListScreen(),
    const SettingsScreen(),
  ];

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentIndex = index;
      });
    }
  }

  Widget? _buildFloatingActionButton(ColorScheme colorScheme) {
    if (_currentIndex == 0) {
      return FloatingActionButton.extended(
        heroTag: 'activity_list_fab',
        onPressed: () {
          HapticFeedback.selectionClick();
          locator<ActivityListController>().addNewSequence();
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(CupertinoIcons.plus, size: 18),
        label: const Text(
          'New Routine',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
      );
    } else if (_currentIndex == 1) {
      return FloatingActionButton.extended(
        heroTag: 'brew_list_fab',
        onPressed: () {
          HapticFeedback.selectionClick();
          unawaited(locator<BrewController>().addNewBrew());
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(CupertinoIcons.plus, size: 18),
        label: const Text(
          'New Brew',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
      );
    } else if (_currentIndex == 2) {
      return FloatingActionButton.extended(
        heroTag: 'interval_timer_list_fab',
        onPressed: () {
          HapticFeedback.selectionClick();
          locator<IntervalTimerController>().addNewIntervalTimer();
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(CupertinoIcons.plus, size: 18),
        label: const Text(
          'New Interval',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final barBackground = AppTheme.cardBackground(
      isDark: isDark,
    ).withValues(alpha: isDark ? 0.8 : 0.88);
    final borderColor = AppTheme.separator(isDark: isDark);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: _buildFloatingActionButton(colorScheme),
      // The session chips live in the bottom bar rather than floating over
      // the body, so the Scaffold lifts the FAB above them instead of
      // letting the two overlap. Each chip renders nothing when its session
      // is idle, so the bar collapses back to the nav strip.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActivityFloater(),
                _IntervalFloater(),
                _BrewFloater(),
              ],
            ),
          ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: barBackground,
                  border: Border(
                    top: BorderSide(color: borderColor, width: 0.6),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  // A minimum, not a fixed height: at 52 the icon-plus-label
                  // column clipped its own labels on 375pt-wide phones at the
                  // default text size, and worse at accessibility scales.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Row(
                      children: [
                        _buildNavItem(
                          context: context,
                          index: 0,
                          label: 'Activities',
                          icon: CupertinoIcons.timer,
                          selectedIcon: CupertinoIcons.timer_fill,
                          colorScheme: colorScheme,
                        ),
                        _buildNavItem(
                          context: context,
                          index: 1,
                          label: 'Brew',
                          icon: Icons.coffee_outlined,
                          selectedIcon: Icons.coffee,
                          colorScheme: colorScheme,
                        ),
                        _buildNavItem(
                          context: context,
                          index: 2,
                          label: 'Intervals',
                          icon: CupertinoIcons.stopwatch,
                          selectedIcon: CupertinoIcons.stopwatch_fill,
                          colorScheme: colorScheme,
                        ),
                        _buildNavItem(
                          context: context,
                          index: 3,
                          label: 'Settings',
                          icon: CupertinoIcons.gear_alt,
                          selectedIcon: CupertinoIcons.gear_alt_fill,
                          colorScheme: colorScheme,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _currentIndex == index;
    final activeColor = colorScheme.primary;
    final inactiveColor = colorScheme.onSurfaceVariant;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTabSelected(index),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: 24,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                // The icon already carries the meaning, so the label is
                // capped well below the system maximum: unbounded scaling
                // pushes the nav strip over a third of the screen.
                textScaler: TextScaler.linear(
                  MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3),
                ),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The minimized brew: a washi pill floating above the nav bar whenever a
/// started, unfinished brew lives in [BrewSessionService]. Tapping it
/// reopens the full run screen on the same controller; the close button
/// ends the brew.
class _BrewFloater extends StatelessWidget {
  String _clock(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final session = BrewSessionService();
    final palette = BrewTheme.paletteFor(Theme.of(context).brightness);

    return SignalBuilder(
      builder: (_) {
        final BrewRunController? controller = session.active.value;
        if (controller == null || !session.hasBrewInProgress) {
          return const SizedBox.shrink();
        }

        final target = controller.currentTarget;
        final label =
            target == null
                ? controller.currentStep.name
                : '${controller.currentStep.name} · pour to ${target}g';

        return Padding(
          // Gap above this chip when it shares the column with another.
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            key: const Key('brew-floater'),
            color: palette.paperRaised,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.pillRadius),
              side: BorderSide(color: palette.hairline),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.pillRadius),
              onTap:
                  () => unawaited(
                    AppPages.push<dynamic>(
                      Routes.brew,
                      extra: controller.recipe,
                    ),
                  ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(Icons.coffee, size: 18, color: palette.lead),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _clock(controller.stepRemaining),
                      style: TextStyle(
                        color:
                            controller.isPouring
                                ? palette.lead
                                : palette.inkSoft,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: const Key('brew-floater-close'),
                      icon: Icon(Icons.close, size: 16, color: palette.inkSoft),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: 'End brew',
                      onPressed: session.clear,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The minimized interval schedule: a pill floating above the nav bar
/// whenever an unfinished session lives in [IntervalSessionService].
/// Tapping it reopens the full run screen on the same controller; the close
/// button ends the session.
class _IntervalFloater extends StatelessWidget {
  String _clock(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final mmss =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
    return hours > 0 ? '$hours:$mmss' : mmss;
  }

  @override
  Widget build(BuildContext context) {
    final session = IntervalSessionService();
    final colorScheme = Theme.of(context).colorScheme;

    return SignalBuilder(
      builder: (_) {
        final IntervalRunController? controller = session.active.value;
        if (controller == null || !session.hasSessionInProgress) {
          return const SizedBox.shrink();
        }

        final label =
            '${controller.timer.name} · alarm '
            '${controller.currentAlarmIndex.value + 1} of '
            '${controller.allAlarmTimes.length}';

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            key: const Key('interval-floater'),
            color: colorScheme.surfaceContainerHigh,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.pillRadius),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.pillRadius),
              onTap:
                  () => unawaited(
                    AppPages.push<dynamic>(
                      Routes.intervalTimer,
                      extra: controller.timer,
                    ),
                  ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.stopwatch,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _clock(controller.untilNextAlarm),
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: const Key('interval-floater-close'),
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: 'End interval timer',
                      onPressed: session.clear,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The minimized activity routine: a pill floating above the nav bar
/// whenever an unfinished routine lives in [ActivitySessionService].
/// Tapping it reopens the full run screen on the same controller; the close
/// button ends the routine.
class _ActivityFloater extends StatelessWidget {
  String _clock(int milliseconds) {
    final total = (milliseconds / 1000).ceil();
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final session = ActivitySessionService();
    final colorScheme = Theme.of(context).colorScheme;

    return SignalBuilder(
      builder: (_) {
        final ActivityRunController? controller = session.active.value;
        if (controller == null || !session.hasSessionInProgress) {
          return const SizedBox.shrink();
        }

        final label =
            controller.isPreparing.value
                ? '${controller.sequence.name} · get ready'
                : '${controller.sequence.name} · ${controller.currentTimer.name}';

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            key: const Key('activity-floater'),
            color: colorScheme.surfaceContainerHigh,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.pillRadius),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.pillRadius),
              onTap:
                  () => unawaited(
                    AppPages.push<dynamic>(
                      Routes.timer,
                      extra: controller.sequence,
                    ),
                  ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.timer,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _clock(controller.remainingMs.value),
                      style: TextStyle(
                        color:
                            controller.isRunning.value
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: const Key('activity-floater-close'),
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: 'End routine',
                      onPressed: session.clear,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
