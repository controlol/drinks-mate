import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/party_session.dart';
import '../models/user_profile.dart';
import '../repository/party_session_repository.dart';
import '../repository/providers.dart';
import 'party_pricing_sheet.dart';

/// Shared "start a Party Session" flow (party-session.md §Starting a
/// session), used by both the Party tab's own start button
/// ([party_screen.dart]'s `_NoSessionView`) and Today's "Start session" toast
/// action (party-session.md §Logging from Today, issue #85 item #4) — both
/// entry points collect a missing birthday/height, gate on 18+, then run the
/// same post-start pricing prompt.
bool isUnder18(UserProfile? profile) {
  final birthDate = profile?.birthDate;
  if (birthDate == null) return false;
  final age = ageYearsFromBirthDate(
    birthDate: DateTime.parse(birthDate),
    today: DateTime.now(),
  );
  return age < 18;
}

/// Starts a Party Session, collecting/validating the birthday first when the
/// profile doesn't have one yet (party-session.md §Starting a session).
/// Returns the new session, or null if the user cancelled or was blocked by
/// the under-18 gate.
Future<PartySession?> startPartySessionFlow(
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
  } else if (isUnder18(profile)) {
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

  final repo = ref.read(partySessionRepositoryProvider);
  final session = await repo.startSession(startedAt: startedAt);

  if (context.mounted) {
    await _runPricingPrompt(context, ref, session);
  }
  // Re-fetch: the pricing prompt may have written useSessionPrices/token
  // config for this same session, and the caller (e.g. the very next
  // logAlcoholicDrink call) must see those values rather than the
  // now-stale defaults captured before the prompt ran.
  return repo.getSessionById(session.id);
}

/// The pricing step of the start-session flow (party-session.md §Starting a
/// session — pricing prompt): "Skip / Copy from last / Configure". A no-op
/// (session stays at its `useSessionPrices = false` default) if the user
/// skips or dismisses the prompt.
Future<void> _runPricingPrompt(
  BuildContext context,
  WidgetRef ref,
  PartySession session,
) async {
  final repo = ref.read(partySessionRepositoryProvider);
  final lastPricing = await repo.getLastSessionPricing();
  if (!context.mounted) return;

  final choice = await showModalBottomSheet<_PricingPromptChoice>(
    context: context,
    builder: (_) => _PricingPromptSheet(hasLastSession: lastPricing != null),
  );
  if (choice == null || choice == _PricingPromptChoice.skip) return;

  if (choice == _PricingPromptChoice.copyFromLast) {
    if (lastPricing == null) return;
    final prices = lastPricing.prices
        .map(
          (p) => PartySessionPriceInput(
            drinkPresetId: p.drinkPresetId,
            priceMinor: p.priceMinor,
            currency: p.currency,
            priceTokens: p.priceTokens,
          ),
        )
        .toList();
    await repo.setSessionPrices(sessionId: session.id, prices: prices);
    await repo.updateTokenConfig(
      sessionId: session.id,
      tokenName: lastPricing.tokenName,
      tokenValueMinor: lastPricing.tokenValueMinor,
      tokenValueCurrency: lastPricing.tokenValueCurrency,
    );
    await repo.setUseSessionPrices(session.id, prices.isNotEmpty);
    return;
  }

  // _PricingPromptChoice.configure
  if (!context.mounted) return;
  final presets = ref.read(visiblePresetsProvider).valueOrNull ?? [];
  final defaultCurrency =
      ref.read(userPreferencesProvider).valueOrNull?.currency ?? 'EUR';
  final result = await showModalBottomSheet<PricingSetupResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PartyPricingSheet(
      presets: presets,
      existingOverrides: const [],
      defaultCurrency: defaultCurrency,
    ),
  );
  if (result == null) return;
  await repo.setSessionPrices(sessionId: session.id, prices: result.prices);
  await repo.updateTokenConfig(
    sessionId: session.id,
    tokenName: result.tokenName,
    tokenValueMinor: result.tokenValueMinor,
    tokenValueCurrency: result.tokenValueCurrency,
  );
  await repo.setUseSessionPrices(session.id, result.prices.isNotEmpty);
}

enum _PricingPromptChoice { skip, copyFromLast, configure }

class _PricingPromptSheet extends StatelessWidget {
  const _PricingPromptSheet({required this.hasLastSession});

  final bool hasLastSession;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set up party prices?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Track money or tokens for drinks in this session — or skip '
              'and use your regular prices.',
            ),
            const SizedBox(height: 16),
            if (hasLastSession)
              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(_PricingPromptChoice.copyFromLast),
                child: const Text('Copy prices from last session'),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pop(_PricingPromptChoice.configure),
              child: const Text('Configure prices'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_PricingPromptChoice.skip),
              child: const Text('Skip — use regular prices'),
            ),
          ],
        ),
      ),
    );
  }
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
