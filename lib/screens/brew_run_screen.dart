import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../controllers/brew_run_controller.dart';
import '../models/brew_recipe.dart';
import '../services/brew_session_service.dart';
import '../theme/brew_theme.dart';

class BrewRunScreen extends StatefulWidget {
  const BrewRunScreen({required this.recipe, this.controller, super.key});

  final BrewRecipe recipe;

  /// Test seam: production borrows the controller from [BrewSessionService].
  final BrewRunController? controller;

  @override
  State<BrewRunScreen> createState() => _BrewRunScreenState();
}

class _BrewRunScreenState extends State<BrewRunScreen> {
  // The session service owns the production controller, so popping this
  // screen minimizes a running brew instead of killing it.
  // Claiming the session writes to the service's signal, so it happens in
  // initState — a write during build would mark the tree dirty mid-build.
  late final BrewRunController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? BrewSessionService().obtain(widget.recipe);
  }

  String _clock(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      // A running brew survives the pop (the floater offers the way back);
      // an unstarted or finished one has nothing to keep alive.
      BrewSessionService().releaseIfIdle();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BrewTheme.themeFor(Theme.of(context).brightness);
    final palette = BrewTheme.paletteFor(Theme.of(context).brightness);

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: palette.paper,
        appBar: AppBar(
          backgroundColor: palette.paper,
          foregroundColor: palette.ink,
          elevation: 0,
          // Popping minimizes: a running brew keeps ticking in the session
          // service and the floating chip brings it back.
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            tooltip: 'Minimize',
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.recipe.name),
        ),
        body: SafeArea(
          child: SignalBuilder(
            builder: (_) {
              if (_controller.isFinished.value) {
                return Center(
                  child: Text(
                    'Brew complete',
                    style: TextStyle(fontSize: 28, color: palette.ink),
                  ),
                );
              }

              final target = _controller.currentTarget;
              final added = _controller.currentAdded;
              final rate = _controller.currentRate;
              final next = _controller.nextStepLabel;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _controller.currentStep.name,
                      style: TextStyle(fontSize: 20, color: palette.inkSoft),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      target == null
                          ? _controller.currentStep.kind.displayName
                          : 'pour to ${target}g',
                      style: TextStyle(
                        fontSize: 48,
                        height: 1.1,
                        letterSpacing: -1.9,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (added != null)
                      Text(
                        rate == null
                            ? '+${added}g'
                            : '+${added}g · ≈${rate.toStringAsFixed(1)} g/s',
                        style: TextStyle(fontSize: 16, color: palette.inkSoft),
                      ),
                    if (_controller.currentStep.description != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _controller.currentStep.description!,
                        style: TextStyle(fontSize: 15, color: palette.inkSoft),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (_controller.currentStep.isPour)
                      Text(
                        _controller.isPouring ? 'POUR' : 'WAIT',
                        style: TextStyle(
                          fontSize: 32,
                          letterSpacing: 4,
                          color:
                              _controller.isPouring
                                  ? palette.lead
                                  : palette.inkSoft,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      _clock(_controller.stepRemaining),
                      style: TextStyle(fontSize: 64, color: palette.ink),
                    ),
                    Text(
                      'total ${_clock(_controller.totalElapsed)}',
                      style: TextStyle(fontSize: 14, color: palette.inkSoft),
                    ),
                    const SizedBox(height: 16),
                    if (next != null)
                      Text(
                        'next: $next',
                        style: TextStyle(fontSize: 15, color: palette.inkSoft),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _controller.isRunning.value
                                    ? _controller.pause
                                    : _controller.start,
                            child: Text(
                              _controller.isRunning.value ? 'Pause' : 'Start',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: _controller.reset,
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
