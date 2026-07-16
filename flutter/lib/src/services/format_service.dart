import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/user_preferences.dart';
import '../repository/providers.dart';

/// Display-boundary formatting service — converts metric canonical values to
/// display strings, gated by [UserPreferences.units] and [UserPreferences.currency].
///
/// Source: Parity Rulebook → "Imperial display" and "Currency symbol position &
/// decimal separator".
///
/// Rules:
///   - All storage is metric; imperial conversion occurs only here.
///   - Currency symbol: EUR→€, USD→$, GBP→£.
///   - Symbol position and decimal separator follow the [locale] argument
///     (device locale in production; pinned in tests for determinism).
class FormatService {
  const FormatService(this._prefs);

  final UserPreferences _prefs;

  bool get _isImperial => _prefs.units == 'imperial';

  // ---------------------------------------------------------------------------
  // Volume
  // ---------------------------------------------------------------------------

  /// Format a volume given in millilitres for display.
  ///
  /// Metric:   "240 ml"
  /// Imperial: "8.1 fl oz"
  String formatVolume(double ml) {
    if (_isImperial) {
      final flOz = mlToFlOz(ml);
      return '${_fmt1dp(flOz)} fl oz';
    }
    return '${ml.round()} ml';
  }

  /// Format a large volume (e.g. today's intake or daily goal) for the
  /// daily-progress headline display (today card, history totals).
  ///
  /// Metric:   always litres, regardless of magnitude; 1 decimal place,
  ///           trailing ".0" omitted for whole litres (e.g. "0.2 L",
  ///           "1.4 L", "2 L").
  /// Imperial: always fl oz with 1 decimal place ("47.3 fl oz").
  ///
  /// Source: Parity Rulebook → "Metric display precision — daily-progress
  /// headline".
  String formatLargeVolume(double ml) {
    if (_isImperial) return '${_fmt1dp(mlToFlOz(ml))} fl oz';
    final rounded = double.parse((ml / 1000).toStringAsFixed(1));
    return rounded == rounded.truncateToDouble()
        ? '${rounded.toInt()} L'
        : '${rounded.toStringAsFixed(1)} L';
  }

  // ---------------------------------------------------------------------------
  // Mass
  // ---------------------------------------------------------------------------

  /// Format a mass given in kilograms for display.
  ///
  /// Metric:   "70 kg"
  /// Imperial: "154.3 lb"
  String formatMass(double kg) {
    if (_isImperial) {
      final lb = kgToLb(kg);
      return '${_fmt1dp(lb)} lb';
    }
    return '${kg.toStringAsFixed(1)} kg';
  }

  // ---------------------------------------------------------------------------
  // Height
  // ---------------------------------------------------------------------------

  /// Format a height given in centimetres for display.
  ///
  /// Metric:   "175.0 cm"
  /// Imperial: "5 ft 9 in"
  String formatHeight(double cm) {
    if (_isImperial) {
      final (:feet, :inches) = cmToFtIn(cm);
      return '$feet ft $inches in';
    }
    return '${cm.toStringAsFixed(1)} cm';
  }

  // ---------------------------------------------------------------------------
  // Price
  // ---------------------------------------------------------------------------

  /// Format an integer minor-unit price (e.g. 250 = €2.50) with the
  /// correct currency symbol.
  ///
  /// [currency] must be one of 'EUR', 'USD', 'GBP'.
  /// [locale] controls symbol position and decimal separator; defaults to
  /// the device locale. Pin to e.g. 'en_US' in tests for determinism.
  ///
  /// Parity Rulebook: "symbol position & decimal separator follow platform
  /// locale conventions, not the currency."
  String formatPrice(int minorUnits, String currency, {String? locale}) =>
      formatPriceValue(minorUnits, currency, locale: locale);

  /// Static form of [formatPrice] — doesn't depend on [UserPreferences], so
  /// callers that only need currency formatting (e.g. the Party Session
  /// price editor) don't need a live [FormatService] instance.
  static String formatPriceValue(
    int minorUnits,
    String currency, {
    String? locale,
  }) {
    final symbol = _currencySymbol(currency);
    final major = minorUnits / 100.0;
    final fmt = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: 2,
    );
    return fmt.format(major);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static String _currencySymbol(String currency) {
    return switch (currency) {
      'EUR' => '€',
      'USD' => '\$',
      'GBP' => '£',
      _ => currency,
    };
  }

  static String _fmt1dp(double value) => value.toStringAsFixed(1);
}

/// Riverpod provider that exposes a [FormatService] backed by the live
/// [UserPreferences] singleton.
///
/// Returns `null` while preferences are loading so callers can handle the
/// unresolved state rather than crashing on first frame.
final formatServiceProvider = Provider<FormatService?>((ref) {
  final prefsAsync = ref.watch(userPreferencesProvider);
  return prefsAsync.valueOrNull == null
      ? null
      : FormatService(prefsAsync.requireValue);
});
