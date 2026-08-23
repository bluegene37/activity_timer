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

    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
    }

    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (message) async =>
          const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
  });

  testWidgets(
    'TimerScreen renders landscape split HUD when orientation is horizontal',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sequence = TimerSequence(
        name: 'Gym Workout Routine',
        category: 'fitness',
        preparationSeconds: 0,
        timers: [
          ActivityTimer(
            name: 'Barbell Squats',
            durationInSeconds: 45,
            phase: IntervalPhase.work,
          ),
          ActivityTimer(
            name: 'Rest',
            durationInSeconds: 60,
            phase: IntervalPhase.rest,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: TimerScreen(sequence: sequence)),
      );
      await tester.pump();

      // Verify landscape split layout elements
      expect(find.text('Gym Workout Routine'), findsOneWidget);
      expect(find.text('Barbell Squats'), findsOneWidget);
      expect(find.text('WORK'), findsOneWidget);
      expect(find.text('0:45'), findsOneWidget);
      expect(find.text('+15s'), findsOneWidget);
      expect(find.text('-15s'), findsOneWidget);
      expect(find.text('Next: Rest (1:00)'), findsOneWidget);
    },
  );
}
