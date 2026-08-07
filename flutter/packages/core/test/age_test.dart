// Unit tests for age.dart — age-in-years from a birth date.
//
// Source: engineering/decisions/design-system.md → Appendix: Parity Rulebook,
// "BAC: Watson TBW" row:
//   age_years = floor((today − birthDate) / 365.25)
//
// This is a day-count formula (not naive calendar-year subtraction), so it is
// used both by the Watson TBW model's ageYears input and by the Party Mode
// 18+ gate (settings_screen.dart _PartyModeSection).
//
// All vectors use UTC DateTimes for both birthDate and today, per the
// function's doc comment ("should use the same time zone... mixing them
// would skew the day count by the zone offset"). Expected values were derived
// by hand from the day-count formula itself (today.difference(birthDate).inDays
// / 365.25, floored) — not read off the current implementation's output.

import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('ageYearsFromBirthDate', () {
    test('clean case: 1996-01-01 -> 2026-01-01 => 30', () {
      // days = 10958 (30 calendar years incl. 8 leap days: 1996, 2000, 2004,
      // 2008, 2012, 2016, 2020, 2024). 10958 / 365.25 = 30.008..., floors to 30.
      expect(
        ageYearsFromBirthDate(
          birthDate: DateTime.utc(1996, 1, 1),
          today: DateTime.utc(2026, 1, 1),
        ),
        30,
      );
    });

    test('exact-18-years boundary reads 18', () {
      // birth 1990-06-15 -> today 2008-06-15 (18 calendar years). Every Feb
      // 29 from 1992, 1996, 2000, 2004, and 2008 falls within this window
      // (2008's Feb 29 is before its June 15 anniversary), so the range
      // contains 5 leap days: days = 18*365 + 5 = 6575.
      // 6575 / 365.25 = 18.0007..., floors to 18 — this birth date
      // accumulates just enough leap days that day-count/365.25 does not lag
      // behind the calendar anniversary, unlike the case below.
      expect(
        ageYearsFromBirthDate(
          birthDate: DateTime.utc(1990, 6, 15),
          today: DateTime.utc(2008, 6, 15),
        ),
        18,
      );
    });

    test('one day before that boundary reads 17', () {
      // Same birth date, today one day earlier (2008-06-14).
      // days = 6574. 6574 / 365.25 = 17.998..., floors to 17.
      expect(
        ageYearsFromBirthDate(
          birthDate: DateTime.utc(1990, 6, 15),
          today: DateTime.utc(2008, 6, 14),
        ),
        17,
      );
    });

    test(
        'leap-year-spanning case: the 365.25 divisor (not naive '
        'calendar-year subtraction) is used', () {
      // birth 2008-07-09 -> today 2026-07-09 is EXACTLY the 18th calendar
      // anniversary (naive "today.year - birthDate.year" subtraction would
      // say 18 here). But this 18-year span only contains 4 leap days
      // (2012, 2016, 2020, 2024 — 2008's own Feb 29 falls before the July 9
      // start of the range and 2028 is not reached), so the actual day count
      // is 6574, one short of 18 * 365.25 = 6574.5.
      // 6574 / 365.25 = 17.9986..., floors to 17 — the formula reads one
      // year "younger" than naive calendar subtraction would on this date,
      // proving the divisor drives the result, not a naive year subtraction.
      expect(
        ageYearsFromBirthDate(
          birthDate: DateTime.utc(2008, 7, 9),
          today: DateTime.utc(2026, 7, 9),
        ),
        17,
      );

      // One day later, the day count (6575) crosses the 6574.5 threshold and
      // the formula catches up to 18 — confirming the divergence above is a
      // genuine boundary effect of the 365.25 divisor, not an off-by-one bug.
      expect(
        ageYearsFromBirthDate(
          birthDate: DateTime.utc(2008, 7, 9),
          today: DateTime.utc(2026, 7, 10),
        ),
        18,
      );
    });
  });
}
