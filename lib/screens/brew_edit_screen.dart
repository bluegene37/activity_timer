import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/brew_recipe.dart';
import '../services/database_service.dart';
import '../theme/brew_theme.dart';

class BrewEditScreen extends StatefulWidget {
  const BrewEditScreen({required this.recipe, required this.isNew, super.key});

  final BrewRecipe recipe;
  final bool isNew;

  @override
  State<BrewEditScreen> createState() => _BrewEditScreenState();
}

class _BrewEditScreenState extends State<BrewEditScreen> {
  final DatabaseService _database = DatabaseService();
  late final TextEditingController _nameField = TextEditingController(
    text: widget.recipe.name,
  );
  late final TextEditingController _doseField = TextEditingController(
    text: _formatNum(widget.recipe.doseGrams),
  );
  late final TextEditingController _ratioField = TextEditingController(
    text: _formatNum(widget.recipe.ratio),
  );

  /// Displays a whole number bare ('16') and a fractional one as typed
  /// ('16.67'), rather than rounding it to a fixed number of decimals.
  static String _formatNum(num value) {
    final text = value.toString();
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  // Deep copy, not an alias: `widget.recipe` is the exact live instance held
  // by BrewController.recipes (and Hive), so mutating it directly would
  // apply every keystroke immediately with no way to back out on cancel.
  // `copyWith` preserves id/createdAt, so `updateBrewRecipe(_draft)` still
  // overwrites the right row on save.
  late final BrewRecipe _draft = widget.recipe.copyWith(
    steps: [for (final step in widget.recipe.steps) step.copyWith()],
  );
  List<String> _errors = const [];

  double get _totalWater => _draft.doseGrams * _draft.ratio;

  void _onDoseChanged(String value) {
    final dose = double.tryParse(value);
    if (dose == null || dose <= 0) {
      return;
    }
    setState(() {
      // Targets are fractions, so they follow the dose with no rewriting.
      _draft.doseGrams = dose;
    });
  }

  void _onRatioChanged(String value) {
    final ratio = double.tryParse(value);
    if (ratio == null || ratio <= 0) {
      return;
    }
    setState(() => _draft.ratio = ratio);
  }

  /// The editor speaks grams; storage speaks fractions.
  void _setStepTargetGrams(int index, int? grams) {
    setState(() {
      final step = _draft.steps[index];
      if (grams == null) {
        final wasPour = step.kind == BrewStepKind.pour;
        step.pourToFraction = null;
        step.pourSeconds = null;
        // Clearing a target shouldn't demote a swirl or drawdown step that
        // never had a pour kind to begin with.
        if (wasPour) {
          step.kind = BrewStepKind.wait;
        }
      } else {
        // The total is a display-rounded value (500.1g -> "500g"), so typing
        // that rounded total back in has to land on fraction 1.0 exactly --
        // otherwise no integer the user can type ever satisfies the model's
        // strict "last pour reaches the total" invariant.
        step.pourToFraction =
            grams == _draft.totalWaterGrams ? 1.0 : grams / _totalWater;
        step.kind = BrewStepKind.pour;
      }
    });
  }

  void _moveStep(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _draft.steps.length) {
      return;
    }
    setState(() {
      final step = _draft.steps.removeAt(index);
      _draft.steps.insert(target, step);
    });
  }

  Future<void> _save() async {
    _draft.name = _nameField.text.trim();
    final errors = _draft.validationErrors();
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }

