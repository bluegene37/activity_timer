import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
    unawaited(Get.forceAppUpdate());
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
          child: Obx(() => RadioGroup<AlarmSound>(
            groupValue: _appController.defaultAlarmSound.value,
            onChanged: (AlarmSound? value) {
              if (value != null) {
                Get.back<AlarmSound>(result: value);
              }
            },
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: AlarmSound.values.length,
              itemBuilder: (context, index) {
                final sound = AlarmSound.values[index];
                return ListTile(
                  leading: Radio<AlarmSound>(value: sound),
                  title: Text(sound.displayName),
                  onTap: () => Get.back<AlarmSound>(result: sound),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => previewAlarmSound(sound),
                  ),
                );
              },
            ),
          )),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<AlarmSound>(),
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