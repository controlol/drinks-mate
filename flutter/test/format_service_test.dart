// Tests for FormatService — display-boundary conversions reading UserPreferences.
//
// We test FormatService directly (not through the Riverpod provider) by
// constructing UserPreferences stubs. This avoids an in-memory Drift database
// and keeps the tests fast and deterministic.
//
// Currency formatting pins locale to 'en_US' so symbol-position and
// decimal-separator checks are deterministic regardless of the host machine's
// locale.

import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/services/format_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Stub helpers
// ---------------------------------------------------------------------------

UserPreferences _prefs({String units = 'metric', String currency = 'EUR'}) {
  final now = DateTime.utc(2026, 1, 1);
  return UserPreferences(
    id: 'test',
    dailyGoalMl: 2000,
    dayBoundaryHour: 5,
    units: units,
    currency: currency,
    reminderEnabled: true,
    reminderStartHour: 8,
    reminderEndHour: 22,
    reminderIntervalMin: 90,
    inactivityReminderEnabled: true,
    weeklySummaryEnabled: true,
    bacOnLockScreenEnabled: false,
    approachingCapNotifEnabled: false,
    soberEstimateNotifEnabled: false,
    alcoholicPresetsAlwaysVisible: true,
    installedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  // -------------------------------------------------------------------------
  // formatVolume
  // -------------------------------------------------------------------------

  group('FormatService.formatVolume — metric', () {
    late FormatService svc;
    setUp(() => svc = FormatService(_prefs(units: 'metric')));

    test('rounds ml to nearest integer', () {
      expect(svc.formatVolume(240.0), equals('240 ml'));
    });

    test('rounds fractional ml', () {
      expect(svc.formatVolume(240.6), equals('241 ml'));
    });

    test('zero', () {
      expect(svc.formatVolume(0), equals('0 ml'));
    });
  });

  group('FormatService.formatVolume — imperial', () {
    late FormatService svc;
    setUp(() => svc = FormatService(_prefs(units: 'imperial')));

    test('240 ml → 8.1 fl oz', () {
      // 240 / 29.5735295625 = 8.1153..., rounds to 8.1
      expect(svc.formatVolume(240.0), equals('8.1 fl oz'));
    });

    test('355 ml → 12.0 fl oz', () {
      // 355 / 29.5735295625 = 12.0039..., rounds to 12.0
      expect(svc.formatVolume(355.0), equals('12.0 fl oz'));
    });

    test('zero', () {
      expect(svc.formatVolume(0), equals('0.0 fl oz'));
    });
  });

  // -------------------------------------------------------------------------
  // formatLargeVolume
  // -------------------------------------------------------------------------

  group('FormatService.formatLargeVolume — metric', () {
    late FormatService svc;
    setUp(() => svc = FormatService(_prefs(units: 'metric')));

    test('zero', () {
      expect(svc.formatLargeVolume(0), equals('0 L'));
    });

    test('sub-1000ml still renders as litres, not ml', () {
      expect(svc.formatLargeVolume(240.0), equals('0.2 L'));
    });

    test('500 ml → 0.5 L', () {
      expect(svc.formatLargeVolume(500.0), equals('0.5 L'));
    });

    test('1400 ml → 1.4 L', () {
      expect(svc.formatLargeVolume(1400.0), equals('1.4 L'));
    });

    test('whole litres omit the trailing .0 (2000 ml → 2 L)', () {
      expect(svc.formatLargeVolume(2000.0), equals('2 L'));
    });

    // Regression: formatLargeVolume used to compare the *unrounded*
    // ml/1000 double against its truncation to decide whether to omit the
    // trailing ".0". That missed values that round UP to a whole litre at
    // 1dp but aren't an exact multiple of 1000 ml. The fix rounds to 1dp
    // first (`(ml / 1000).toStringAsFixed(1)`), then checks if *that*
    // rounded value is a whole litre. Source: Parity Rulebook → "Metric
    // display precision — daily-progress headline" (1 decimal place,
    // trailing ".0" omitted for whole litres).
    group('near-whole-litre rounding (regression)', () {
      // Each of these divides to a value in [1.95, 2.05) that rounds to
      // "2.0" at 1dp — verified directly via
      // `(ml/1000).toStringAsFixed(1)` (not back-filled from the old,
      // buggy output) before being asserted here.
      for (final ml in [1970.0, 1980.0, 1995.0, 2030.0, 2049.0]) {
        test('$ml ml rounds up to whole litres → 2 L', () {
          expect(svc.formatLargeVolume(ml), equals('2 L'));
        });
      }

      test('1949 ml stays below the rounding boundary → 1.9 L', () {
        // 1949 / 1000 = 1.949 → "1.9" at 1dp; sits just below the
        // round-up-to-2 boundary, confirming the fix doesn't over-collapse
        // near-2 values that should stay at 1.9.
        expect(svc.formatLargeVolume(1949.0), equals('1.9 L'));
      });

      test(
        '1950 ml (exact half-boundary) → 1.9 L, not 2 L',
        () {
          // 1950 / 1000 = 1.95 exactly as a *mathematical* value, but the
          // nearest representable double is fractionally below 1.95, so
          // Dart's `toStringAsFixed(1)` rounds it DOWN to "1.9" rather than
          // "2.0" (round-half-away-from-zero only applies to values that
          // are exactly representable at the half boundary; verified
          // directly against `(1950.0 / 1000).toStringAsFixed(1)`, not
          // assumed from IEEE-754 half-to-even reasoning). This is the
          // sharpest edge of the fix: it proves the implementation is
          // rounding the *actual* double, not doing decimal-exact math.
          expect(svc.formatLargeVolume(1950.0), equals('1.9 L'));
        },
      );

      test('999 ml rounds up to a whole litre from below → 1 L', () {
        // 999 / 1000 = 0.999, rounds to 1.0 at 1dp — mirrors the "rounds up
        // to whole" case one order of magnitude down.
        expect(svc.formatLargeVolume(999.0), equals('1 L'));
      });
    });
  });

  group('FormatService.formatLargeVolume — imperial', () {
    late FormatService svc;
    setUp(() => svc = FormatService(_prefs(units: 'imperial')));

    test('zero', () {
      expect(svc.formatLargeVolume(0), equals('0.0 fl oz'));
    });

    test('240 ml → 8.1 fl oz', () {
      expect(svc.formatLargeVolume(240.0), equals('8.1 fl oz'));
    });

    test('2000 ml → 67.6 fl oz', () {
      // 2000 / 29.5735295625 = 67.628..., rounds to 67.6
      expect(svc.formatLargeVolume(2000.0), equals('67.6 fl oz'));
    });
  });

  // -------------------------------------------------------------------------
  // formatMass
  // -------------------------------------------------------------------------

  group('FormatService.formatMass — metric', () {
    late FormatService svc;
    setUp(() => svc = FormatService(_prefs(units: 'metric')));

    test('shows one decimal place', () {
      expect(svc.formatMass(70.0), equals('70.0 kg'));
    });

    test('fractional kg', () {
      expect(svc.formatMass(65.5), equals('65.5 kg'));
    });
  });

  group('FormatService.formatMass — imperial', () {
    late FormatService svc;
    setUp(() => svc = FormatService(_prefs(units: 'imperial')));

    test('70 kg → 154.3 lb', () {
      // 70 * 2.20462262185 = 154.3235..., rounds to 154.3
      expect(svc.formatMass(70.0), equals('154.3 lb'));
    });

    test('50 kg → 110.2 lb', () {
      // 50 * 2.20462262185 = 110.2311..., rounds to 110.2
      expect(svc.formatMass(50.0), equals('110.2 lb'));
    });

    test('zero', () {
      expect(svc.formatMass(0), equals('0.0 lb'));
    });
  });

  // -------------------------------------------------------------------------
  // formatHeight
  // -------------------------------------------------------------------------

  group('FormatService.formatHeight — metric', () {
    late FormatService svc;
    setUp(() => svc = FormatService(_prefs(units: 'metric')));

    test('shows one decimal place', () {
      expect(svc.formatHeight(175.0), equals('175.0 cm'));
    });

    test('fractional cm', () {
      expect(svc.formatHeight(175.5), equals('175.5 cm'));
    });
  });

  group('FormatService.formatHeight — imperial', () {
    late FormatService svc;
    setUp(() => svc = FormatService(_prefs(units: 'imperial')));

    test('180 cm → 5 ft 11 in', () {
      // 180 / 2.54 = 70.866..., rounds to 71 in → 5 ft 11 in
      expect(svc.formatHeight(180.0), equals('5 ft 11 in'));
    });

    test('152.4 cm → 5 ft 0 in', () {
      // 152.4 / 2.54 = 60.0 exactly → 5 ft 0 in
      expect(svc.formatHeight(152.4), equals('5 ft 0 in'));
    });

    test('30.48 cm → 1 ft 0 in', () {
      // 30.48 / 2.54 = 12.0 exactly → 1 ft 0 in
      expect(svc.formatHeight(30.48), equals('1 ft 0 in'));
    });
  });

  // -------------------------------------------------------------------------
  // formatPrice
  // -------------------------------------------------------------------------

  group('FormatService.formatPrice', () {
    // All formatPrice tests pin locale to 'en_US' for deterministic output.
    // The Parity Rulebook states symbol position and decimal separator follow
    // device locale; en_US gives prefix-symbol with '.' decimal separator.
    late FormatService svc;
    setUp(() => svc = FormatService(_prefs(currency: 'EUR')));

    test('EUR: 250 minor units → €2.50 (en_US locale)', () {
      expect(svc.formatPrice(250, 'EUR', locale: 'en_US'), equals('€2.50'));
    });

    test('EUR: 0 minor units → €0.00', () {
      expect(svc.formatPrice(0, 'EUR', locale: 'en_US'), equals('€0.00'));
    });

    test('USD: 999 minor units → \$9.99', () {
      expect(svc.formatPrice(999, 'USD', locale: 'en_US'), equals('\$9.99'));
    });

    test('GBP: 800 minor units → £8.00', () {
      expect(svc.formatPrice(800, 'GBP', locale: 'en_US'), equals('£8.00'));
    });

    test('EUR: 4250 minor units → €42.50', () {
      // Covers the grouped-currency example from data-model.md §Currency.
      expect(svc.formatPrice(4250, 'EUR', locale: 'en_US'), equals('€42.50'));
    });

    test('GBP: 4200 minor units → £42.00', () {
      // Matches the "€42.50 + £8.00" multi-currency example in Parity Rulebook.
      expect(svc.formatPrice(4200, 'GBP', locale: 'en_US'), equals('£42.00'));
    });

    test('integer minor units avoid floating-point drift in totals', () {
      // Rulebook: "Money is always stored in the minor unit as an integer …
      // This avoids floating-point rounding in totals."
      // 10 × 33 minor units = 330 minor units = €3.30, not €3.2999…
      final total = List.generate(10, (_) => 33).reduce((a, b) => a + b);
      expect(total, equals(330));
      expect(svc.formatPrice(total, 'EUR', locale: 'en_US'), equals('€3.30'));
    });

    test(
      'locale parameter affects symbol position and decimal separator (de_DE)',
      () {
        // Parity Rulebook: "symbol position & decimal separator follow device
        // locale conventions, not the currency."
        // de_DE: decimal separator is ',', symbol follows the amount.
        final result = svc.formatPrice(250, 'EUR', locale: 'de_DE');
        // Verify the decimal separator is a comma and the symbol is present.
        expect(result, contains('2,50'));
        expect(result, contains('€'));
        // In de_DE the symbol appears after the amount, not before it.
        final euroIndex = result.indexOf('€');
        final amountIndex = result.indexOf('2');
        expect(
          euroIndex > amountIndex,
          isTrue,
          reason: 'In de_DE locale, € symbol should follow the amount',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Storage invariant: metric values are never written to DB from FormatService
  // -------------------------------------------------------------------------

  group('FormatService does not write to storage', () {
    // FormatService is read-only — it only formats values for display.
    // This test confirms that formatVolume/formatMass/formatHeight/formatPrice
    // return strings without mutating the underlying preferences object.

    test('formatting does not change the prefs object', () {
      final prefs = _prefs(units: 'imperial', currency: 'USD');
      final svc = FormatService(prefs);

      // Call all formatters — none of them should throw or mutate prefs.
      svc.formatVolume(500);
      svc.formatMass(70);
      svc.formatHeight(175);
      svc.formatPrice(1000, 'USD', locale: 'en_US');

      // prefs is still unmodified — units is still 'imperial', currency 'USD'.
      expect(prefs.units, equals('imperial'));
      expect(prefs.currency, equals('USD'));
    });
  });
}
