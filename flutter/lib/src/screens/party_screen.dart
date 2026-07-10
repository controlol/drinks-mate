import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../a11y/semantics_labels.dart';
import '../models/party_session.dart';
import '../models/user_profile.dart';
import '../repository/providers.dart';
import '../services/bac_estimator.dart';
import '../theme/app_theme.dart';
import 'party_log_drink_sheet.dart';
import 'settings_screen.dart';

/// Party tab (S7) — Party Session UI (issue #22).
///
/// Emerald is the Party-Mode-only accent (C5 quarantine rule): every
/// Party-specific action in this file uses [PartyColorTokens], never the
/// general azure/honey accents, and this colour never leaves this screen.
class PartyScreen extends ConsumerWidget {
  const PartyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(activePartySessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Party'),
        actions: [_settingsButton(context)],
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (session) => session == null
            ? const _NoSessionView()
            : _ActiveSessionView(key: ValueKey(session.id), session: session),
      ),
    );
  }
}

Color _emerald(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? PartyColorTokens.emeraldDark
        : PartyColorTokens.emerald;

// ---------------------------------------------------------------------------
// No active session
// ---------------------------------------------------------------------------

class _NoSessionView extends ConsumerWidget {
  const _NoSessionView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final prefs = ref.watch(userPreferencesProvider).valueOrNull;
    final under18 = _isUnder18(profile);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Icon(Icons.local_bar_outlined, size: 48, color: _emerald(context)),
        const SizedBox(height: 12),
        Text(
          'Party Mode',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Track alcoholic drinks during a session and see an estimated '
          'blood alcohol concentration (BAC).',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const _DisclaimerBanner(),
        const SizedBox(height: 24),
        // Only the "Start party session" branch is age-gated (party-session.md
        // §Logging alcohol when no session is active): the age check sits on
        // the "Start party session" arrow, not on "Don't start a session", so
        // an alcoholic drink can always be logged as an orphan regardless of
        // age. "Log alcohol" therefore stays visible even when under18.
        if (under18)
          const _Under18Gate()
        else
          Semantics(
            label: SemanticsLabels.startPartySession,
            button: true,
            excludeSemantics: true,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _emerald(context),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => _startPartySessionFlow(context, ref),
              child: const Text('Start party session'),
            ),
          ),
        const SizedBox(height: 12),
        Semantics(
          label: SemanticsLabels.logAlcoholButton,
          button: true,
          excludeSemantics: true,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _emerald(context),
              side: BorderSide(color: _emerald(context)),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => _handleLogAlcohol(context, ref, null),
            child: const Text('Log alcohol'),
          ),
        ),
        if (!under18 && prefs?.bacCapGramsPerL != null) ...[
          const SizedBox(height: 16),
          Text(
            'Your cap: ${prefs!.bacCapGramsPerL!.toStringAsFixed(2)} g/L '
            '(set in Settings → Party Mode)',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _Under18Gate extends StatelessWidget {
  const _Under18Gate();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: SemanticsLabels.under18Gate,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'Party Mode requires you to be 18 or older.',
                style: Theme.of(context).textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'If you entered your birthday incorrectly, you can update it '
                'in Settings and try again.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isUnder18(UserProfile? profile) {
  final birthDate = profile?.birthDate;
  if (birthDate == null) return false;
  final age = ageYearsFromBirthDate(
    birthDate: DateTime.parse(birthDate),
    today: DateTime.now(),
  );
  return age < 18;
}

// ---------------------------------------------------------------------------
// Active session
// ---------------------------------------------------------------------------

class _ActiveSessionView extends ConsumerStatefulWidget {
  const _ActiveSessionView({required super.key, required this.session});

  final PartySession session;

  @override
  ConsumerState<_ActiveSessionView> createState() => _ActiveSessionViewState();
}

class _ActiveSessionViewState extends ConsumerState<_ActiveSessionView> {
  bool _bmiWarningDismissed = false;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(
      partySessionEntriesProvider(widget.session.id),
    );
    final mealsAsync = ref.watch(partySessionMealsProvider(widget.session.id));
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final prefs = ref.watch(userPreferencesProvider).valueOrNull;

    // profile.birthDate can briefly be null right after a session starts via
    // the birthday-collection dialog (profile write vs. this stream's next
    // emission racing) — show a loading state rather than let
    // estimateSessionBac's precondition throw.
    if (profile == null ||
        profile.birthDate == null ||
        !entriesAsync.hasValue ||
        !mealsAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final alcoholicEntries = entriesAsync.requireValue
        .where((e) => e.beverageType.isAlcoholic)
        .toList();
    final estimate = estimateSessionBac(
      profile: profile,
      alcoholicEntries: alcoholicEntries,
      meals: mealsAsync.requireValue,
      at: now,
    );
    final cap = prefs?.bacCapGramsPerL;
    final approachingCap = cap != null &&
        isApproachingCap(bacGPerL: estimate.gPerL, capGPerL: cap);
    final elapsed = now.difference(widget.session.startedAt);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _BacCard(
          estimate: estimate,
          elapsed: elapsed,
          capGPerL: cap,
          approachingCap: approachingCap,
        ),
        if (estimate.bmiWarning && !_bmiWarningDismissed) ...[
          const SizedBox(height: 12),
          _BmiWarningBanner(
            onDismiss: () {
              setState(() => _bmiWarningDismissed = true);
            },
          ),
        ],
        if (approachingCap) ...[
          const SizedBox(height: 12),
          const _ApproachingCapBanner(),
        ],
        const SizedBox(height: 16),
        Semantics(
          label: SemanticsLabels.logAlcoholButton,
          button: true,
          excludeSemantics: true,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _emerald(context),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => _handleLogAlcohol(context, ref, widget.session),
            child: const Text('Log alcohol'),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: SemanticsLabels.endPartySession,
          button: true,
          excludeSemantics: true,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => _confirmEndSession(context, ref, widget.session),
            child: const Text('End session'),
          ),
        ),
        const SizedBox(height: 16),
        const _DisclaimerBanner(),
      ],
    );
  }
}

