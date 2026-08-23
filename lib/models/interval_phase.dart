import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

part 'interval_phase.g.dart';

@HiveType(typeId: 7)
enum IntervalPhase {
  @HiveField(0)
  work,
  @HiveField(1)
  rest,
  @HiveField(2)
  prepare,
  @HiveField(3)
  cooldown;

  String get displayName {
    switch (this) {
      case IntervalPhase.work:
        return 'Work';
      case IntervalPhase.rest:
        return 'Rest';
      case IntervalPhase.prepare:
        return 'Prepare';
      case IntervalPhase.cooldown:
        return 'Cool Down';
    }
  }

  IconData get icon {
    switch (this) {
      case IntervalPhase.work:
        return Icons.fitness_center;
      case IntervalPhase.rest:
        return Icons.bedtime_outlined;
      case IntervalPhase.prepare:
        return Icons.hourglass_top_outlined;
      case IntervalPhase.cooldown:
        return Icons.ac_unit;
    }
  }

  Color get defaultColor {
    switch (this) {
      case IntervalPhase.work:
        return const Color(0xFFFF6D00); // Energetic amber/orange
      case IntervalPhase.rest:
        return const Color(0xFF00B0FF); // Calming cyan/blue
      case IntervalPhase.prepare:
        return const Color(0xFFFFD600); // Golden yellow
      case IntervalPhase.cooldown:
        return const Color(0xFF00E676); // Fresh mint green
    }
  }

  static IntervalPhase fromString(String? name) {
    if (name == null) return IntervalPhase.work;
    return IntervalPhase.values.firstWhere(
      (phase) => phase.name.toLowerCase() == name.toLowerCase(),
      orElse: () => IntervalPhase.work,
    );
  }
}
