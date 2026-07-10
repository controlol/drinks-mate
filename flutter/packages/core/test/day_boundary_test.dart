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

    test('now at 10:00 local → window is [today 05:00, tomorrow 05:00]', () {
      // Source: Parity Rulebook — Day boundary rule.
      final now = DateTime(2026, 6, 22, 10, 0); // Mon 10:00
      final (start, end) = dayWindow(now: now);

      expect(start, DateTime(2026, 6, 22, 5, 0));
      expect(end, DateTime(2026, 6, 23, 5, 0));
    });

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

    test('now at 00:30 local (midnight) → falls in previous day\'s window', () {
      // Source: Parity Rulebook — Day boundary rule.
      // 00:30 < 05:00 → previous day's window.
      final now = DateTime(2026, 6, 22, 0, 30);
      final (start, end) = dayWindow(now: now);

      expect(start, DateTime(2026, 6, 21, 5, 0)); // yesterday 05:00
      expect(end, DateTime(2026, 6, 22, 5, 0)); // today 05:00
    });

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

    test('start and end are local datetimes (isUtc == false)', () {
      // Source: Parity Rulebook — "A drink's day = the window
      // [dayBoundary, next dayBoundary) containing its consumedAt (local)."
      // All boundary computations are in local time; UTC datetimes would
      // silently produce wrong buckets on non-UTC devices.
      final now = DateTime(2026, 6, 22, 10, 0);
      final (start, end) = dayWindow(now: now);

      expect(start.isUtc, isFalse);
      expect(end.isUtc, isFalse);
    });

    // ------------------------------------------------------------------ //
    // Window is always exactly 24 hours (on days without a DST transition)//
    // ------------------------------------------------------------------ //

    test('end − start == 24 hours for a mid-year non-DST-transition day', () {
      // Source: Parity Rulebook — Day boundary rule.
      // The window [boundary, next boundary) spans exactly one calendar day.
      // This holds on any day that doesn't contain a DST wall-clock transition.
      // (On spring-forward or fall-back days the Duration would be 23h or 25h,
      // which is correct and expected — do not use a known transition date here.)
      final now = DateTime(2026, 6, 22, 10, 0); // mid-year, no DST transition
      final (start, end) = dayWindow(now: now);

      expect(end.difference(start), const Duration(hours: 24));
    });

    // ------------------------------------------------------------------ //
    // Consistency: start and end boundary timestamps are coherent         //
    // ------------------------------------------------------------------ //

    test('start.hour and end.hour match the configured boundary hour', () {
      // Source: Parity Rulebook — Day boundary rule (configurable).
      final now = DateTime(2026, 6, 22, 10, 0);
      final (start, end) = dayWindow(now: now, boundaryHour: 5);

      expect(start.hour, 5);
      expect(start.minute, 0);
      expect(end.hour, 5);
      expect(end.minute, 0);
    });

    test('now is always contained in [start, end): start <= now < end', () {
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
    });
  });

  // Source: Parity Rulebook → "Weekly summary" (ISO week, Mon–Sun);
  // notifications.md §Notification types → Weekly summary. Built from 7
  // consecutive dayWindows: Monday's day-window start through the following
  // Monday's day-window start.
  group('isoWeekWindow (Parity Rulebook — ISO week, Mon–Sun)', () {
    test(
      'Sunday 20:00 (well after boundary) → window is the preceding Monday '
      '05:00 through the following Monday 05:00',
      () {
        // 2026-01-04 is a Sunday (weekday == 7) — verified via DateTime.weekday.
        final now = DateTime(2026, 1, 4, 20, 0);
        expect(now.weekday, DateTime.sunday);

        final (start, end) = isoWeekWindow(now: now);

        expect(start, DateTime(2025, 12, 29, 5, 0)); // preceding Monday 05:00
        expect(end, DateTime(2026, 1, 5, 5, 0)); // following Monday 05:00
      },
    );

    test(
      'Sunday 02:00 (before the 05:00 boundary) resolves to Saturday\'s '
      'day-window, but stays in the SAME ISO week as Sunday 20:00',
      () {
        // dayWindow(Jan 4 02:00, boundary 5) shifts back to Saturday Jan 3's
        // day-window (02:00 < 05:00 boundary) — see day_boundary.dart. But
        // Saturday Jan 3 and Sunday Jan 4 fall in the SAME Mon–Sun ISO week
        // (Mon Dec 29 – Sun Jan 4), so the pre-boundary shift does NOT push
        // this into the previous ISO week — it only matters when the shift
        // crosses a Sunday→Monday boundary (see the next test).
        final now = DateTime(2026, 1, 4, 2, 0);
        final (start, end) = isoWeekWindow(now: now);

        expect(start, DateTime(2025, 12, 29, 5, 0));
        expect(end, DateTime(2026, 1, 5, 5, 0));
      },
    );

    test(
      'Monday 02:00 (before the 05:00 boundary) shifts back to Sunday\'s '
      'day-window and thus the PREVIOUS ISO week — the genuinely tricky '
      'crossing case',
      () {
        // dayWindow(Jan 5 02:00, boundary 5) shifts back to Sunday Jan 4's
        // day-window (still before the day boundary). Sunday Jan 4 belongs to
        // the ISO week Mon Dec 29 – Sun Jan 4, i.e. the week BEFORE the one
        // containing "Monday Jan 5" by the calendar date alone. Contrast with
        // the very next test, where Jan 5 05:00 (3 hours later, at the
        // boundary) is the start of the NEW week — two instants 3 hours apart
        // land in different ISO weeks.
        final now = DateTime(2026, 1, 5, 2, 0);
        final (start, end) = isoWeekWindow(now: now);

        expect(start, DateTime(2025, 12, 29, 5, 0));
        expect(end, DateTime(2026, 1, 5, 5, 0));
      },
    );

    test(
      'Monday exactly at the boundary hour (05:00) is the START of the new '
      'week, not the previous one',
      () {
        final now = DateTime(2026, 1, 5, 5, 0);
        final (start, end) = isoWeekWindow(now: now);

        expect(start, DateTime(2026, 1, 5, 5, 0));
        expect(end, DateTime(2026, 1, 12, 5, 0));
      },
    );

    test('midweek Wednesday resolves to that week\'s Monday–Sunday bounds', () {
      final now = DateTime(2026, 1, 7, 12, 0); // Wednesday, well after boundary
      expect(now.weekday, DateTime.wednesday);

      final (start, end) = isoWeekWindow(now: now);

      expect(start, DateTime(2026, 1, 5, 5, 0));
      expect(end, DateTime(2026, 1, 12, 5, 0));
    });

    test('window duration is always exactly 7 days', () {
      final cases = [
        DateTime(2026, 1, 4, 20, 0),
        DateTime(2026, 1, 4, 2, 0),
        DateTime(2026, 1, 5, 2, 0),
        DateTime(2026, 1, 5, 5, 0),
        DateTime(2026, 1, 7, 12, 0),
      ];
      for (final now in cases) {
        final (start, end) = isoWeekWindow(now: now);
        expect(
          end.difference(start),
          const Duration(days: 7),
          reason: 'isoWeekWindow($now) must span exactly 7 days',
        );
      }
    });

    test(
      'now (as adjusted by day-boundary semantics) always falls within '
      '[start, end)',
      () {
        final cases = [
          DateTime(2026, 1, 4, 20, 0),
          DateTime(2026, 1, 4, 2, 0),
          DateTime(2026, 1, 5, 2, 0),
          DateTime(2026, 1, 5, 5, 0),
          DateTime(2026, 1, 7, 12, 0),
        ];
        for (final now in cases) {
          final (start, end) = isoWeekWindow(now: now);
          final dayStart = dayWindow(now: now).$1;
          expect(
            !start.isAfter(dayStart) && dayStart.isBefore(end),
            isTrue,
            reason: 'now\'s day-window start ($dayStart) must satisfy '
                'start <= dayStart < end (got [$start, $end))',
          );
        }
      },
    );
  });

  // Source: Parity Rulebook → "Day boundary" (the general day-window rule —
  // monthWindow has no dedicated Rulebook row of its own); design/features.md
  // F4 — History monthly range. Built the same way as isoWeekWindow: the 1st
  // of the month's day-window start through the 1st of next month's
  // day-window start.
  group('monthWindow (Day boundary + F4 — History monthly range)', () {
    test(
      'mid-month, well after boundary: now = June 15 12:00 2026 → window is '
      '[June 1 05:00, July 1 05:00)',
      () {
        final now = DateTime(2026, 6, 15, 12, 0);
        final (start, end) = monthWindow(now: now);

        expect(start, DateTime(2026, 6, 1, 5, 0));
        expect(end, DateTime(2026, 7, 1, 5, 0));
      },
    );

    test(
      'pre-boundary on the 1st: now = June 1 02:00 2026 (before 05:00) '
      'resolves into the PREVIOUS month\'s window',
      () {
        // dayWindow(June 1 02:00, boundary 5) shifts back to May 31's
        // day-window (02:00 < 05:00 boundary) — see day_boundary.dart. May 31
        // belongs to the May month-window, so the pre-boundary instant on the
        // 1st is still "last month", mirroring isoWeekWindow's Monday
        // pre-boundary crossing case.
        final now = DateTime(2026, 6, 1, 2, 0);
        final (start, end) = monthWindow(now: now);

        expect(start, DateTime(2026, 5, 1, 5, 0));
        expect(end, DateTime(2026, 6, 1, 5, 0));
      },
    );

    test(
      'custom boundary hour (0 = midnight): now = June 15 23:00 2026 → '
      'window is [June 1 00:00, July 1 00:00)',
      () {
        // Source: Parity Rulebook — Day boundary rule (configurable boundary).
        final now = DateTime(2026, 6, 15, 23, 0);
        final (start, end) = monthWindow(
          now: now,
          boundaryHour: 0,
          boundaryMinute: 0,
        );

        expect(start, DateTime(2026, 6, 1, 0, 0));
        expect(end, DateTime(2026, 7, 1, 0, 0));
      },
    );

    test(
      'December → January year rollover: now = Dec 15 12:00 2026 → window is '
      '[Dec 1 05:00 2026, Jan 1 05:00 2027)',
      () {
        final now = DateTime(2026, 12, 15, 12, 0);
        final (start, end) = monthWindow(now: now);

        expect(start, DateTime(2026, 12, 1, 5, 0));
        expect(end, DateTime(2027, 1, 1, 5, 0));
      },
    );

    test(
      'now (as adjusted by day-boundary semantics) always falls within '
      '[start, end)',
      () {
        final cases = [
          DateTime(2026, 6, 15, 12, 0),
          DateTime(2026, 6, 1, 2, 0),
          DateTime(2026, 6, 15, 23, 0),
          DateTime(2026, 12, 15, 12, 0),
        ];
        for (final now in cases) {
          final (start, end) = monthWindow(now: now);
          final dayStart = dayWindow(now: now).$1;
          expect(
            !start.isAfter(dayStart) && dayStart.isBefore(end),
            isTrue,
            reason: 'now\'s day-window start ($dayStart) must satisfy '
                'start <= dayStart < end (got [$start, $end))',
          );
        }
      },
    );
  });

  // Source: Parity Rulebook → "Weekly summary" (ISO week, Mon–Sun) +
  // "Day boundary"; design/user-experience.md S3 — History range paging
  // ("step backwards and forwards through past periods"). Steps back by
  // 7*offset days from the current week's window.
  group('pagedIsoWeekWindow (ISO week paging, F4/S3)', () {
    // Anchor: 2026-01-07 is a Wednesday. isoWeekWindow(now) (boundary 5) =
    // [2026-01-05 05:00, 2026-01-12 05:00) — the week Mon Jan 5 – Sun Jan 11.
    final anchor = DateTime(2026, 1, 7, 12, 0);

    test('offset=0 matches plain isoWeekWindow for the same now', () {
      final paged = pagedIsoWeekWindow(now: anchor, offset: 0);
      final plain = isoWeekWindow(now: anchor);

      expect(paged, equals(plain));
      expect(paged.$1, DateTime(2026, 1, 5, 5, 0));
      expect(paged.$2, DateTime(2026, 1, 12, 5, 0));
    });

    test('offset=1 lands on the prior Monday\'s week window', () {
      final (start, end) = pagedIsoWeekWindow(now: anchor, offset: 1);

      expect(start, DateTime(2025, 12, 29, 5, 0));
      expect(end, DateTime(2026, 1, 5, 5, 0));
    });

    test(
      'offset=2 lands two whole weeks back, crossing the year boundary',
      () {
        final (start, end) = pagedIsoWeekWindow(now: anchor, offset: 2);

        expect(start, DateTime(2025, 12, 22, 5, 0));
        expect(end, DateTime(2025, 12, 29, 5, 0));
      },
    );

    test(
      'custom boundary hour (0 = midnight) is respected when paging back',
      () {
        // isoWeekWindow(anchor, boundary 0) = [2026-01-05 00:00, 2026-01-12 00:00).
        final (start, end) = pagedIsoWeekWindow(
          now: anchor,
          offset: 1,
          boundaryHour: 0,
          boundaryMinute: 0,
        );

        expect(start, DateTime(2025, 12, 29, 0, 0));
        expect(end, DateTime(2026, 1, 5, 0, 0));
      },
    );

    test('every window start is a Monday, 7 days wide', () {
      for (var offset = 0; offset <= 3; offset++) {
        final (start, end) = pagedIsoWeekWindow(now: anchor, offset: offset);
        expect(
          start.weekday,
          DateTime.monday,
          reason: 'offset=$offset window must start on a Monday',
        );
        expect(end.difference(start), const Duration(days: 7));
      }
    });
  });

  // Source: Parity Rulebook → "Day boundary"; design/features.md F4 — History
  // monthly range paging; design/user-experience.md S3 (paging semantics).
  group('pagedMonthWindow (calendar-month paging, F4/S3)', () {
    // Anchor: monthWindow(2026-01-15, boundary 5) = [2026-01-01 05:00, 2026-02-01 05:00).
    final anchor = DateTime(2026, 1, 15, 12, 0);

    test('offset=0 matches plain monthWindow for the same now', () {
      final paged = pagedMonthWindow(now: anchor, offset: 0);
      final plain = monthWindow(now: anchor);

      expect(paged, equals(plain));
      expect(paged.$1, DateTime(2026, 1, 1, 5, 0));
      expect(paged.$2, DateTime(2026, 2, 1, 5, 0));
    });

    test(
      'offset=2 pages back across a year boundary: January → November of '
      'the previous year',
      () {
        final (start, end) = pagedMonthWindow(now: anchor, offset: 2);

        expect(start, DateTime(2025, 11, 1, 5, 0));
        expect(end, DateTime(2025, 12, 1, 5, 0));
      },
    );

    test('offset=1 lands on the previous calendar month', () {
      final (start, end) = pagedMonthWindow(now: anchor, offset: 1);

      expect(start, DateTime(2025, 12, 1, 5, 0));
      expect(end, DateTime(2026, 1, 1, 5, 0));
    });

    test(
      'custom boundary hour (0 = midnight) is respected when paging back',
      () {
        final (start, end) = pagedMonthWindow(
          now: anchor,
          offset: 1,
          boundaryHour: 0,
          boundaryMinute: 0,
        );

        expect(start, DateTime(2025, 12, 1, 0, 0));
        expect(end, DateTime(2026, 1, 1, 0, 0));
      },
    );

    test('every window start is the 1st of a month', () {
      for (var offset = 0; offset <= 14; offset++) {
        final (start, end) = pagedMonthWindow(now: anchor, offset: offset);
        expect(
          start.day,
          1,
          reason: 'offset=$offset window must start on the 1st',
        );
        expect(
          end.isAfter(start),
          isTrue,
          reason: 'offset=$offset window end must be after its start',
        );
      }
    });
  });
}