class _BacCard extends StatelessWidget {
  const _BacCard({
    required this.estimate,
    required this.elapsed,
    required this.capGPerL,
    required this.approachingCap,
  });

  final BacEstimate estimate;
  final Duration elapsed;
  final double? capGPerL;
  final bool approachingCap;

  @override
  Widget build(BuildContext context) {
    // BAC display precision: 2 decimal places for both g/L and mmol/L,
    // matching party-session.md §Display units' own example
    // ("0.36 g/L (≈ 7.85 mmol/L)"). The Rulebook does not pin BAC display
    // precision explicitly; this choice is documented here for the reviewer.
    final gPerLText = estimate.gPerL.toStringAsFixed(2);
    final mmolText = estimate.mmolPerL.toStringAsFixed(2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: '${SemanticsLabels.bacValue}: $gPerLText g/L, '
                  'approximately $mmolText mmol/L',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$gPerLText g/L',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '≈ $mmolText mmol/L',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'estimate',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            if (capGPerL != null) ...[
              const SizedBox(height: 16),
              _CapReferenceBar(
                bacGPerL: estimate.gPerL,
                capGPerL: capGPerL!,
                approachingCap: approachingCap,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Elapsed: ${_formatElapsed(elapsed)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (estimate.unspecifiedGenderConservative) ...[
              const SizedBox(height: 8),
              Text(
                "Estimate uses a conservative model since gender isn't "
                'specified.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatElapsed(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
}

class _CapReferenceBar extends StatelessWidget {
  const _CapReferenceBar({
    required this.bacGPerL,
    required this.capGPerL,
    required this.approachingCap,
  });

  final double bacGPerL;
  final double capGPerL;
  final bool approachingCap;

  @override
  Widget build(BuildContext context) {
    final scaleMax = [
      bacGPerL,
      capGPerL * 1.25,
      0.01,
    ].reduce((a, b) => a > b ? a : b);
    final bacFraction = (bacGPerL / scaleMax).clamp(0.0, 1.0);
    final capFraction = (capGPerL / scaleMax).clamp(0.0, 1.0);
    final fillColor =
        approachingCap ? kColorWarning : Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal cap: ${capGPerL.toStringAsFixed(2)} g/L',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: bacFraction,
                    child: Container(
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (width * capFraction - 1).clamp(
                      0.0,
                      (width - 2).clamp(0.0, double.infinity),
                    ),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BmiWarningBanner extends StatelessWidget {
  const _BmiWarningBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: SemanticsLabels.bmiWarningBanner,
      child: Material(
        color: kColorWarning.withAlpha(38),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: kColorWarning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'BAC estimates may be less accurate for users outside '
                  'typical body composition ranges.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Dismiss',
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApproachingCapBanner extends StatelessWidget {
  const _ApproachingCapBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: SemanticsLabels.approachingCapBanner,
      child: Material(
        color: kColorWarning.withAlpha(38),
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_outlined,
                size: 18,
                color: kColorWarning,
              ),
              SizedBox(width: 8),
              Expanded(child: Text('Approaching your personal cap')),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: SemanticsLabels.bacDisclaimer,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                SemanticsLabels.bacDisclaimer,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session-start flow (shared by the no-session Start button and the
// log-alcohol "start a session?" prompt)
// ---------------------------------------------------------------------------

/// Starts a Party Session, collecting/validating the birthday first when the
/// profile doesn't have one yet (party-session.md §Starting a session).
/// Returns the new session, or null if the user cancelled or was blocked by
/// the under-18 gate.
Future<PartySession?> _startPartySessionFlow(
  BuildContext context,
  WidgetRef ref, {
  DateTime? startedAt,
}) async {
  final profile = ref.read(userProfileProvider).valueOrNull;
  if (profile == null) return null;

  var birthDate = profile.birthDate;
  var heightCm = profile.heightCm;

  if (birthDate == null) {
    final result = await _showBirthdatePrompt(context);
    if (result == null) return null;
    birthDate = result.birthDateIso;
    heightCm = result.heightCm ?? heightCm;
    await ref.read(preferencesRepositoryProvider).upsertProfile(
          profile.copyWith(birthDate: birthDate, heightCm: heightCm),
        );
  } else if (_isUnder18(profile)) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Party Mode requires you to be 18 or older'),
          content: Text(
            'If you entered your birthday incorrectly, you can update it in '
            'Settings and try again.',
          ),
        ),
      );
    }
    return null;
  }

  return ref
      .read(partySessionRepositoryProvider)
      .startSession(startedAt: startedAt);
}

/// Result of [_showBirthdatePrompt] — a birthday that has already been
/// confirmed to make the user 18+.
class _BirthdatePromptResult {
  const _BirthdatePromptResult({required this.birthDateIso, this.heightCm});

  final String birthDateIso;
  final double? heightCm;
}

Future<_BirthdatePromptResult?> _showBirthdatePrompt(BuildContext context) {
  return showDialog<_BirthdatePromptResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _BirthdateDialog(),
  );
}

class _BirthdateDialog extends StatefulWidget {
  const _BirthdateDialog();

  @override
  State<_BirthdateDialog> createState() => _BirthdateDialogState();
}

class _BirthdateDialogState extends State<_BirthdateDialog> {
  DateTime? _picked;
  final _heightCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked != null) setState(() => _picked = picked);
  }

  void _continue() {
    final picked = _picked;
    if (picked == null) {
      setState(() => _error = 'Please enter your birthday');
      return;
    }
    final age = ageYearsFromBirthDate(birthDate: picked, today: DateTime.now());
    if (age < 18) {
      setState(() {
        _error = 'Party Mode requires you to be 18 or older. If you entered '
            'your birthday incorrectly, you can try again.';
        _picked = null;
      });
      return;
    }
    final heightCm = double.tryParse(_heightCtrl.text);
    Navigator.of(context).pop(
      _BirthdatePromptResult(
        birthDateIso: picked.toIso8601String().substring(0, 10),
        heightCm: heightCm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('When were you born?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Party Mode requires a birthday to estimate BAC.'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _pickDate,
            child: Text(
              _picked == null
                  ? 'Pick birthday'
                  : '${_picked!.year}-${_picked!.month.toString().padLeft(2, '0')}-${_picked!.day.toString().padLeft(2, '0')}',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _heightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Height (optional, improves accuracy)',
              suffixText: 'cm',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _continue, child: const Text('Continue')),
      ],
    );
  }
}

/// The "Start a Party Session first?" prompt (party-session.md §Logging
/// alcohol when no session is active). Returns true to start a session,
/// false to log as an orphan. Null means the dialog was dismissed without an
/// explicit choice (e.g. the Android back gesture, which bypasses
/// `barrierDismissible`) — the caller treats that as cancelling the whole
/// log action, not as an implicit "don't start a session".
Future<bool?> _showStartSessionPrompt(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('Start a Party Session first?'),
      content: const Text(
        'You can track this drink in a Party Session to see an estimated '
        'BAC, or just log it without tracking.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("Don't start a session"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Start party session'),
        ),
      ],
    ),
  );
}

/// Meal prompt shown after each alcoholic drink log (party-session.md
/// §Meals: "A single, skippable prompt"). Returns null on Skip/dismiss.
Future<MealSize?> _showMealPrompt(BuildContext context) {
  return showModalBottomSheet<MealSize>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Did you eat recently?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Small'),
              subtitle: const Text('Snack, sandwich, light salad'),
              onTap: () => Navigator.of(context).pop(MealSize.small),
            ),
            ListTile(
              title: const Text('Medium'),
              subtitle: const Text('Normal meal'),
              onTap: () => Navigator.of(context).pop(MealSize.medium),
            ),
            ListTile(
              title: const Text('Large'),
              subtitle: const Text('Heavy meal'),
              onTap: () => Navigator.of(context).pop(MealSize.large),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Logs [selection] as an orphan drink (no Party Session) and shows a
/// confirmation SnackBar.
Future<void> _logOrphanDrink(
  BuildContext context,
  WidgetRef ref,
  AlcoholicDrinkSelection selection,
) async {
  await ref.read(drinksRepositoryProvider).logDrink(
        preset: selection.preset,
        volumeMl: selection.volumeMl,
        abvPercent: selection.abvPercent,
        consumedAt: selection.consumedAt,
      );
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Drink logged')));
  }
}

/// Orchestrates the whole "Log alcohol" flow: pick a preset (via
/// [PartyLogDrinkSheet]), then — if there's no active [session] — the
/// start-or-orphan prompt, then the actual log call, then the meal prompt.
Future<void> _handleLogAlcohol(
  BuildContext context,
  WidgetRef ref,
  PartySession? session,
) async {
  final selection = await showModalBottomSheet<AlcoholicDrinkSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const PartyLogDrinkSheet(),
  );
  if (selection == null || !context.mounted) return;

  var sessionId = session?.id;
  if (sessionId == null) {
    final startNewSession = await _showStartSessionPrompt(context);
    if (startNewSession == null) return;
    if (!startNewSession) {
      if (context.mounted) await _logOrphanDrink(context, ref, selection);
      return;
    }
    if (!context.mounted) return;
    final newSession = await _startPartySessionFlow(
      context,
      ref,
      startedAt: selection.consumedAt,
    );
    if (newSession == null) {
      // Blocked by the under-18 gate or the birthdate dialog was cancelled —
      // the user already confirmed this drink, so fall back to logging it as
      // an orphan rather than silently discarding it (party-session.md
      // §Logging alcohol when no session is active).
      if (context.mounted) await _logOrphanDrink(context, ref, selection);
      return;
    }
    sessionId = newSession.id;
  }

  await ref.read(partySessionRepositoryProvider).logAlcoholicDrink(
        preset: selection.preset,
        sessionId: sessionId,
        volumeMl: selection.volumeMl,
        abvPercent: selection.abvPercent,
        consumedAt: selection.consumedAt,
      );

  if (!context.mounted) return;
  final mealSize = await _showMealPrompt(context);
  if (mealSize != null) {
    await ref
        .read(partySessionRepositoryProvider)
        .addMeal(sessionId: sessionId, size: mealSize);
  }
}

Future<void> _confirmEndSession(
  BuildContext context,
  WidgetRef ref,
  PartySession session,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('End session?'),
      content: const Text('This ends your current Party Session.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('End session'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref
        .read(partySessionRepositoryProvider)
        .endSession(session.id, PartySessionEndReason.manual);
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

Widget _settingsButton(BuildContext context) => IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Settings',
      onPressed: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      ),
    );
