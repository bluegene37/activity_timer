import 'package:activity_timer/controllers/brew_run_controller.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/brew_recipe.dart';
import 'package:activity_timer/screens/brew_run_screen.dart';
import 'package:activity_timer/services/brew_cue_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeClock {
  DateTime value = DateTime(2026, 1, 1, 8);

  DateTime call() => value;

  void advance(Duration delta) => value = value.add(delta);
}

class _SilentCuePlayer implements BrewCuePlayer {
  @override
  Future<void> playStepEnd(AlarmSound sound) async {}

  @override
  Future<void> dispose() async {}
}

BrewRecipe brew() => BrewRecipe(
  name: 'Test brew',
  method: BrewMethod.v60,
  doseGrams: 20,
  ratio: 16,
  steps: [
    BrewStep(
      name: 'Bloom',
      seconds: 30,
      pourToFraction: 0.1875,
      pourSeconds: 10,
      description: 'Wet the bed evenly.',
    ),
    BrewStep(name: 'Main pour', seconds: 30, pourToFraction: 1, pourSeconds: 15),
    BrewStep(name: 'Drawdown', seconds: 20, kind: BrewStepKind.drawdown),
  ],
);

void main() {
  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
    }

    // wakelock_plus talks over a pigeon message channel in the installed
    // plugin version, not a plain MethodChannel.
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (message) async =>
          const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
  });

  tearDown(Get.reset);

  testWidgets('shows the target, the delta, the rate and the description', (
    tester,
  ) async {
    final clock = _FakeClock();
    final controller = BrewRunController(
      recipe: brew(),
      clock: clock.call,
      cuePlayer: _SilentCuePlayer(),
    );

    await tester.pumpWidget(
      GetMaterialApp(home: BrewRunScreen(recipe: brew(), controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('pour to 60g'), findsOneWidget);
    expect(find.text('Bloom'), findsOneWidget);
    expect(find.textContaining('+60g'), findsOneWidget);
    expect(find.textContaining('≈6.0 g/s'), findsOneWidget);
    expect(find.text('Wet the bed evenly.'), findsOneWidget);
    expect(find.textContaining('next: pour to 320g'), findsOneWidget);

    controller.reset();
  });

  testWidgets('reads POUR during the window and WAIT after it', (tester) async {
    final clock = _FakeClock();
    final controller = BrewRunController(
      recipe: brew(),
      clock: clock.call,
      cuePlayer: _SilentCuePlayer(),
    );

    await tester.pumpWidget(
      GetMaterialApp(home: BrewRunScreen(recipe: brew(), controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(find.text('POUR'), findsOneWidget);

    clock.advance(const Duration(seconds: 11));
    await tester.pump(const Duration(seconds: 11));

    expect(find.text('WAIT'), findsOneWidget);
    expect(find.text('POUR'), findsNothing);

    controller.reset();
  });

  testWidgets('moves to the next step at the boundary', (tester) async {
    final clock = _FakeClock();
    final controller = BrewRunController(
      recipe: brew(),
      clock: clock.call,
      cuePlayer: _SilentCuePlayer(),
    );

    await tester.pumpWidget(
      GetMaterialApp(home: BrewRunScreen(recipe: brew(), controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();

    clock.advance(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));

    expect(find.text('pour to 320g'), findsOneWidget);
    expect(find.text('Main pour'), findsOneWidget);

    controller.reset();
  });

  testWidgets('shows a done state after the last step', (tester) async {
    final clock = _FakeClock();
    final controller = BrewRunController(
      recipe: brew(),
      clock: clock.call,
      cuePlayer: _SilentCuePlayer(),
    );

    await tester.pumpWidget(
      GetMaterialApp(home: BrewRunScreen(recipe: brew(), controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();

    clock.advance(const Duration(seconds: 85));
    await tester.pump(const Duration(seconds: 85));

    expect(find.text('Brew complete'), findsOneWidget);

    controller.reset();
  });
}
