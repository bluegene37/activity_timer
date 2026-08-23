import 'dart:io';

import 'package:activity_timer/controllers/app_controller.dart';
import 'package:activity_timer/models/settings.dart';
import 'package:activity_timer/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    // Silence the audioplayers platform channels so constructing players in
    // controllers does not raise MissingPluginException in tests.
    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
    }

    tempDir = await Directory.systemTemp.createTemp('settings_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(AppSettingsDataAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('SettingsScreen renders theme mode selector and sections', (
    tester,
  ) async {
    Get.put(AppController());

    await tester.pumpWidget(const GetMaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    // Three-way theme selector
    expect(find.text('Theme Mode'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Accent Color'), findsOneWidget);

    // Notification settings
    expect(find.text('Sound Alerts'), findsOneWidget);
    expect(find.text('Vibration'), findsOneWidget);
    expect(find.text('Default Alarm Sound'), findsOneWidget);

    // App Info
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.text('Developer'), findsOneWidget);
    expect(find.text('genexis.dev'), findsOneWidget);

    // Switching theme mode updates the controller
    final appController = Get.find<AppController>();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(appController.themeMode.value, ThemeMode.light);

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(appController.themeMode.value, ThemeMode.system);
  });
}
