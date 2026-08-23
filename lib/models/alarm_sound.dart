import 'package:hive_ce/hive.dart';

part 'alarm_sound.g.dart';

@HiveType(typeId: 5)
enum AlarmSound {
  @HiveField(0)
  beep('Beep', 'beep.wav'),

  @HiveField(1)
  bell('Bell', 'bell.mp3'),

  @HiveField(2)
  chime('Chime', 'chime.mp3'),

  @HiveField(3)
  digital('Digital', 'digital.mp3'),

  @HiveField(4)
  gentle('Gentle', 'gentle.mp3');

  const AlarmSound(this.displayName, this.fileName);

  final String displayName;
  final String fileName;

  /// Resolves a persisted [Enum.name], falling back to [AlarmSound.beep].
  static AlarmSound fromString(String value) => AlarmSound.values.firstWhere(
    (sound) => sound.name == value,
    orElse: () => AlarmSound.beep,
  );
}
