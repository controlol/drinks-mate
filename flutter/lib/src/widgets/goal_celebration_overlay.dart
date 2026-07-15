import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';
import '../theme/haptic_tokens.dart';
import '../theme/reduce_motion.dart';

// Full-screen goal-met celebration overlay.
//
// Designer-brief §Goal-met celebration:
//   - Confetti from the app palette (azure + honey, mint accents).
//   - Medium haptic alongside.
//   - Confetti plays for the same 10 s as the overlay itself, which
//     auto-dismisses after 10 s, or immediately on tap — whichever
//     comes first.
//   - Reduce-motion fallback: static "Goal reached!" card, haptic still fires.
//
// Usage: push via showGeneralDialog (or Stack in TodayScreen) then call
// onDismissed when the user taps anywhere or the timer elapses.

const _kAutoDismissDuration = Duration(seconds: 10);

class GoalCelebrationOverlay extends StatefulWidget {
  const GoalCelebrationOverlay({super.key, required this.onDismissed});

  final VoidCallback onDismissed;

  @override
  State<GoalCelebrationOverlay> createState() => _GoalCelebrationOverlayState();
}

class _GoalCelebrationOverlayState extends State<GoalCelebrationOverlay> {
  ConfettiController? _confetti;
  Timer? _autoDismiss;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    // Haptic fires regardless of reduce-motion (spec: "play only the haptic").
    HapticTokens.onGoalMet();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start confetti + timer only once, after the context is available for
    // ReduceMotion check (cannot call MediaQuery in initState safely).
    if (_confetti == null && _autoDismiss == null) {
      if (!ReduceMotion.isEnabled(context)) {
        _confetti = ConfettiController(duration: _kAutoDismissDuration)..play();
      }
      _autoDismiss = Timer(_kAutoDismissDuration, _dismiss);
    }
  }

  @override
  void dispose() {
    _confetti?.dispose();
    _autoDismiss?.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    if (ReduceMotion.isEnabled(context)) {
      return _ReduceMotionCard(onDismissed: _dismiss);
    }
    final controller = _confetti;
    if (controller == null) {
      // Defensive: reduce-motion state changed between didChangeDependencies
      // and build — fall through to static card rather than crash.
      return _ReduceMotionCard(onDismissed: _dismiss);
    }
    return _ConfettiScreen(controller: controller, onDismissed: _dismiss);
  }
}

// ---------------------------------------------------------------------------
// Normal path — full-screen confetti
// ---------------------------------------------------------------------------

class _ConfettiScreen extends StatelessWidget {
  const _ConfettiScreen({required this.controller, required this.onDismissed});

  final ConfettiController controller;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismissed,
      child: Semantics(
        label: 'Goal reached celebration. Tap to dismiss.',
        child: Container(
          color: Colors.black54,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Confetti bursts from the top-centre.
              ConfettiWidget(
                confettiController: controller,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                gravity: 0.3,
                emissionFrequency: 0.05,
                // Mint permitted in goal-met confetti per color_tokens.dart comment.
                colors: const [
                  kColorAzure,
                  kColorHoney,
                  PartyColorTokens.emerald,
                ],
                shouldLoop: false,
              ),
              // Centred card with message.
              Center(child: _GoalCard()),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reduce-motion path — static card
// ---------------------------------------------------------------------------

class _ReduceMotionCard extends StatelessWidget {
  const _ReduceMotionCard({required this.onDismissed});

  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismissed,
      child: Semantics(
        label: 'Goal reached. Tap to dismiss.',
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: _GoalCard(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card content
// ---------------------------------------------------------------------------

class _GoalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              size: 64,
              color: kColorHoney,
            ),
            const SizedBox(height: 16),
            Text(
              'Goal reached!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: kColorHoney,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Great job staying hydrated today.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
