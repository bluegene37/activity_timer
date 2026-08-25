import 'package:activity_timer/components/alarm_sound_picker.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingCuePlayer implements CuePlayer {
  final List<AlarmSound> previews = [];
  int disposeCount = 0;

  @override
  Future<void> playAlarm(AlarmSound sound) async => previews.add(sound);

  @override
  Future<void> playCompletion() async {}

  @override
  Future<void> playStart() async {}

  @override
  Future<void> dispose() async => disposeCount++;
}

void main() {
  // The picker's own future must NOT be awaited by the helper: an async
  // function returning a Future awaits it, which would hang until the
  // sheet closes. Tests read `pending` after driving the dialog.
  late Future<AlarmSoundChoice?> pending;

  Future<void> openPicker(
    WidgetTester tester,
    _RecordingCuePlayer cues, {
    AlarmSound? selected,
    bool allowAppDefault = false,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => ElevatedButton(
                onPressed: () {
                  pending = showAlarmSoundPicker(
                    context,
                    selected: selected,
                    allowDefault: allowAppDefault,
                    cuePlayer: cues,
                  );
                },
                child: const Text('open'),
              ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every sound with its description', (tester) async {
    final cues = _RecordingCuePlayer();
    await openPicker(tester, cues, selected: AlarmSound.beep);

    for (final sound in AlarmSound.values) {
      expect(
        find.byKey(Key('alarm-sound-${sound.name}')),
        findsOneWidget,
        reason: '${sound.displayName} must be offered',
      );
    }
    // The loud additions are reachable and described.
    expect(find.text('Alert'), findsOneWidget);
    expect(find.text('Urgent triple pulse — loudest'), findsOneWidget);
    expect(find.text('Siren'), findsOneWidget);
  });

  testWidgets('tapping a sound previews it and keeps the sheet open', (
    tester,
  ) async {
    final cues = _RecordingCuePlayer();
    await openPicker(tester, cues, selected: AlarmSound.beep);

    await tester.tap(find.byKey(const Key('alarm-sound-alert')));
    await tester.pumpAndSettle();

    expect(cues.previews, [AlarmSound.alert], reason: 'auditioned on tap');
    expect(
      find.byKey(const Key('alarm-sound-done')),
      findsOneWidget,
      reason: 'the sheet stays open so several sounds can be compared',
    );

    await tester.tap(find.byKey(const Key('alarm-sound-siren')));
    await tester.pumpAndSettle();
    expect(cues.previews, [AlarmSound.alert, AlarmSound.siren]);
  });

  testWidgets('Done returns the audition; Cancel returns nothing', (
    tester,
  ) async {
    final cues = _RecordingCuePlayer();
    await openPicker(tester, cues, selected: AlarmSound.beep);
    final chosen = pending;

    await tester.tap(find.byKey(const Key('alarm-sound-marimba')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('alarm-sound-done')));
    await tester.pumpAndSettle();

    expect((await chosen)?.sound, AlarmSound.marimba);

    // Done already popped the first sheet, so the button is tappable again.
    await openPicker(tester, cues, selected: AlarmSound.beep);
    final cancelled = pending;
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await cancelled, isNull, reason: 'cancel changes nothing');
  });

  testWidgets('the default row is offered only when allowed', (tester) async {
    final cues = _RecordingCuePlayer();
    await openPicker(tester, cues, selected: AlarmSound.beep);
    expect(find.text('Use default app sound'), findsNothing);

    // Close the first sheet before opening the second: a live dialog route
    // would otherwise sit over the button the helper taps.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await openPicker(
      tester,
      cues,
      selected: null,
      allowAppDefault: true,
    );
    final chosen = pending;
    expect(find.text('Use default app sound'), findsOneWidget);

    await tester.tap(find.text('Use default app sound'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('alarm-sound-done')));
    await tester.pumpAndSettle();

    final choice = await chosen;
    expect(choice, isNotNull, reason: 'a choice was made');
    expect(choice!.sound, isNull, reason: 'and it was "use the default"');
  });

  testWidgets('an injected player is left for its owner to dispose', (
    tester,
  ) async {
    final cues = _RecordingCuePlayer();
    await openPicker(tester, cues, selected: AlarmSound.beep);
    final cancelled = pending;
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await cancelled;

    expect(cues.disposeCount, 0);
  });
}
