import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../components/color_selector.dart';
import '../controllers/app_controller.dart';
import '../controllers/settings_controller.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());
    final appController = Get.find<AppController>();
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
              // Top Header
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
                      CupertinoIcons.gear_alt_fill,
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
                          'Settings',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Configure your app',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // APPEARANCE SECTION
              _buildSectionHeader('Appearance', textTheme),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground(isDark: isDark),
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(
                    color: AppTheme.separator(isDark: isDark),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Theme Mode',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'System follows your device setting',
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),
                          Obx(
                            () => SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<ThemeMode>(
                                segments: const [
                                  ButtonSegment(
                                    value: ThemeMode.system,
                                    label: Text('System'),
                                    icon: Icon(
                                      CupertinoIcons.device_phone_portrait,
                                      size: 16,
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.light,
                                    label: Text('Light'),
                                    icon: Icon(
                                      CupertinoIcons.sun_max_fill,
                                      size: 16,
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.dark,
                                    label: Text('Dark'),
                                    icon: Icon(
                                      CupertinoIcons.moon_fill,
                                      size: 16,
                                    ),
                                  ),
                                ],
                                selected: {appController.themeMode.value},
                                onSelectionChanged: (selection) {
                                  HapticFeedback.selectionClick();
                                  appController.setThemeMode(selection.first);
                                },
                                style: SegmentedButton.styleFrom(
                                  selectedBackgroundColor: colorScheme.primary
                                      .withValues(alpha: 0.18),
                                  selectedForegroundColor: colorScheme.primary,
                                  side: BorderSide(
                                    color: AppTheme.separator(isDark: isDark),
                                    width: 0.8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: AppTheme.separator(isDark: isDark),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accent Color',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Obx(
                            () => ColorSelector(
                              selectedColor: appController.themeColor.value,
                              onColorSelected: controller.setThemeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // NOTIFICATIONS SECTION
              _buildSectionHeader('Notifications', textTheme),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground(isDark: isDark),
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(
                    color: AppTheme.separator(isDark: isDark),
                    width: 0.8,
                  ),
                ),
                child: Material(
                  // Gives the ListTiles a Material below the painted background so
                  // their ink splashes stay visible.
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      Obx(
                        () => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sound Alerts',
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Play sound when timer completes',
                                      style: textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              CupertinoSwitch(
                                value: appController.soundEnabled.value,
                                activeTrackColor: colorScheme.primary,
                                onChanged: (value) {
                                  HapticFeedback.selectionClick();
                                  controller.toggleSound(value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: AppTheme.separator(isDark: isDark),
                      ),
                      Obx(
                        () => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Vibration',
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Vibrate when timer completes',
                                      style: textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              CupertinoSwitch(
                                value: appController.vibrationEnabled.value,
                                activeTrackColor: colorScheme.primary,
                                onChanged: (value) {
                                  HapticFeedback.selectionClick();
                                  controller.toggleVibration(value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: AppTheme.separator(isDark: isDark),
                      ),
                      Obx(
                        () => ListTile(
                          title: Text(
                            'Default Alarm Sound',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            appController.defaultAlarmSound.value.displayName,
                            style: textTheme.bodySmall,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 6,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  CupertinoIcons.play_circle_fill,
                                  color: colorScheme.primary,
                                  size: 28,
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  controller.previewAlarmSound(
                                    appController.defaultAlarmSound.value,
                                  );
                                },
                                tooltip: 'Preview sound',
                              ),
                              IconButton(
                                icon: Icon(
                                  CupertinoIcons.pencil,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  controller.selectDefaultAlarmSound();
                                },
                                tooltip: 'Change sound',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ABOUT SECTION
              _buildSectionHeader('About', textTheme),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground(isDark: isDark),
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(
                    color: AppTheme.separator(isDark: isDark),
                    width: 0.8,
                  ),
                ),
                child: Material(
                  // Gives the ListTiles a Material below the painted background so
                  // their ink splashes stay visible.
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          'Version',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Text(
                          '1.0.0',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 2,
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: AppTheme.separator(isDark: isDark),
                      ),
                      ListTile(
                        title: Text(
                          'Developer',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Text(
                          'CodeGenexis',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // THEME PREVIEW SECTION
              _buildSectionHeader('Theme Preview', textTheme),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground(isDark: isDark),
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(
                    color: AppTheme.separator(isDark: isDark),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme Sample',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This is how your app buttons and highlights look with your chosen accent color.',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            child: const Text('Primary Button'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            child: const Text('Outlined Button'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, TextTheme textTheme) {
    return Text(
      title,
      style: textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }
}
