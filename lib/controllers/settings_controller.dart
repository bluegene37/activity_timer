import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/alarm_sound.dart';
import 'app_controller.dart';

class SettingsController extends GetxController {
  final _audioPlayer = AudioPlayer();
  late final AppController _appController;

  @override
  void onInit() {
    super.onInit();
    _appController = Get.find<AppController>();
  }

  @override
  void onClose() {
    _audioPlayer.dispose();
    super.onClose();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _appController.setThemeMode(mode);
    Get.changeThemeMode(mode);
  }

  Future<void> setThemeColor(Color color) async {
    await _appController.setThemeColor(color);
    // Force rebuild of the app with new theme
    Get.forceAppUpdate();
  }

  Future<void> toggleSound(bool enabled) async {
    await _appController.setSoundEnabled(enabled);
  }

  Future<void> toggleVibration(bool enabled) async {
    await _appController.setVibrationEnabled(enabled);
  }

  Future<void> selectDefaultAlarmSound() async {
    final selectedSound = await Get.dialog<AlarmSound>(
      AlertDialog(
        title: const Text('Select Default Alarm Sound'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: AlarmSound.values.length,
            itemBuilder: (context, index) {
              final sound = AlarmSound.values[index];
              return Obx(() => RadioListTile<AlarmSound>(
                title: Text(sound.displayName),
                value: sound,
                groupValue: _appController.defaultAlarmSound.value,
                onChanged: (AlarmSound? value) {
                  if (value != null) {
                    Get.back(result: value);
                  }
                },
                secondary: IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => previewAlarmSound(sound),
                ),
              ));
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedSound != null) {
      await _appController.setDefaultAlarmSound(selectedSound);
    }
  }

  Future<void> previewAlarmSound(AlarmSound sound) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setSource(AssetSource('sounds/${sound.fileName}'));
      await _audioPlayer.resume();
    } catch (e) {
      Get.snackbar('Error', 'Failed to play sound: $e');
    }
  }
}