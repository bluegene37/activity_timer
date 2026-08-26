import 'package:flutter/scheduler.dart';
import 'package:signals/signals.dart';

/// Writes [value] into [target], deferring to the next frame when a build is
/// already in progress.
///
/// A screen claims its session in `initState`, which runs *during* the build
/// of the new route. Publishing there would mark widgets that already watch
/// the signal — the floating chip, say — as needing rebuild mid-build, which
/// Flutter rejects. The claim itself is synchronous either way; only the
/// notification waits, and a chip that appears one frame later is invisible
/// to the user.
void setAfterBuild<T>(Signal<T> target, T value) {
  final binding = SchedulerBinding.instance;
  if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
    binding.addPostFrameCallback((_) => target.value = value);
    return;
  }
  target.value = value;
}
