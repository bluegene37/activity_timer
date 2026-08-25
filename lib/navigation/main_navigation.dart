import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/activity_list_controller.dart';
import '../controllers/brew_controller.dart';
import '../controllers/interval_timer_controller.dart';
import '../screens/activity_list_screen.dart';
import '../screens/brew_list_screen.dart';
import '../screens/interval_timer_list_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';

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
          Get.find<ActivityListController>().addNewSequence();
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
          unawaited(Get.find<BrewController>().addNewBrew());
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
          Get.find<IntervalTimerController>().addNewIntervalTimer();
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
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: barBackground,
              border: Border(top: BorderSide(color: borderColor, width: 0.6)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    _buildNavItem(
                      index: 0,
                      label: 'Activities',
                      icon: CupertinoIcons.timer,
                      selectedIcon: CupertinoIcons.timer_fill,
                      colorScheme: colorScheme,
                    ),
                    _buildNavItem(
                      index: 1,
                      label: 'Brew',
                      icon: Icons.coffee_outlined,
                      selectedIcon: Icons.coffee,
                      colorScheme: colorScheme,
                    ),
                    _buildNavItem(
                      index: 2,
                      label: 'Intervals',
                      icon: CupertinoIcons.stopwatch,
                      selectedIcon: CupertinoIcons.stopwatch_fill,
                      colorScheme: colorScheme,
                    ),
                    _buildNavItem(
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
    );
  }

  Widget _buildNavItem({
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
