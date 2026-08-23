import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/activity_list_screen.dart';
import '../screens/interval_timer_list_screen.dart';
import '../screens/settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ActivityListScreen(),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final barBackground = (isDark ? const Color(0xFF1C1C1E) : Colors.white)
        .withValues(alpha: isDark ? 0.8 : 0.88);
    final borderColor = isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: barBackground,
              border: Border(
                top: BorderSide(
                  color: borderColor,
                  width: 0.6,
                ),
              ),
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
                      label: 'Intervals',
                      icon: CupertinoIcons.stopwatch,
                      selectedIcon: CupertinoIcons.stopwatch_fill,
                      colorScheme: colorScheme,
                    ),
                    _buildNavItem(
                      index: 2,
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
