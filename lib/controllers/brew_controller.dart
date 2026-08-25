import 'package:get/get.dart';

import '../models/brew_recipe.dart';
import '../routes/app_routes.dart';
import '../services/database_service.dart';

class BrewController extends GetxController {
  final _databaseService = DatabaseService();

  final RxList<BrewRecipe> recipes = <BrewRecipe>[].obs;
  final RxBool isLoading = true.obs;

  /// The recipe a brand-new brew starts from: one bloom, one pour, a drawdown.
  static BrewRecipe starterRecipe() => BrewRecipe(
    name: 'New Brew',
    method: BrewMethod.v60,
    doseGrams: 18,
    ratio: 16,
    steps: [
      BrewStep(name: 'Bloom', seconds: 45, pourToFraction: 0.12, pourSeconds: 10),
      BrewStep(name: 'Main pour', seconds: 60, pourToFraction: 1, pourSeconds: 30),
      BrewStep(name: 'Drawdown', seconds: 60, kind: BrewStepKind.drawdown),
    ],
  );

  @override
  void onInit() {
    super.onInit();
    loadRecipes();
  }

  Future<void> loadRecipes() async {
    isLoading.value = true;
    try {
      final stored = await _databaseService.getAllBrewRecipes();
      stored.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      recipes.assignAll(stored);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load brews: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshRecipes() => loadRecipes();

  Future<void> addNewBrew() async {
    // GetX builds every named route as `GetPageRoute<dynamic>`, so pushing with
    // a concrete result type throws inside `Navigator.pushNamed`. Push untyped
    // and narrow the result here.
    final result = await Get.toNamed<dynamic>(
      Routes.editBrew,
      arguments: (recipe: starterRecipe(), isNew: true),
    );

    if (result == true) {
      await refreshRecipes();
    }
  }

  Future<void> editBrew(BrewRecipe recipe) async {
    final result = await Get.toNamed<dynamic>(
      Routes.editBrew,
      arguments: (recipe: recipe, isNew: false),
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
      Get.snackbar('Error', 'Failed to delete brew: $e');
    }
  }

  Future<void> addFromTemplate(BrewRecipe template) async {
    try {
      await _databaseService.createBrewRecipe(template.cloneAsNew());
      await refreshRecipes();
      Get.snackbar('Added', '"${template.name}" is in your brews');
    } catch (e) {
      Get.snackbar('Error', 'Failed to add brew: $e');
    }
  }
}
