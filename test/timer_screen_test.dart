import 'dart:io';

import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/interval_phase.dart';
import 'package:activity_timer/screens/timer_screen.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    // The loop toggle persists to Hive; open real boxes outside any
    // fake-async zone.
    tempDir = await Directory.systemTemp.createTemp('timer_screen_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    await DatabaseService().init();

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    // Silence the audioplayers method channels.
    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
    }

    // runAsync lets the player's real asset load run: it needs a temp dir
    // (path_provider) and the global event stream to exist.
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
    messenger.setMockStreamHandler(
      const EventChannel('xyz.luan/audioplayers.global/events'),
      MockStreamHandler.inline(onListen: (arguments, events) {}),
    );

    // Reply successfully to the wakelock_plus pigeon channel.
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (message) async =>
          const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  TimerSequence buildSequence({int preparationSeconds = 0}) => TimerSequence(
    name: 'Test Routine',
    preparationSeconds: preparationSeconds,
    timers: [
      ActivityTimer(
        name: 'Step One',
        durationInSeconds: 60,
        phase: IntervalPhase.work,
      ),
      ActivityTimer(
        name: 'Step Two',
        durationInSeconds: 30,
        phase: IntervalPhase.rest,
      ),
    ],
  );

  testWidgets(
    'runs, skips forward and back, pauses and resumes with phase pills',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(home: TimerScreen(sequence: buildSequence())),
      );
      await tester.pump();

      // Starts on the first timer (Work phase), running.
      expect(find.text('Step One'), findsOneWidget);
      expect(find.text('WORK'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('1:00'), findsOneWidget);
      expect(find.text('remaining'), findsOneWidget);
      expect(find.text('Next: Step Two (0:30)'), findsOneWidget);

      // Test +15s adjustment button
      expect(find.text('+15s'), findsOneWidget);
      await tester.tap(find.text('+15s'));
      await tester.pump();
      expect(find.text('1:15'), findsOneWidget);

      // Skip to the second timer (Rest phase).
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pump();
      expect(find.text('Step Two'), findsOneWidget);
      expect(find.text('REST'), findsOneWidget);
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.text('0:30'), findsOneWidget);

      // Back to the first timer.
      await tester.tap(find.byIcon(Icons.skip_previous));
      await tester.pump();
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('Step One'), findsOneWidget);

      // Pause and resume.
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      expect(find.text('paused'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsWidgets);

      await tester.tap(find.byIcon(Icons.play_arrow).first);
      await tester.pump();
      expect(find.text('remaining'), findsOneWidget);
    },
  );

  testWidgets('handles preparation countdown before sequence starts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: TimerScreen(sequence: buildSequence(preparationSeconds: 5)),
      ),
    );
    await tester.pump();

    // In preparation state
    expect(find.text('GET READY!'), findsOneWidget);
    expect(find.text('PREPARE'), findsOneWidget);
    expect(find.text('0:05'), findsOneWidget);
    expect(find.text('Starts with: Step One (1:00)'), findsOneWidget);

    // Skip prep to go directly to work phase
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pump();
    expect(find.text('Step One'), findsOneWidget);
    expect(find.text('WORK'), findsOneWidget);
  });

  testWidgets('system back shows the exit confirmation instead of popping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(home: TimerScreen(sequence: buildSequence())),
    );
    await tester.pump();

    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pump();

    // Timer screen is still there, with the confirm dialog on top.
    expect(find.text('Exit Activity?'), findsOneWidget);
    expect(find.text('Step One'), findsOneWidget);

    // Cancel keeps the session alive.
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Exit Activity?'), findsNothing);
    expect(find.text('Step One'), findsOneWidget);
  });

  testWidgets('loop toggle persists as the routine default', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final sequence = buildSequence();
    await tester.pumpWidget(MaterialApp(home: TimerScreen(sequence: sequence)));
    await tester.pump();

    expect(sequence.defaultLoopEnabled, isFalse);

    // Hive IO only progresses outside the fake-async zone, so the tap that
    // triggers the save and its settling delay share one runAsync block.
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Enable loop'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(
      sequence.defaultLoopEnabled,
      isTrue,
      reason: 'the routine must remember it loops',
    );

    final stored = await tester.runAsync(
      () => DatabaseService().getAllActivitySequences(),
    );
    expect(
      stored!.singleWhere((s) => s.id == sequence.id).defaultLoopEnabled,
      isTrue,
      reason: 'the loop choice survives a restart',
    );

    // Toggling back off persists too.
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Disable loop'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    final storedAgain = await tester.runAsync(
      () => DatabaseService().getAllActivitySequences(),
    );
    expect(
      storedAgain!.singleWhere((s) => s.id == sequence.id).defaultLoopEnabled,
      isFalse,
    );
  });
}