    if (widget.isNew) {
      await _database.createBrewRecipe(_draft);
    } else {
      await _database.updateBrewRecipe(_draft);
    }
    Get.back<bool>(result: true);
  }

  @override
  void dispose() {
    _nameField.dispose();
    _doseField.dispose();
    _ratioField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = BrewTheme.paletteFor(Theme.of(context).brightness);

    return Theme(
      data: BrewTheme.themeFor(Theme.of(context).brightness),
      child: Scaffold(
        backgroundColor: palette.paper,
        appBar: AppBar(
          backgroundColor: palette.paper,
          foregroundColor: palette.ink,
          elevation: 0,
          title: Text(widget.isNew ? 'New Brew' : 'Edit Brew'),
          actions: [TextButton(onPressed: _save, child: const Text('Save'))],
        ),
        // SingleChildScrollView + Column, not a lazy ListView: this is a
        // single form whose trailing validation errors are part of the same
        // page as the fields above, and a recipe only ever has a handful of
        // steps, so building all of it eagerly costs nothing measurable.
        // Do not "optimize" this back to a lazy list -- a lazy list only
        // materializes children near the viewport, so it would silently stop
        // rendering the trailing error text (and step rows below the fold)
        // without a scroll.
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('brew-name-field'),
                controller: _nameField,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<BrewMethod>(
                key: const Key('brew-method-field'),
                initialValue: _draft.method,
                decoration: const InputDecoration(labelText: 'Method'),
                items: [
                  for (final method in BrewMethod.values)
                    DropdownMenuItem(
                      value: method,
                      child: Text(method.displayName),
                    ),
                ],
                onChanged: (method) {
                  if (method != null) {
                    setState(() => _draft.method = method);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('brew-dose-field'),
                      controller: _doseField,
                      keyboardType: TextInputType.number,
                      onChanged: _onDoseChanged,
                      decoration: const InputDecoration(labelText: 'Dose (g)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('brew-ratio-field'),
                      controller: _ratioField,
                      keyboardType: TextInputType.number,
                      onChanged: _onRatioChanged,
                      decoration: const InputDecoration(
                        labelText: 'Ratio (1:x)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Total water ${_totalWater.round()}g',
                style: TextStyle(color: palette.inkSoft),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < _draft.steps.length; i++)
                _StepRow(
                  // Keyed by step identity, not position: BrewStep has no ==
                  // override, so this is reference identity. Reorder and
                  // delete shift which index a step sits at; keying by index
                  // would make Flutter reuse the old State object (and its
                  // TextFormField.initialValue, which only seeds on first
                  // build) for the new occupant of that slot, leaving stale
                  // text on screen even though _draft.steps is correct.
                  key: ValueKey(_draft.steps[i]),
                  index: i,
                  step: _draft.steps[i],
                  targetGrams: _draft.targetGramsAt(i),
                  palette: palette,
                  onTargetChanged: (grams) => _setStepTargetGrams(i, grams),
                  onChanged: () => setState(() {}),
                  onDelete: () => setState(() => _draft.steps.removeAt(i)),
                  onMoveUp: () => _moveStep(i, -1),
                  onMoveDown: () => _moveStep(i, 1),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed:
                    () => setState(
                      () => _draft.steps.add(
                        BrewStep(
                          name: 'New step',
                          seconds: 30,
                          kind: BrewStepKind.wait,
                        ),
                      ),
                    ),
                child: const Text('Add step'),
              ),
              if (_errors.isNotEmpty) ...[
                const SizedBox(height: 20),
                for (final error in _errors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(error, style: TextStyle(color: palette.lead)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.step,
    required this.targetGrams,
    required this.palette,
    required this.onTargetChanged,
    required this.onChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    super.key,
  });

  final int index;
  final BrewStep step;
  final int? targetGrams;
  final BrewPalette palette;
  final ValueChanged<int?> onTargetChanged;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: Key('brew-step-$index-name'),
                  initialValue: step.name,
                  decoration: const InputDecoration(labelText: 'Step name'),
                  onChanged: (value) {
                    step.name = value;
                    onChanged();
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed: onMoveUp,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                onPressed: onMoveDown,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: palette.lead,
                onPressed: onDelete,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: Key('brew-step-$index-seconds'),
                  initialValue: step.seconds.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Seconds'),
                  onChanged: (value) {
                    step.seconds = int.tryParse(value) ?? step.seconds;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                // The key carries the gram value so the field redraws when the
                // dose changes and every target rescales.
                child: TextFormField(
                  key: Key('brew-step-$index-target-$targetGrams'),
                  initialValue: targetGrams?.toString() ?? '',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pour to (g)',
                    helperText: 'blank = no pour',
                  ),
                  onChanged: (value) => onTargetChanged(int.tryParse(value)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: Key('brew-step-$index-pour-seconds'),
                  initialValue: step.pourSeconds?.toString() ?? '',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pour secs'),
                  onChanged: (value) {
                    step.pourSeconds = int.tryParse(value);
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          TextFormField(
            key: Key('brew-step-$index-description'),
            initialValue: step.description ?? '',
            decoration: const InputDecoration(labelText: 'Note (optional)'),
            onChanged: (value) {
              step.description = value.trim().isEmpty ? null : value;
              onChanged();
            },
          ),
        ],
      ),
    ),
  );
}
