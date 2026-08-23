import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'session_history.g.dart';

@HiveType(typeId: 6)
class SessionHistory extends HiveObject {
  SessionHistory({
    String? id,
    required this.title,
    DateTime? completedAt,
    required this.totalDurationInSeconds,
    this.itemCount = 1,
    this.loopCount = 0,
    this.sessionType = 'activity',
    this.category = 'custom',
  }) : id = id ?? const Uuid().v4(),
       completedAt = completedAt ?? DateTime.now();

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final DateTime completedAt;

  @HiveField(3)
  final int totalDurationInSeconds;

  @HiveField(4)
  final int itemCount;

  @HiveField(5)
  final int loopCount;

  @HiveField(6)
  final String sessionType; // 'activity' or 'interval'

  @HiveField(7)
  final String category; // 'fitness', 'work', 'custom'
}
