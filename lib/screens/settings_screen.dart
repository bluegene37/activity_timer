import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../controllers/app_controller.dart';
import '../theme/app_theme.dart';
import '../components/color_selector.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());
    final appController = Get.find<AppController>();
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
                      color: colorScheme.primary, // Changed to strictly adhere to primary theme color
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.settings,
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
                          'Settings',
                          style: textTheme.headlineSmall,
                        ),
                        Text(
                          'Configure your app',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              _buildSectionHeader('Appearance', textTheme),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(() {
                        final isDark = appController.themeMode.value == ThemeMode.dark;
                        return SwitchListTile(
                          title: Text('Dark Mode', style: textTheme.titleSmall),
                          subtitle: Text('Use a high-contrast minimalist dark theme', style: textTheme.bodyMedium),
                          value: isDark,
                          onChanged: (value) {
                            appController.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                          },
                          activeTrackColor: colorScheme.primary,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          secondary: Icon(
                            isDark ? Icons.dark_mode : Icons.light_mode, 
                            color: isDark ? Colors.white : colorScheme.primary
                          ),
                        );
                      }),
                      
                      Obx(() {
                        final isDark = appController.themeMode.value == ThemeMode.dark;
                        if (isDark) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Divider(height: 1, color: colorScheme.surfaceContainerHighest),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dark Theme Accent Color',
                                      style: textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 16),
                                    ColorSelector(
                                      selectedColor: appController.themeColor.value,
                                      onColorSelected: controller.setThemeColor,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(height: 1, color: colorScheme.surfaceContainerHighest),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Theme Color',
                                    style: textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 16),
                                  ColorSelector(
                                    selectedColor: appController.themeColor.value,
                                    onColorSelected: controller.setThemeColor,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              _buildSectionHeader('Notifications', textTheme),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Obx(() => SwitchListTile(
                        title: Text('Sound Alerts', style: textTheme.titleSmall),
                        subtitle: Text('Play sound when timer completes', style: textTheme.bodyMedium),
                        value: appController.soundEnabled.value,
                        onChanged: controller.toggleSound,
                        activeTrackColor: colorScheme.primary,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      )),
                      Divider(height: 1, color: colorScheme.surfaceContainerHighest),
                      Obx(() => SwitchListTile(
                        title: Text('Vibration', style: textTheme.titleSmall),
                        subtitle: Text('Vibrate when timer completes', style: textTheme.bodyMedium),
                        value: appController.vibrationEnabled.value,
                        onChanged: controller.toggleVibration,
                        activeTrackColor: colorScheme.primary,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      )),
                      Divider(height: 1, color: colorScheme.surfaceContainerHighest),
                      Obx(() => ListTile(
                        title: Text('Default Alarm Sound', style: textTheme.titleSmall),
                        subtitle: Text(appController.defaultAlarmSound.value.displayName, style: textTheme.bodyMedium),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.play_circle_fill, color: colorScheme.primary, size: 32),
                              onPressed: () => controller.previewAlarmSound(appController.defaultAlarmSound.value),
                              tooltip: 'Preview sound',
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.edit, color: colorScheme.onSurfaceVariant),
                              onPressed: controller.selectDefaultAlarmSound,
                              tooltip: 'Change sound',
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              _buildSectionHeader('About', textTheme),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        title: Text('Version', style: textTheme.titleSmall),
                        trailing: Text('1.0.0', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      ),
                      Divider(height: 1, color: colorScheme.surfaceContainerHighest),
                      ListTile(
                        title: Text('Developer', style: textTheme.titleSmall),
                        trailing: Text('CodeGenexis', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              _buildSectionHeader('Theme Preview', textTheme),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme Sample', style: textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'This is how your app will look with the selected theme. You can see your primary color highlighted below.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: colorScheme.primary, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Outlined Button',
                              style: textTheme.titleSmall?.copyWith(color: colorScheme.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, TextTheme textTheme) {
    return Text(
      title,
      style: textTheme.titleLarge,
    );
  }
}
