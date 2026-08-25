import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/brew_recipe.dart';
import 'package:activity_timer/services/brew_session_service.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

BrewRecipe recipe({String name = 'Morning V60'}) => BrewRecipe(
  name: name,
  method: BrewMethod.v60,
  doseGrams: 20,
  ratio: 16,
  steps: [
    BrewStep(name: 'Bloom', seconds: 30, pourToFraction: 0.1875, pourSeconds: 10),
    BrewStep(name: 'Main pour', seconds: 30, pourToFraction: 1, pourSeconds: 15),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Reply successfully to the wakelock_plus pigeon channel so the
    // controller's WakelockPlus.enable/disable calls don't throw in tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (message) async =>
              const StandardMessageCodec().encodeMessage(<Object?>[null]),
        );
  });

  final session = BrewSessionService();

  tearDown(session.clear);

  test('obtain creates a controller and exposes it as the active session', () {
    final brew = recipe();
    final controller = session.obtain(brew, cuePlayer: _SilentCuePlayer());

    expect(session.active.value, same(controller));
    expect(controller.recipe.id, brew.id);
  });

  test('obtain returns the SAME controller for the same recipe', () {
    final brew = recipe();
    final first = session.obtain(brew, cuePlayer: _SilentCuePlayer());
    final second = session.obtain(brew, cuePlayer: _SilentCuePlayer());

    expect(second, same(first), reason: 'reopening the screen must resume, not restart');
  });

  test('obtain for a different recipe replaces the session', () {
    final first = session.obtain(recipe(), cuePlayer: _SilentCuePlayer());
    final second = session.obtain(
      recipe(name: 'Kalita'),
      cuePlayer: _SilentCuePlayer(),
    );

    expect(second, isNot(same(first)));
    expect(session.active.value, same(second));
  });

  test('clear closes the session', () {
    session.obtain(recipe(), cuePlayer: _SilentCuePlayer());
    session.clear();

    expect(session.active.value, isNull);
  });

  test('hasBrewInProgress reflects a started, unfinished brew only', () async {
    expect(session.hasBrewInProgress, isFalse, reason: 'no session at all');

    final controller = session.obtain(recipe(), cuePlayer: _SilentCuePlayer());
    expect(
      session.hasBrewInProgress,
      isFalse,
      reason: 'opened but never started',
    );

    controller.start();
    expect(session.hasBrewInProgress, isTrue);

    // Let the real ticker record some elapsed time before pausing, as any
    // real pause would.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    controller.pause();
    expect(
      session.hasBrewInProgress,
      isTrue,
      reason: 'a paused mid-brew still deserves the floater',
    );
  });

  test('releaseIfIdle clears an unstarted session and keeps a running one', () {
    session.obtain(recipe(), cuePlayer: _SilentCuePlayer());
    session.releaseIfIdle();
    expect(session.active.value, isNull, reason: 'never started -> no floater');

    final controller = session.obtain(recipe(), cuePlayer: _SilentCuePlayer());
    controller.start();
    session.releaseIfIdle();
    expect(
      session.active.value,
      same(controller),
      reason: 'running brew survives the screen being popped',
    );
  });
}
