import 'dart:io';
import 'dart:typed_data';

import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Every audible cue the app can play, by asset file name.
Iterable<String> allCueFiles() sync* {
  for (final sound in AlarmSound.values) {
    yield sound.fileName;
  }
  yield AudioCuePlayer.completionSound;
}

/// Reads the leading bytes without pulling the whole file into memory.
Uint8List head(File file, int count) {
  final raf = file.openSync();
  try {
    return raf.readSync(count);
  } finally {
    raf.closeSync();
  }
}

bool isWav(Uint8List b) =>
    b.length >= 12 &&
    String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
    String.fromCharCodes(b.sublist(8, 12)) == 'WAVE';

bool isMp3(Uint8List b) =>
    b.length >= 3 &&
    // Either an ID3 tag or a raw MPEG frame sync.
    (String.fromCharCodes(b.sublist(0, 3)) == 'ID3' ||
        (b[0] == 0xFF && (b[1] & 0xE0) == 0xE0));

void main() {
  // This suite exists because a cue file once shipped as a 154-byte text
  // placeholder named `.mp3`: the code path ran, the exception was
  // swallowed, and the alarm was simply silent. Names and extensions prove
  // nothing — these tests read the bytes.
  group('alarm assets', () {
    for (final fileName in allCueFiles()) {
      test('$fileName exists and is real audio', () {
        final file = File('assets/sounds/$fileName');
        expect(file.existsSync(), isTrue, reason: '$fileName is missing');

        final bytes = file.lengthSync();
        expect(
          bytes,
          greaterThan(4000),
          reason: '$fileName is $bytes bytes — too small to be audio',
        );

        final magic = head(file, 12);
        expect(
          fileName.endsWith('.wav') ? isWav(magic) : isMp3(magic),
          isTrue,
          reason: '$fileName does not start with a valid audio header',
        );
      });
    }

    test('every sound file under assets/sounds is reachable from the app', () {
      final onDisk =
          Directory('assets/sounds')
              .listSync()
              .whereType<File>()
              .map((f) => f.uri.pathSegments.last)
              .where((name) => !name.startsWith('.'))
              .toSet();

      expect(
        onDisk.difference(allCueFiles().toSet()),
        isEmpty,
        reason: 'orphan sound files ship in the bundle but can never play',
      );
      expect(
        allCueFiles().toSet().difference(onDisk),
        isEmpty,
        reason: 'the app references sounds that are not on disk',
      );
    });

    test('assets/sounds is declared in pubspec so the files ship', () {
      final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
      final assets =
          ((pubspec['flutter'] as Map)['assets'] as List).cast<String>();
      expect(assets, contains('assets/sounds/'));
    });

    test('each sound has a distinct name and a description', () {
      final names = AlarmSound.values.map((s) => s.displayName).toSet();
      expect(names, hasLength(AlarmSound.values.length));

      for (final sound in AlarmSound.values) {
        expect(
          sound.description,
          isNotEmpty,
          reason: '${sound.displayName} needs a hint in the picker',
        );
      }
    });
  });
}
