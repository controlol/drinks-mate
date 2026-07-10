import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/drink_preset.dart';
import '../models/party_session_price.dart';
import '../repository/party_session_repository.dart';
import '../services/format_service.dart';

const List<String> _kCurrencies = ['EUR', 'USD', 'GBP'];

/// A single drink preset's draft party price — mirrors the mutual
/// exclusivity of [PartySessionPrice] (data-model.md §PartySessionPrice).
class PriceOverrideDraft {
  const PriceOverrideDraft({this.priceMinor, this.currency, this.priceTokens});

  final int? priceMinor;
  final String? currency;
  final int? priceTokens;

  bool get isOverridden => priceMinor != null || priceTokens != null;

  static const none = PriceOverrideDraft();
}

/// Result of the pricing setup/edit sheet — the caller is responsible for
/// persisting it via [PartySessionRepository.setSessionPrices] and
/// [PartySessionRepository.updateTokenConfig].
class PricingSetupResult {
  const PricingSetupResult({
    required this.prices,
    this.tokenName,
    this.tokenValueMinor,
    this.tokenValueCurrency,
  });

  final List<PartySessionPriceInput> prices;
  final String? tokenName;
  final int? tokenValueMinor;
  final String? tokenValueCurrency;
}

/// The per-preset party-price table + token config editor
/// (party-session.md §Editing prices during a session). Used both by the
/// start-session "Configure" step and the active-session "Manage prices"
/// action.
///
/// [presets] is every visible (non-hidden) [DrinkPreset] — the spec does not
/// restrict this to alcoholic presets ("One row per DrinkPreset (excluding
/// hidden ones)").
class PartyPricingSheet extends StatefulWidget {
  const PartyPricingSheet({
    super.key,
    required this.presets,
    required this.existingOverrides,
    this.initialTokenName,
    this.initialTokenValueMinor,
    this.initialTokenValueCurrency,
    required this.defaultCurrency,
  });

  final List<DrinkPreset> presets;
  final List<PartySessionPrice> existingOverrides;
  final String? initialTokenName;
  final int? initialTokenValueMinor;
  final String? initialTokenValueCurrency;
  final String defaultCurrency;

  @override
  State<PartyPricingSheet> createState() => _PartyPricingSheetState();
}

class _PartyPricingSheetState extends State<PartyPricingSheet> {
  late Map<String, PriceOverrideDraft> _drafts;
  late final TextEditingController _tokenNameCtrl;
  late final TextEditingController _tokenValueCtrl;
  late String _tokenValueCurrency;
  String? _tokenNameError;

  @override
  void initState() {
    super.initState();
    _drafts = {
      for (final o in widget.existingOverrides)
        o.drinkPresetId: PriceOverrideDraft(
          priceMinor: o.priceMinor,
          currency: o.currency,
          priceTokens: o.priceTokens,
        ),
    };
    _tokenNameCtrl = TextEditingController(text: widget.initialTokenName);
    _tokenValueCtrl = TextEditingController(
      text: widget.initialTokenValueMinor == null
          ? ''
          : (widget.initialTokenValueMinor! / 100.0).toStringAsFixed(2),
    );
    _tokenValueCurrency =
        widget.initialTokenValueCurrency ?? widget.defaultCurrency;
  }

