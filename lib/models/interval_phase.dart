import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

part 'interval_phase.g.dart';

@HiveType(typeId: 7)
enum IntervalPhase {
  @HiveField(0)
  work('Work', Icons.fitness_center, Color(0xFFFF6D00)), // Energetic amber/orange
  @HiveField(1)
  rest('Rest', Icons.bedtime_outlined, Color(0xFF00B0FF)), // Calming cyan/blue
  @HiveField(2)
  prepare('Prepare', Icons.hourglass_top_outlined, Color(0xFFFFD600)), // Golden yellow
  @HiveField(3)
  cooldown('Cool Down', Icons.ac_unit, Color(0xFF00E676)); // Fresh mint green

  const IntervalPhase(this.displayName, this.icon, this.defaultColor);

  final String displayName;
  final IconData icon;
  final Color defaultColor;

  static IntervalPhase fromString(String? name) {
    if (name == null) return IntervalPhase.work;
    final lowerName = name.toLowerCase();
    return IntervalPhase.values.firstWhere(
      (phase) => phase.name.toLowerCase() == lowerName,
      orElse: () => IntervalPhase.work,
    );
  }
}
