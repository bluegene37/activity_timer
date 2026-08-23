import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/interval_phase.dart';
import 'package:activity_timer/screens/timer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    // Silence the audioplayers method channels.
    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
    }

    // Reply successfully to the wakelock_plus pigeon channel.
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (message) async =>
          const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
  });

  TimerSequence buildSequence({int preparationSeconds = 0}) => TimerSequence(
        name: 'Test Routine',
        preparationSeconds: preparationSeconds,
        timers: [
          ActivityTimer(name: 'Step One', durationInSeconds: 60, phase: IntervalPhase.work),
          ActivityTimer(name: 'Step Two', durationInSeconds: 30, phase: IntervalPhase.rest),
        ],
      );

  testWidgets('runs, skips forward and back, pauses and resumes with phase pills',
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
  });

  testWidgets('handles preparation countdown before sequence starts', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(home: TimerScreen(sequence: buildSequence(preparationSeconds: 5))),
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

  testWidgets('system back shows the exit confirmation instead of popping',
      (tester) async {
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
}
