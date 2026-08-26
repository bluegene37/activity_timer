import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alarm_sound.dart';
import '../services/cue_player.dart';

/// The result of the picker: null means the sheet was dismissed without
/// choosing, while a record carrying a null [sound] means "use the app
/// default" (offered only when the caller allows it).
typedef AlarmSoundChoice = ({AlarmSound? sound});

/// Shows the one alarm-sound picker the whole app uses.
///
/// Tapping a row plays it, and the sheet stays open: picking an alarm you
/// cannot hear first is how people end up with a cue they never notice.
Future<AlarmSoundChoice?> showAlarmSoundPicker(
  BuildContext context, {
  required AlarmSound? selected,
  bool allowDefault = false,
  String title = 'Alarm Sound',
  CuePlayer? cuePlayer,
}) => showDialog<AlarmSoundChoice>(
  context: context,
  builder:
      (context) => AlarmSoundPickerDialog(
        selected: selected,
        allowDefault: allowDefault,
        title: title,
        cuePlayer: cuePlayer,
      ),
);

/// The picker itself. Use [showAlarmSoundPicker] when a `BuildContext` is
/// at hand; raise this directly (via `UiMessenger`) when one is not.
class AlarmSoundPickerDialog extends StatefulWidget {
  const AlarmSoundPickerDialog({
    super.key,
    required this.selected,
    this.allowDefault = false,
    this.title = 'Alarm Sound',
    this.cuePlayer,
  });

  final AlarmSound? selected;
  final bool allowDefault;
  final String title;

  /// Test seam: production builds its own player.
  final CuePlayer? cuePlayer;

  @override
  State<AlarmSoundPickerDialog> createState() => AlarmSoundPickerDialogState();
}

class AlarmSoundPickerDialogState extends State<AlarmSoundPickerDialog> {
  late final CuePlayer _cuePlayer = widget.cuePlayer ?? AudioCuePlayer();
  late AlarmSound? _selected = widget.selected;

  @override
  void dispose() {
    if (widget.cuePlayer == null) {
      unawaited(_cuePlayer.dispose());
    }
    super.dispose();
  }

  void _choose(AlarmSound? sound) {
    setState(() => _selected = sound);
    if (sound != null) {
      unawaited(_cuePlayer.playAlarm(sound));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(widget.title),
      contentPadding: const EdgeInsets.only(top: 12),
      content: SizedBox(
        width: double.maxFinite,
        child: RadioGroup<AlarmSound?>(
          groupValue: _selected,
          onChanged: _choose,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (widget.allowDefault)
                RadioListTile<AlarmSound?>(
                  value: null,
                  title: const Text('Use default app sound'),
                  subtitle: Text(
                    'Follows the sound set in Settings',
                    style: textTheme.bodySmall,
                  ),
                ),
              for (final sound in AlarmSound.values)
                RadioListTile<AlarmSound?>(
                  key: Key('alarm-sound-${sound.name}'),
                  value: sound,
                  title: Text(sound.displayName),
                  subtitle: Text(sound.description, style: textTheme.bodySmall),
                  secondary: const Icon(Icons.volume_up_outlined, size: 20),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('alarm-sound-done'),
          onPressed: () => Navigator.pop(context, (sound: _selected)),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
