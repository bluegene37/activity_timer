import 'package:hive/hive.dart';

part 'alarm_sound.g.dart';

@HiveType(typeId: 5)
enum AlarmSound {
  @HiveField(0)
  beep('Beep', 'timer_complete.mp3'),
  
  @HiveField(1)
  bell('Bell', 'bell.mp3'),
  
  @HiveField(2)
  chime('Chime', 'chime.mp3'),
  
  @HiveField(3)
  digital('Digital', 'digital.mp3'),
  
  @HiveField(4)
  gentle('Gentle', 'gentle.mp3');

  final String displayName;
  final String fileName;

  const AlarmSound(this.displayName, this.fileName);

  static AlarmSound fromString(String value) {
    return AlarmSound.values.firstWhere(
      (sound) => sound.name == value,
      orElse: () => AlarmSound.beep,
    );
  }
}
