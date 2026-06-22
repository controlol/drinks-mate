import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  // Source: Parity Rulebook → "Day boundary":
  //   "Default 05:00 local, configurable. A drink's day = the window
  //    [dayBoundary, next dayBoundary) containing its consumedAt (local)."
  // (engineering/decisions/design-system.md → Appendix, Boundary/time rules)

  group('dayWindow (Parity Rulebook — Day boundary)', () {
    // ------------------------------------------------------------------ //
    // Standard mid-day case (well after boundary)                         //
    // ------------------------------------------------------------------ //

    test(
      'now at 10:00 local → window is [today 05:00, tomorrow 05:00]',
      () {
        // Source: Parity Rulebook — Day boundary rule.
        final now = DateTime(2026, 6, 22, 10, 0); // Mon 10:00
        final (start, end) = dayWindow(now: now);

        expect(start, DateTime(2026, 6, 22, 5, 0));
        expect(end, DateTime(2026, 6, 23, 5, 0));
      },
    );

    // ------------------------------------------------------------------ //
    // Before boundary: falls in the previous day's window                 //
    // ------------------------------------------------------------------ //

    test(
      'now at 04:59 local (before 05:00 boundary) → window is [yesterday 05:00, today 05:00]',
      () {
        // Source: Parity Rulebook — Day boundary rule (before-boundary case).
        final now = DateTime(2026, 6, 22, 4, 59); // 04:59, before boundary
        final (start, end) = dayWindow(now: now);

        expect(start, DateTime(2026, 6, 21, 5, 0)); // yesterday 05:00
        expect(end, DateTime(2026, 6, 22, 5, 0)); // today 05:00
      },
    );

    // ------------------------------------------------------------------ //
    // Exactly at boundary: belongs to the NEW day's window                //
    // ------------------------------------------------------------------ //

    test(
      'now exactly at 05:00 local → window is [today 05:00, tomorrow 05:00]',
      () {
        // Source: Parity Rulebook — Day boundary rule.
        // The window is [boundary, next boundary), so the boundary instant
        // itself is the START of the new day (not the end of the previous).
        final now = DateTime(2026, 6, 22, 5, 0); // exactly at boundary
        final (start, end) = dayWindow(now: now);

        expect(start, DateTime(2026, 6, 22, 5, 0));
        expect(end, DateTime(2026, 6, 23, 5, 0));
      },
    );

    // ------------------------------------------------------------------ //
    // Midnight case: 00:30 falls in the previous day's window             //
    // ------------------------------------------------------------------ //

    test(
      'now at 00:30 local (midnight) → falls in previous day\'s window',
      () {
        // Source: Parity Rulebook — Day boundary rule.
        // 00:30 < 05:00 → previous day's window.
        final now = DateTime(2026, 6, 22, 0, 30);
        final (start, end) = dayWindow(now: now);

        expect(start, DateTime(2026, 6, 21, 5, 0)); // yesterday 05:00
        expect(end, DateTime(2026, 6, 22, 5, 0)); // today 05:00
      },
    );

    // ------------------------------------------------------------------ //
    // Custom boundary: 00:00 — standard calendar days                     //
    // ------------------------------------------------------------------ //

    test(
      'custom boundary 00:00: now at 23:00 → window is [today 00:00, tomorrow 00:00]',
      () {
        // Source: Parity Rulebook — Day boundary rule (configurable boundary).
        final now = DateTime(2026, 6, 22, 23, 0);
        final (start, end) = dayWindow(
          now: now,
          boundaryHour: 0,
          boundaryMinute: 0,
        );

        expect(start, DateTime(2026, 6, 22, 0, 0));
        expect(end, DateTime(2026, 6, 23, 0, 0));
      },
    );

    // ------------------------------------------------------------------ //
    // Custom boundaryMinute: 05:30 boundary                               //
    // ------------------------------------------------------------------ //

    test(
      'custom boundary 05:30: now at 05:00 → before boundary, falls in previous window',
      () {
        // Source: Parity Rulebook — Day boundary rule (configurable boundary).
        // 05:00 < 05:30 boundary → still the previous day's window.
        final now = DateTime(2026, 6, 22, 5, 0);
        final (start, end) = dayWindow(
          now: now,
          boundaryHour: 5,
          boundaryMinute: 30,
        );

        expect(start, DateTime(2026, 6, 21, 5, 30)); // yesterday 05:30
        expect(end, DateTime(2026, 6, 22, 5, 30)); // today 05:30
      },
    );

    test(
      'custom boundary 05:30: now at 05:30 → exactly at boundary, new window starts',
      () {
        // Source: Parity Rulebook — Day boundary rule (half-open [start, end)).
        final now = DateTime(2026, 6, 22, 5, 30);
        final (start, end) = dayWindow(
          now: now,
          boundaryHour: 5,
          boundaryMinute: 30,
        );

        expect(start, DateTime(2026, 6, 22, 5, 30));
        expect(end, DateTime(2026, 6, 23, 5, 30));
      },
    );

    // ------------------------------------------------------------------ //
    // Month-end rollover (non-leap year)                                  //
    // ------------------------------------------------------------------ //

    test(
      'month-end rollover (non-leap): now = March 1 03:00 2026 → window starts Feb 28',
      () {
        // Source: Parity Rulebook — Day boundary rule.
        // 2026 is not a leap year; Feb has 28 days.
        // The implementation uses DateTime(y, m, day-1) which Dart normalises:
        // DateTime(2026, 3, 0) → Feb 28, 2026. This tests that rollover.
        final now = DateTime(2026, 3, 1, 3, 0); // March 1, before 05:00
        final (start, end) = dayWindow(now: now);

        expect(start, DateTime(2026, 2, 28, 5, 0)); // Feb 28 05:00
        expect(end, DateTime(2026, 3, 1, 5, 0)); // March 1 05:00
      },
    );

    test(
      'month-end rollover (leap year): now = March 1 03:00 2024 → window starts Feb 29',
      () {
        // Source: Parity Rulebook — Day boundary rule.
        // 2024 IS a leap year; Feb has 29 days.
        // DateTime(2024, 3, 0) normalises to Feb 29, 2024.
        final now = DateTime(2024, 3, 1, 3, 0); // March 1, before 05:00
        final (start, end) = dayWindow(now: now);

        expect(start, DateTime(2024, 2, 29, 5, 0)); // Feb 29 05:00 (leap)
        expect(end, DateTime(2024, 3, 1, 5, 0)); // March 1 05:00
      },
    );

    // ------------------------------------------------------------------ //
    // Year-end rollover                                                   //
    // ------------------------------------------------------------------ //

    test(
      'year-end rollover: now = Jan 1 00:30 → window starts Dec 31 05:00',
      () {
        // Source: Parity Rulebook — Day boundary rule.
        // 00:30 < 05:00 → previous day's window.
        // DateTime(2026, 1, 0) normalises to Dec 31, 2025.
        final now = DateTime(2026, 1, 1, 0, 30);
        final (start, end) = dayWindow(now: now);

        expect(start, DateTime(2025, 12, 31, 5, 0)); // Dec 31 05:00
        expect(end, DateTime(2026, 1, 1, 5, 0)); // Jan 1 05:00
      },
    );

    // ------------------------------------------------------------------ //
    // Returned datetimes must be local (not UTC)                          //
    // ------------------------------------------------------------------ //

    test(
      'start and end are local datetimes (isUtc == false)',
      () {
        // Source: Parity Rulebook — "A drink's day = the window
        // [dayBoundary, next dayBoundary) containing its consumedAt (local)."
        // All boundary computations are in local time; UTC datetimes would
        // silently produce wrong buckets on non-UTC devices.
        final now = DateTime(2026, 6, 22, 10, 0);
        final (start, end) = dayWindow(now: now);

        expect(start.isUtc, isFalse);
        expect(end.isUtc, isFalse);
      },
    );

    // ------------------------------------------------------------------ //
    // Window is always exactly 24 hours (on days without a DST transition)//
    // ------------------------------------------------------------------ //

    test(
      'end − start == 24 hours for a mid-year non-DST-transition day',
      () {
        // Source: Parity Rulebook — Day boundary rule.
        // The window [boundary, next boundary) spans exactly one calendar day.
        // This holds on any day that doesn't contain a DST wall-clock transition.
        // (On spring-forward or fall-back days the Duration would be 23h or 25h,
        // which is correct and expected — do not use a known transition date here.)
        final now = DateTime(2026, 6, 22, 10, 0); // mid-year, no DST transition
        final (start, end) = dayWindow(now: now);

        expect(end.difference(start), const Duration(hours: 24));
      },
    );

    // ------------------------------------------------------------------ //
    // Consistency: start and end boundary timestamps are coherent         //
    // ------------------------------------------------------------------ //

    test(
      'start.hour and end.hour match the configured boundary hour',
      () {
        // Source: Parity Rulebook — Day boundary rule (configurable).
        final now = DateTime(2026, 6, 22, 10, 0);
        final (start, end) = dayWindow(now: now, boundaryHour: 5);

        expect(start.hour, 5);
        expect(start.minute, 0);
        expect(end.hour, 5);
        expect(end.minute, 0);
      },
    );

    test(
      'now is always contained in [start, end): start <= now < end',
      () {
        // Source: Parity Rulebook — Day boundary rule.
        // The half-open window must contain its own `now` argument.
        final cases = [
          DateTime(2026, 6, 22, 10, 0), // mid-day
          DateTime(2026, 6, 22, 4, 59), // just before boundary
          DateTime(2026, 6, 22, 5, 0), // exactly at boundary
          DateTime(2026, 6, 22, 0, 30), // midnight
          DateTime(2026, 3, 1, 3, 0), // month-end before boundary
          DateTime(2026, 1, 1, 0, 30), // year-end
        ];

        for (final now in cases) {
          final (start, end) = dayWindow(now: now);
          expect(
            !start.isAfter(now) && now.isBefore(end),
            isTrue,
            reason: 'now ($now) must satisfy start <= now < end '
                '(got [$start, $end))',
          );
        }
      },
    );
  });
}
