import 'package:signals/signals_flutter.dart';

import '../models/brew_recipe.dart';
import '../routes/app_pages.dart';
import '../routes/app_routes.dart';
import '../services/database_service.dart';
import '../services/ui_messenger.dart';

class BrewController {
  final _databaseService = DatabaseService();

  final recipes = listSignal<BrewRecipe>([]);
  final isLoading = signal(true);

  /// The recipe a brand-new brew starts from: one bloom, one pour, a drawdown.
  static BrewRecipe starterRecipe() => BrewRecipe(
    name: 'New Brew',
    method: BrewMethod.v60,
    doseGrams: 18,
    ratio: 16,
    steps: [
      BrewStep(
        name: 'Bloom',
        seconds: 45,
        pourToFraction: 0.12,
        pourSeconds: 10,
      ),
      BrewStep(
        name: 'Main pour',
        seconds: 60,
        pourToFraction: 1,
        pourSeconds: 30,
      ),
      BrewStep(name: 'Drawdown', seconds: 60, kind: BrewStepKind.drawdown),
    ],
  );

  void onInit() {
    loadRecipes();
  }

  Future<void> loadRecipes() async {
    isLoading.value = true;
    try {
      final stored = await _databaseService.getAllBrewRecipes();
      stored.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      recipes.value = List.of(stored);
    } catch (e) {
      UiMessenger().showMessage('Failed to load brews: $e', title: 'Error');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshRecipes() => loadRecipes();

  Future<void> addNewBrew() async {
    final result = await AppPages.push<dynamic>(
      Routes.editBrew,
      extra: (recipe: starterRecipe(), isNew: true),
    );

    if (result == true) {
      await refreshRecipes();
    }
  }

  Future<void> editBrew(BrewRecipe recipe) async {
    final result = await AppPages.push<dynamic>(
      Routes.editBrew,
      extra: (recipe: recipe, isNew: false),
    );

    if (result == true) {
      await refreshRecipes();
    }
  }

  Future<void> deleteBrew(String id) async {
    try {
      await _databaseService.deleteBrewRecipe(id);
      recipes.removeWhere((recipe) => recipe.id == id);
    } catch (e) {
      UiMessenger().showMessage('Failed to delete brew: $e', title: 'Error');
    }
  }

  Future<void> addFromTemplate(BrewRecipe template) async {
    try {
      await _databaseService.createBrewRecipe(template.cloneAsNew());
      await refreshRecipes();
      UiMessenger().showMessage(
        '"${template.name}" is in your brews',
        title: 'Added',
      );
    } catch (e) {
      UiMessenger().showMessage('Failed to add brew: $e', title: 'Error');
    }
  }
}
