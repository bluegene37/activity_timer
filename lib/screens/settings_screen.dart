import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../controllers/app_controller.dart';
import '../theme/for_ui.dart';
import '../components/for_ui_card.dart';
import '../components/color_selector.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());
    final appController = Get.find<AppController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(ForUI.spacing),
        children: [
          ForUICard(
            padding: const EdgeInsets.all(ForUI.spacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: ForUI.spacingSmall),
                const Divider(),

                // Theme color selector
                const SizedBox(height: ForUI.spacingSmall),
                Obx(
                  () => ColorSelector(
                    selectedColor: appController.themeColor.value,
                    onColorSelected: controller.setThemeColor,
                  ),
                ),
                const SizedBox(height: ForUI.spacing),

                // Theme mode selection
                Obx(
                  () => RadioListTile<ThemeMode>(
                    title: const Text('Light Theme'),
                    subtitle: const Text('Bright colors and white background'),
                    value: ThemeMode.light,
                    groupValue: appController.themeMode.value,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        controller.setThemeMode(value);
                      }
                    },
                  ),
                ),
                Obx(
                  () => RadioListTile<ThemeMode>(
                    title: const Text('Dark Theme'),
                    subtitle: const Text(
                      'Dark colors for low-light environments',
                    ),
                    value: ThemeMode.dark,
                    groupValue: appController.themeMode.value,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        controller.setThemeMode(value);
                      }
                    },
                  ),
                ),
                Obx(
                  () => RadioListTile<ThemeMode>(
                    title: const Text('System Theme'),
                    subtitle: const Text(
                      'Follow system dark/light mode settings',
                    ),
                    value: ThemeMode.system,
                    groupValue: appController.themeMode.value,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        controller.setThemeMode(value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: ForUI.spacing),

          ForUICard(
            padding: const EdgeInsets.all(ForUI.spacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: ForUI.spacingSmall),
                const Divider(),
                Obx(
                  () => SwitchListTile(
                    title: const Text('Sound Alerts'),
                    subtitle: const Text('Play sound when timer completes'),
                    value: appController.soundEnabled.value,
                    onChanged: controller.toggleSound,
                  ),
                ),
                Obx(
                  () => SwitchListTile(
                    title: const Text('Vibration'),
                    subtitle: const Text('Vibrate when timer completes'),
                    value: appController.vibrationEnabled.value,
                    onChanged: controller.toggleVibration,
                  ),
                ),
                Obx(
                  () => ListTile(
                    title: const Text('Default Alarm Sound'),
                    subtitle: Text(
                      appController.defaultAlarmSound.value.displayName,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed:
                              () => controller.previewAlarmSound(
                                appController.defaultAlarmSound.value,
                              ),
                          tooltip: 'Preview sound',
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: controller.selectDefaultAlarmSound,
                          tooltip: 'Change sound',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: ForUI.spacing),

          ForUICard(
            padding: const EdgeInsets.all(ForUI.spacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: ForUI.spacingSmall),
                const Divider(),
                ListTile(
                  title: const Text('Version'),
                  trailing: const Text('1.0.0'),
                ),
                ListTile(
                  title: const Text('Developer'),
                  trailing: const Text('ForUI Team'),
                ),
              ],
            ),
          ),

          const SizedBox(height: ForUI.spacingLarge),

          // Theme preview
          ForUICard(
            padding: const EdgeInsets.all(ForUI.spacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme Preview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: ForUI.spacingSmall),
                const Divider(),
                Container(
                  padding: const EdgeInsets.all(ForUI.spacing),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(ForUI.borderRadius),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Theme Sample', style: theme.textTheme.titleLarge),
                      const SizedBox(height: ForUI.spacingSmall),
                      Text(
                        'This is how your app will look with the selected theme.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: ForUI.spacing),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {},
                            child: const Text('Primary Button'),
                          ),
                          const SizedBox(width: ForUI.spacingSmall),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Text Button'),
                          ),
                        ],
                      ),
                    ],
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
