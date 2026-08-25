import 'package:hive_ce/hive.dart';

part 'alarm_sound.g.dart';

@HiveType(typeId: 5)
enum AlarmSound {
  @HiveField(0)
  beep('Beep', 'beep.wav', description: 'Short and neutral'),

  @HiveField(1)
  bell('Bell', 'bell.mp3', description: 'Resonant single strike'),

  @HiveField(2)
  chime('Chime', 'chime.mp3', description: 'Gentle ascending notes'),

  @HiveField(3)
  digital('Digital', 'digital.mp3', description: 'Classic clock radio'),

  @HiveField(4)
  gentle('Gentle', 'gentle.mp3', description: 'Soft and unhurried'),

  @HiveField(5)
  alert('Alert', 'alert.wav', description: 'Urgent triple pulse — loudest'),

  @HiveField(6)
  siren('Siren', 'siren.wav', description: 'Two-tone alternating alarm'),

  @HiveField(7)
  marimba('Marimba', 'marimba.wav', description: 'Musical, still cuts through');

  const AlarmSound(this.displayName, this.fileName, {this.description = ''});

  final String displayName;
  final String fileName;

  /// One-line hint shown next to the name when picking a sound.
  final String description;

  /// Resolves a persisted [Enum.name], falling back to [AlarmSound.beep].
  static AlarmSound fromString(String value) => AlarmSound.values.firstWhere(
    (sound) => sound.name == value,
    orElse: () => AlarmSound.beep,
  );
}
