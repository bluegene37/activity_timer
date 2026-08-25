import 'package:get/get.dart';

import '../controllers/brew_run_controller.dart';
import '../models/brew_recipe.dart';
import 'brew_cue_player.dart';

/// Owns the one running brew, decoupled from any screen.
///
/// `BrewRunScreen` borrows its controller from here instead of creating one,
/// so popping the screen no longer kills the brew: the clock, cues, and
/// wakelock live in the controller, and the controller lives here. The
/// floating chip in `MainNavigation` watches [active] to offer the way back.
class BrewSessionService {
  factory BrewSessionService() => _instance;

  BrewSessionService._internal();

  static final BrewSessionService _instance = BrewSessionService._internal();

  /// The controller of the current session, or null when there is none.
  final Rxn<BrewRunController> active = Rxn<BrewRunController>();

  /// True while a brew has been started and has not finished — exactly the
  /// window in which the floater should be visible.
  bool get hasBrewInProgress {
    final controller = active.value;
    if (controller == null || controller.isFinished.value) {
      return false;
    }
    return controller.isRunning.value ||
        controller.elapsedInStepMs.value > 0 ||
        controller.stepIndex.value > 0;
  }

  /// The controller for [recipe] — the existing one when the session already
  /// runs this recipe (reopening resumes, never restarts), a fresh one
  /// otherwise. Starting a different recipe replaces the old session.
  BrewRunController obtain(BrewRecipe recipe, {BrewCuePlayer? cuePlayer}) {
    final current = active.value;
    if (current != null && current.recipe.id == recipe.id) {
      return current;
    }
    clear();
    final controller = BrewRunController(recipe: recipe, cuePlayer: cuePlayer);
    active.value = controller;
    return controller;
  }

  /// Ends the session: cancels the ticker, releases the wakelock, disposes
  /// the cue player.
  void clear() {
    active.value?.onClose();
    active.value = null;
  }

  /// Called when the run screen is popped: a brew that was never started —
  /// or has finished — has nothing worth floating, so let it go.
  void releaseIfIdle() {
    if (!hasBrewInProgress) {
      clear();
    }
  }
}
