import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../controllers/brew_controller.dart';
import '../models/brew_recipe.dart';
import '../routes/app_pages.dart';
import '../routes/app_routes.dart';
import '../services/database_service.dart';
import '../services/locator.dart';
import '../services/ui_messenger.dart';
import '../theme/brew_theme.dart';

class BrewListScreen extends StatelessWidget {
  const BrewListScreen({super.key});

  static String _duration(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  static String _ratio(double ratio) {
    if (ratio.truncateToDouble() == ratio) {
      return ratio.toStringAsFixed(0);
    }
    final twoDecimals = ratio.toStringAsFixed(2);
    return twoDecimals.endsWith('0') ? ratio.toStringAsFixed(1) : twoDecimals;
  }

  Future<void> _confirmDelete(
    BrewController controller,
    BrewRecipe recipe,
  ) async {
    final confirmed = await UiMessenger().confirm(
      title: 'Delete Brew',
      message: 'Are you sure you want to delete "${recipe.name}"?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed) {
      await controller.deleteBrew(recipe.id);
    }
  }

  void _openLibrary(
    BuildContext context,
    BrewController controller,
    BrewPalette palette,
  ) {
    final templates = DatabaseService().getBrewTemplates();
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder:
            (sheetContext) => Material(
              color: palette.paperRaised,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Brew Library',
                        style: TextStyle(fontSize: 22, color: palette.ink),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final template in templates)
                      ListTile(
                        title: Text(
                          template.name,
                          style: TextStyle(color: palette.ink),
                        ),
                        subtitle: Text(
                          '${template.method.displayName} · '
                          '${template.totalWaterGrams}g · '
                          '${_duration(template.totalSeconds)}',
                          style: TextStyle(color: palette.inkSoft),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          unawaited(controller.addFromTemplate(template));
                        },
                      ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = locator<BrewController>();
    final brightness = Theme.of(context).brightness;
    final palette = BrewTheme.paletteFor(brightness);

    return Theme(
      data: BrewTheme.themeFor(brightness),
      child: Scaffold(
        backgroundColor: palette.paper,
        body: SafeArea(
          bottom: false,
          child: SignalBuilder(
            builder:
                (_) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  children: [
                    Text(
                      'Brew',
                      style: TextStyle(
                        fontSize: 34,
                        letterSpacing: -1.9,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed:
                          () => _openLibrary(context, controller, palette),
                      icon: const Icon(CupertinoIcons.book, size: 16),
                      label: const Text('Brew Library'),
                    ),
                    const SizedBox(height: 20),
                    for (final recipe in controller.recipes)
                      Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: InkWell(
                          onTap:
                              () => unawaited(
                                AppPages.push<dynamic>(
                                  Routes.brew,
                                  extra: recipe,
                                ),
                              ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        recipe.name,
                                        style: TextStyle(
                                          fontSize: 19,
                                          color: palette.ink,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        CupertinoIcons.pencil,
                                        size: 18,
                                      ),
                                      color: palette.inkSoft,
                                      onPressed:
                                          () => unawaited(
                                            controller.editBrew(recipe),
                                          ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        CupertinoIcons.trash,
                                        size: 18,
                                      ),
                                      color: palette.inkSoft,
                                      onPressed:
                                          () => unawaited(
                                            _confirmDelete(controller, recipe),
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${recipe.method.displayName} · '
                                  '${recipe.doseGrams.toStringAsFixed(0)}g · '
                                  '1:${_ratio(recipe.ratio)} · '
                                  '${recipe.totalWaterGrams}g · '
                                  '${_duration(recipe.totalSeconds)}',
                                  style: TextStyle(color: palette.inkSoft),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${recipe.pourCount} pours · '
                                  'bloom ${recipe.targetGramsAt(0) ?? 0}g '
                                  '→ ${recipe.totalWaterGrams}g',
                                  style: TextStyle(
                                    color: palette.inkSoft,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}
