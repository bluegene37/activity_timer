import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import 'alarm_sound.dart';

part 'brew_recipe.g.dart';

@HiveType(typeId: 10)
enum BrewStepKind {
  @HiveField(0)
  pour('Pour'),
  @HiveField(1)
  wait('Wait'),
  @HiveField(2)
  swirl('Swirl'),
  @HiveField(3)
  drawdown('Drawdown');

  const BrewStepKind(this.displayName);

  final String displayName;
}

@HiveType(typeId: 11)
enum BrewMethod {
  @HiveField(0)
  v60('V60'),
  @HiveField(1)
  chemex('Chemex'),
  @HiveField(2)
  kalita('Kalita Wave'),
  @HiveField(3)
  aeropress('AeroPress'),
  @HiveField(4)
  switchBrewer('Switch');

  const BrewMethod(this.displayName);

  final String displayName;

  /// Resolves a persisted [Enum.name], falling back to [BrewMethod.v60].
  static BrewMethod fromString(String? value) => BrewMethod.values.firstWhere(
    (method) => method.name == value,
    orElse: () => BrewMethod.v60,
  );
}

/// One timed step of a brew. A step with a [pourToFraction] is a pour: the
/// fraction is the cumulative share of the recipe's total water the scale
/// should read by the end of the pour window, so changing the dose rescales
/// every target at once.
@HiveType(typeId: 9)
class BrewStep extends HiveObject {
  BrewStep({
    required this.name,
    required this.seconds,
    this.kind = BrewStepKind.pour,
    this.pourToFraction,
    this.pourSeconds,
    this.description,
  });

  @HiveField(0)
  String name;

  @HiveField(1)
  int seconds;

  @HiveField(2)
  double? pourToFraction;

  @HiveField(3)
  int? pourSeconds;

  @HiveField(4)
  BrewStepKind kind;

  @HiveField(5)
  String? description;

  bool get isPour => pourToFraction != null;

  BrewStep copyWith({
    String? name,
    int? seconds,
    BrewStepKind? kind,
    double? pourToFraction,
    int? pourSeconds,
    String? description,
  }) => BrewStep(
    name: name ?? this.name,
    seconds: seconds ?? this.seconds,
    kind: kind ?? this.kind,
    pourToFraction: pourToFraction ?? this.pourToFraction,
    pourSeconds: pourSeconds ?? this.pourSeconds,
    description: description ?? this.description,
  );
}

@HiveType(typeId: 8)
class BrewRecipe extends HiveObject {
  BrewRecipe({
    String? id,
    required this.name,
    required this.method,
    required this.doseGrams,
    required this.ratio,
    required this.steps,
    this.notes,
    String? alarmSoundName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       alarmSoundName = alarmSoundName ?? AlarmSound.bell.name,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  BrewMethod method;

  @HiveField(3)
  double doseGrams;

  @HiveField(4)
  double ratio;

  @HiveField(5)
  List<BrewStep> steps;

  @HiveField(6)
  String? notes;

  @HiveField(7)
  String alarmSoundName;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime updatedAt;

  AlarmSound get alarmSound => AlarmSound.fromString(alarmSoundName);

  /// Water the recipe finishes on, in grams.
  double get totalWater => doseGrams * ratio;

  int get totalWaterGrams => totalWater.round();

  int get totalSeconds => steps.fold(0, (total, step) => total + step.seconds);

  int get pourCount => steps.where((step) => step.isPour).length;

  /// Cumulative scale reading for the pour at [index], or null when that step
  /// pours nothing.
  int? targetGramsAt(int index) {
    final fraction = steps[index].pourToFraction;
    return fraction == null ? null : (fraction * totalWater).round();
  }

  /// Water this pour adds: its target minus the target of the pour before it.
  int? addedGramsAt(int index) {
    final target = targetGramsAt(index);
    if (target == null) return null;
    for (var i = index - 1; i >= 0; i--) {
      final earlier = targetGramsAt(i);
      if (earlier != null) return target - earlier;
    }
    return target;
  }

  /// Pour speed in grams per second, or null when the step has no pour window.
  double? pourRateAt(int index) {
    final added = addedGramsAt(index);
    final window = steps[index].pourSeconds;
    if (added == null || window == null || window <= 0) return null;
    return added / window;
  }

  /// Human-readable reasons this recipe cannot be saved. Empty means valid.
  List<String> validationErrors() {
    final errors = <String>[];
    if (name.trim().isEmpty) {
      errors.add('Name cannot be empty.');
    }
    if (doseGrams <= 0) {
      errors.add('Dose must be greater than 0g.');
    }
    if (ratio <= 0) {
      errors.add('Ratio must be greater than 0.');
    }
    if (steps.isEmpty) {
      errors.add('A brew needs at least one step.');
    }

    var previousFraction = 0.0;
    var sawPour = false;
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final label = 'Step ${i + 1} (${step.name.trim()})';
      if (step.seconds <= 0) {
        errors.add('$label must be longer than 0s.');
      }
      final fraction = step.pourToFraction;
      if (fraction == null) {
        continue;
      }
      sawPour = true;
      if (fraction < previousFraction) {
        errors.add('$label pours to less water than the step before it.');
      }
      if (fraction > 1) {
        errors.add('$label pours past the total water.');
      }
      previousFraction = fraction;
      final window = step.pourSeconds;
      if (window == null || window <= 0) {
        errors.add('$label needs a pour time.');
      } else if (window > step.seconds) {
        errors.add('$label pours for longer than the step lasts.');
      }
    }
    if (sawPour && previousFraction != 1) {
      errors.add('The last pour must reach the full water total.');
    }
    return errors;
  }

  BrewRecipe copyWith({
    String? name,
    BrewMethod? method,
    double? doseGrams,
    double? ratio,
    List<BrewStep>? steps,
    String? notes,
    String? alarmSoundName,
  }) => BrewRecipe(
    id: id,
    name: name ?? this.name,
    method: method ?? this.method,
    doseGrams: doseGrams ?? this.doseGrams,
    ratio: ratio ?? this.ratio,
    steps: steps ?? this.steps,
    notes: notes ?? this.notes,
    alarmSoundName: alarmSoundName ?? this.alarmSoundName,
    createdAt: createdAt,
  );

  /// A deep copy with a fresh id, for cloning a library recipe into the
  /// user's own list.
  BrewRecipe cloneAsNew({String? name}) => BrewRecipe(
    name: name ?? this.name,
    method: method,
    doseGrams: doseGrams,
    ratio: ratio,
    steps: [for (final step in steps) step.copyWith()],
    notes: notes,
    alarmSoundName: alarmSoundName,
  );
}
