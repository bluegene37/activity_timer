import 'dart:io';

import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/brew_recipe.dart';
import 'package:activity_timer/routes/app_pages.dart';
import 'package:activity_timer/services/brew_session_service.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:activity_timer/services/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _SilentCuePlayer implements CuePlayer {
  @override
  Future<void> playAlarm(AlarmSound sound) async {}

  @override
  Future<void> playCompletion() async {}

  @override
  Future<void> playStart() async {}

  @override
  Future<void> dispose() async {}
}

BrewRecipe recipe() => BrewRecipe(
  name: 'Morning V60',
  method: BrewMethod.v60,
  doseGrams: 20,
  ratio: 16,
  steps: [
    BrewStep(
      name: 'Bloom',
      seconds: 300,
      pourToFraction: 0.1875,
      pourSeconds: 200,
    ),
    BrewStep(
      name: 'Main pour',
      seconds: 300,
      pourToFraction: 1,
      pourSeconds: 200,
    ),
  ],
);

/// The nav screens animate continuously, so pumpAndSettle never settles;
/// bounded pumps are the established idiom for this widget tree.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (message) async =>
              const StandardMessageCodec().encodeMessage(<Object?>[null]),
        );

    tempDir = await Directory.systemTemp.createTemp('brew_floater_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  tearDown(() async {
    BrewSessionService().clear();
    await resetLocator();
  });

  Future<void> pumpNav(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    setUpLocator();
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: AppPages.createRouter()),
    );
    await settle(tester);
  }

  testWidgets('no floater when nothing is brewing', (tester) async {
    await pumpNav(tester);

    expect(find.byKey(const Key('brew-floater')), findsNothing);
  });

  testWidgets('a running brew floats on every tab and expands on tap', (
    tester,
  ) async {
    await pumpNav(tester);

    final session = BrewSessionService();
    session.obtain(recipe(), cuePlayer: _SilentCuePlayer()).start();
    await settle(tester);

    // Chip visible on the Activities tab...
    expect(find.byKey(const Key('brew-floater')), findsOneWidget);
    expect(find.textContaining('pour to 60g'), findsOneWidget);

    // ...and still there on another tab.
    await tester.tap(find.text('Settings'));
    await settle(tester);
    expect(find.byKey(const Key('brew-floater')), findsOneWidget);

    // Tapping expands the full run screen on the same session.
    await tester.tap(find.byKey(const Key('brew-floater')));
    await settle(tester);
    expect(find.text('pour to 60g'), findsOneWidget);
    expect(find.text('Morning V60'), findsWidgets);

    session.clear();
    await settle(tester);
  });

  testWidgets('minimizing the run screen keeps the brew and shows the chip', (
    tester,
  ) async {
    await pumpNav(tester);

    final session = BrewSessionService();
    final controller = session.obtain(recipe(), cuePlayer: _SilentCuePlayer())
      ..start();
    await settle(tester);

    await tester.tap(find.byKey(const Key('brew-floater')));
    await settle(tester);
    expect(find.text('pour to 60g'), findsOneWidget);

    // Minimize via the chevron.
    await tester.tap(find.byTooltip('Minimize'));
    await settle(tester);

    expect(
      session.active.value,
      same(controller),
      reason: 'brew survives the pop',
    );
    expect(controller.isRunning.value, isTrue);
    expect(find.byKey(const Key('brew-floater')), findsOneWidget);

    session.clear();
    await settle(tester);
  });

  testWidgets('the close button ends the brew and removes the chip', (
    tester,
  ) async {
    await pumpNav(tester);

    final session = BrewSessionService();
    session.obtain(recipe(), cuePlayer: _SilentCuePlayer()).start();
    await settle(tester);
    expect(find.byKey(const Key('brew-floater')), findsOneWidget);

    await tester.tap(find.byKey(const Key('brew-floater-close')));
    await settle(tester);

    expect(session.active.value, isNull);
    expect(find.byKey(const Key('brew-floater')), findsNothing);
  });
}