  @override
  void dispose() {
    _tokenNameCtrl.dispose();
    _tokenValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _editRow(DrinkPreset preset) async {
    final current = _drafts[preset.id] ?? PriceOverrideDraft.none;
    final result = await showDialog<PriceOverrideDraft>(
      context: context,
      builder: (_) => _PriceOverrideDialog(
        preset: preset,
        initial: current,
        defaultCurrency: widget.defaultCurrency,
      ),
    );
    if (result != null) {
      setState(() => _drafts[preset.id] = result);
    }
  }

  void _save() {
    final prices = <PartySessionPriceInput>[];
    for (final preset in widget.presets) {
      final draft = _drafts[preset.id];
      final hadExisting = widget.existingOverrides.any(
        (o) => o.drinkPresetId == preset.id,
      );
      if (draft != null && (draft.isOverridden || hadExisting)) {
        prices.add(
          PartySessionPriceInput(
            drinkPresetId: preset.id,
            priceMinor: draft.priceMinor,
            currency: draft.currency,
            priceTokens: draft.priceTokens,
          ),
        );
      }
    }
    final rawTokenName = _tokenNameCtrl.text.trim();
    String? tokenName;
    if (rawTokenName.isNotEmpty) {
      // Mirrors PartySessionRepository.updateTokenConfig's own
      // normalise-then-validate so a name accepted here is guaranteed to be
      // accepted there — a rejected name must never reach the repository as
      // an unhandled ArgumentError (Parity Rulebook §Username rules: same
      // whitelist as tokenName, 1–30 chars).
      final normalized = normalizeNfc(rawTokenName);
      final validation = validateUsername(normalized, minLength: 1);
      if (!validation.isValid) {
        setState(() => _tokenNameError = validation.error);
        return;
      }
      tokenName = normalized;
    }
    setState(() => _tokenNameError = null);

    final tokenValue = double.tryParse(_tokenValueCtrl.text);
    Navigator.of(context).pop(
      PricingSetupResult(
        prices: prices,
        tokenName: tokenName,
        tokenValueMinor: tokenValue == null ? null : (tokenValue * 100).round(),
        tokenValueCurrency: tokenValue == null ? null : _tokenValueCurrency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Party prices',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Text(
                    'Token name (optional)',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tokenNameCtrl,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Token',
                      errorText: _tokenNameError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Token value (optional)',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _tokenValueCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*$'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: '1 token =',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _tokenValueCurrency,
                        items: _kCurrencies
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _tokenValueCurrency = v);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  for (final preset in widget.presets)
                    _PresetPriceRow(
                      preset: preset,
                      draft: _drafts[preset.id] ?? PriceOverrideDraft.none,
                      onTap: () => _editRow(preset),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetPriceRow extends StatelessWidget {
  const _PresetPriceRow({
    required this.preset,
    required this.draft,
    required this.onTap,
  });

  final DrinkPreset preset;
  final PriceOverrideDraft draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final regularText =
        preset.regularPriceMinor != null && preset.regularCurrency != null
            ? FormatService.formatPriceValue(
                preset.regularPriceMinor!,
                preset.regularCurrency!,
              )
            : 'No regular price';
    final partyText = draft.priceTokens != null
        ? '${draft.priceTokens} tokens'
        : draft.priceMinor != null && draft.currency != null
            ? FormatService.formatPriceValue(draft.priceMinor!, draft.currency!)
            : 'Regular price';
    return ListTile(
      onTap: onTap,
      title: Text(preset.name),
      subtitle: Text('Regular: $regularText'),
      trailing: Text(partyText, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _PriceOverrideDialog extends StatefulWidget {
  const _PriceOverrideDialog({
    required this.preset,
    required this.initial,
    required this.defaultCurrency,
  });

  final DrinkPreset preset;
  final PriceOverrideDraft initial;
  final String defaultCurrency;

  @override
  State<_PriceOverrideDialog> createState() => _PriceOverrideDialogState();
}

enum _PriceMode { regular, money, tokens }

class _PriceOverrideDialogState extends State<_PriceOverrideDialog> {
  late _PriceMode _mode;
  late final TextEditingController _amountCtrl;
  late String _currency;

  @override
  void initState() {
    super.initState();
    _mode = widget.initial.priceTokens != null
        ? _PriceMode.tokens
        : widget.initial.priceMinor != null
            ? _PriceMode.money
            : _PriceMode.regular;
    final initialAmount = widget.initial.priceTokens?.toString() ??
        (widget.initial.priceMinor == null
            ? ''
            : (widget.initial.priceMinor! / 100.0).toStringAsFixed(2));
    _amountCtrl = TextEditingController(text: initialAmount);
    _currency = widget.initial.currency ?? widget.defaultCurrency;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    switch (_mode) {
      case _PriceMode.regular:
        Navigator.of(context).pop(PriceOverrideDraft.none);
      case _PriceMode.money:
        final major = double.tryParse(_amountCtrl.text);
        if (major == null) return;
        Navigator.of(context).pop(
          PriceOverrideDraft(
            priceMinor: (major * 100).round(),
            currency: _currency,
          ),
        );
      case _PriceMode.tokens:
        final tokens = int.tryParse(_amountCtrl.text);
        if (tokens == null) return;
        Navigator.of(context).pop(PriceOverrideDraft(priceTokens: tokens));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.preset.name),
      content: RadioGroup<_PriceMode>(
        groupValue: _mode,
        onChanged: (v) => setState(() => _mode = v!),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RadioListTile<_PriceMode>(
              contentPadding: EdgeInsets.zero,
              title: Text('Regular price'),
              value: _PriceMode.regular,
            ),
            const RadioListTile<_PriceMode>(
              contentPadding: EdgeInsets.zero,
              title: Text('Money'),
              value: _PriceMode.money,
            ),
            const RadioListTile<_PriceMode>(
              contentPadding: EdgeInsets.zero,
              title: Text('Tokens'),
              value: _PriceMode.tokens,
            ),
            if (_mode != _PriceMode.regular) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: _mode == _PriceMode.tokens
                          ? TextInputType.number
                          : const TextInputType.numberWithOptions(
                              decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          _mode == _PriceMode.tokens
                              ? RegExp(r'^\d*$')
                              : RegExp(r'^\d*\.?\d*$'),
                        ),
                      ],
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText:
                            _mode == _PriceMode.tokens ? 'Count' : 'Amount',
                      ),
                    ),
                  ),
                  if (_mode == _PriceMode.money) ...[
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _currency,
                      items: _kCurrencies
                          .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _currency = v);
                      },
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Done')),
      ],
    );
  }
}
