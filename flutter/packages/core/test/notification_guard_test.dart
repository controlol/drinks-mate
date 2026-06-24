import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // isInActiveHours
  // ---------------------------------------------------------------------------
  group(
    'isInActiveHours (notifications.md §Configuration, default 08:00–22:00)',
    () {
      // Half-open interval [start, end) — i.e. start is inclusive, end exclusive.
      test('inside window (09:00 within 08–22) → true', () {
        expect(
          isInActiveHours(
            now: DateTime(2026, 6, 24, 9, 0),
            activeStartHour: 8,
            activeEndHour: 22,
          ),
          isTrue,
        );
      });

      test('at start boundary (08:00) → true (inclusive)', () {
        expect(
          isInActiveHours(
            now: DateTime(2026, 6, 24, 8, 0),
            activeStartHour: 8,
            activeEndHour: 22,
          ),
          isTrue,
        );
      });

      test('just before end (21:59) → true', () {
        expect(
          isInActiveHours(
            now: DateTime(2026, 6, 24, 21, 59),
            activeStartHour: 8,
            activeEndHour: 22,
          ),
          isTrue,
        );
      });

      test('at end boundary (22:00) → false (exclusive)', () {
        // Source: notifications.md §Configuration, half-open [start, end)
        expect(
          isInActiveHours(
            now: DateTime(2026, 6, 24, 22, 0),
            activeStartHour: 8,
            activeEndHour: 22,
          ),
          isFalse,
        );
      });

      test('outside window (23:00) → false', () {
        expect(
          isInActiveHours(
            now: DateTime(2026, 6, 24, 23, 0),
            activeStartHour: 8,
            activeEndHour: 22,
          ),
          isFalse,
        );
      });

      test('midnight (00:00) outside 08–22 → false', () {
        expect(
          isInActiveHours(
            now: DateTime(2026, 6, 24, 0, 0),
            activeStartHour: 8,
            activeEndHour: 22,
          ),
          isFalse,
        );
      });

      // Overnight window: [22, 06) covers 22:00–05:59, excludes 06:00–21:59.
      group('overnight window (22–06)', () {
        test('23:00 inside overnight window → true', () {
          expect(
            isInActiveHours(
              now: DateTime(2026, 6, 24, 23, 0),
              activeStartHour: 22,
              activeEndHour: 6,
            ),
            isTrue,
          );
        });

        test('00:00 inside overnight window → true', () {
          expect(
            isInActiveHours(
              now: DateTime(2026, 6, 24, 0, 0),
              activeStartHour: 22,
              activeEndHour: 6,
            ),
            isTrue,
          );
        });

        test('05:59 inside overnight window (just before end) → true', () {
          expect(
            isInActiveHours(
              now: DateTime(2026, 6, 24, 5, 59),
              activeStartHour: 22,
              activeEndHour: 6,
            ),
            isTrue,
          );
        });

        test('06:00 at end of overnight window → false (exclusive)', () {
          expect(
            isInActiveHours(
              now: DateTime(2026, 6, 24, 6, 0),
              activeStartHour: 22,
              activeEndHour: 6,
            ),
            isFalse,
          );
        });

        test('12:00 outside overnight window → false', () {
          expect(
            isInActiveHours(
              now: DateTime(2026, 6, 24, 12, 0),
              activeStartHour: 22,
              activeEndHour: 6,
            ),
            isFalse,
          );
        });
      });
    },
  );

  // ---------------------------------------------------------------------------
  // isInactiveUserSilenced
  // ---------------------------------------------------------------------------
  group(
      'isInactiveUserSilenced '
      '(notifications.md §Inactive-user silence)', () {
    // Use a fixed now; derive past timestamps via subtract to avoid DST hazards
    // when computing millisecond differences across calendar days.
    final now = DateTime(2026, 6, 24, 12, 0);

    // Source: notifications.md §Inactive-user silence
    test('exactly 7 days inactive → silenced (true)', () {
      final installedAt = now.subtract(const Duration(days: 7));
      expect(
        isInactiveUserSilenced(
          now: now,
          installedAt: installedAt,
          latestDrinkConsumedAt: null,
        ),
        isTrue,
      );
    });

    // Source: notifications.md §Inactive-user silence
    test('6 days 23 hours inactive → not silenced (false)', () {
      final installedAt = now.subtract(const Duration(days: 6, hours: 23));
      expect(
        isInactiveUserSilenced(
          now: now,
          installedAt: installedAt,
          latestDrinkConsumedAt: null,
        ),
        isFalse,
      );
    });

    // Source: notifications.md §Inactive-user silence
    test('8 days inactive → silenced (true)', () {
      final installedAt = now.subtract(const Duration(days: 8));
      expect(
        isInactiveUserSilenced(
          now: now,
          installedAt: installedAt,
          latestDrinkConsumedAt: null,
        ),
        isTrue,
      );
    });

    test('0 days inactive (just installed) → not silenced (false)', () {
      expect(
        isInactiveUserSilenced(
          now: now,
          installedAt: now,
          latestDrinkConsumedAt: null,
        ),
        isFalse,
      );
    });

    // Source: notifications.md §Inactive-user silence
    test(
      'latestDrinkConsumedAt null, installedAt exactly 7 days ago → silenced',
      () {
        final installedAt = now.subtract(const Duration(days: 7));
        expect(
          isInactiveUserSilenced(
            now: now,
            installedAt: installedAt,
            // latestDrinkConsumedAt omitted — should default to installedAt
          ),
          isTrue,
        );
      },
    );

    // last_engagement = max(installedAt, latestDrinkConsumedAt)
    // When latestDrinkConsumedAt is MORE recent, it is used.
    // Discriminating fixture: installedAt = 8 days ago (would silence if used),
    // latestDrinkConsumedAt = 1 day ago (should not silence).
    test(
        'latestDrinkConsumedAt more recent than installedAt → '
        'last_engagement = latestDrinkConsumedAt (not silenced)', () {
      final installedAt = now.subtract(const Duration(days: 8));
      final latestDrink = now.subtract(const Duration(days: 1));
      expect(
        isInactiveUserSilenced(
          now: now,
          installedAt: installedAt,
          latestDrinkConsumedAt: latestDrink,
        ),
        isFalse,
      );
    });

    // last_engagement = max(installedAt, latestDrinkConsumedAt)
    // When latestDrinkConsumedAt is OLDER, installedAt is used.
    // Discriminating fixture: installedAt = 1 day ago (should not silence if used),
    // latestDrinkConsumedAt = 30 days ago (would silence if used).
    test(
        'latestDrinkConsumedAt older than installedAt → '
        'last_engagement = installedAt (not silenced)', () {
      final installedAt = now.subtract(const Duration(days: 1));
      final latestDrink = now.subtract(const Duration(days: 30));
      expect(
        isInactiveUserSilenced(
          now: now,
          installedAt: installedAt,
          latestDrinkConsumedAt: latestDrink,
        ),
        isFalse,
      );
    });

    // Cross-check: when latestDrinkConsumedAt is older and installedAt pushes
    // past the 7-day boundary, it is silenced.
    test(
        'latestDrinkConsumedAt older than installedAt, '
        'installedAt is 7+ days ago → silenced', () {
      final installedAt = now.subtract(const Duration(days: 7));
      final latestDrink = now.subtract(const Duration(days: 30));
      expect(
        isInactiveUserSilenced(
          now: now,
          installedAt: installedAt,
          latestDrinkConsumedAt: latestDrink,
        ),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // isNotificationTooSoon
  // ---------------------------------------------------------------------------
  group('isNotificationTooSoon (flood-prevention guard)', () {
    final now = DateTime(2026, 6, 24, 10, 0);
    const intervalMin = 90;

    test('lastNotifiedAt is null → false (never sent, never too soon)', () {
      expect(
        isNotificationTooSoon(
          now: now,
          lastNotifiedAt: null,
          minIntervalMin: intervalMin,
        ),
        isFalse,
      );
    });

    test('exactly minIntervalMin minutes elapsed → false (not too soon)', () {
      final lastNotifiedAt = now.subtract(const Duration(minutes: intervalMin));
      expect(
        isNotificationTooSoon(
          now: now,
          lastNotifiedAt: lastNotifiedAt,
          minIntervalMin: intervalMin,
        ),
        isFalse,
      );
    });

    test('1 minute less than minIntervalMin elapsed → true (too soon)', () {
      final lastNotifiedAt =
          now.subtract(const Duration(minutes: intervalMin - 1));
      expect(
        isNotificationTooSoon(
          now: now,
          lastNotifiedAt: lastNotifiedAt,
          minIntervalMin: intervalMin,
        ),
        isTrue,
      );
    });

    test('more than minIntervalMin elapsed → false', () {
      final lastNotifiedAt =
          now.subtract(const Duration(minutes: intervalMin + 30));
      expect(
        isNotificationTooSoon(
          now: now,
          lastNotifiedAt: lastNotifiedAt,
          minIntervalMin: intervalMin,
        ),
        isFalse,
      );
    });

    test('just 1 ms short of minIntervalMin → true (too soon)', () {
      final lastNotifiedAt = now.subtract(
        const Duration(milliseconds: intervalMin * 60000 - 1),
      );
      expect(
        isNotificationTooSoon(
          now: now,
          lastNotifiedAt: lastNotifiedAt,
          minIntervalMin: intervalMin,
        ),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // buildScheduleSlots
  // ---------------------------------------------------------------------------
  group('buildScheduleSlots', () {
    // All DateTimes are local (DateTime(...) form) to match implementation output.
    // The implementation builds local DateTimes; DateTime == also compares isUtc.
    const startHour = 8;
    const endHour = 22;
    const intervalMin = 90;

    test('from already in active window → first slot equals from', () {
      final from = DateTime(2026, 6, 24, 9, 0); // 09:00, inside 08–22
      final slots = buildScheduleSlots(
        from: from,
        intervalMin: intervalMin,
        activeStartHour: startHour,
        activeEndHour: endHour,
        count: 1,
      );
      expect(slots, isNotEmpty);
      expect(slots.first, equals(from));
    });

    test('from at active-hours start → first slot equals from', () {
      final from = DateTime(2026, 6, 24, 8, 0); // 08:00 exactly
      final slots = buildScheduleSlots(
        from: from,
        intervalMin: intervalMin,
        activeStartHour: startHour,
        activeEndHour: endHour,
        count: 1,
      );
      expect(slots.first, equals(from));
    });

    // from after end of active window → next active slot is next day at startHour.
    test(
      'from outside active window (23:00) → first slot is next day at 08:00',
      () {
        final from = DateTime(2026, 6, 24, 23, 0); // outside 08–22
        final slots = buildScheduleSlots(
          from: from,
          intervalMin: intervalMin,
          activeStartHour: startHour,
          activeEndHour: endHour,
          count: 1,
        );
        expect(slots, isNotEmpty);
        // The implementation jumps to (day+1) at activeStartHour.
        final expected = DateTime(2026, 6, 25, startHour, 0);
        expect(slots.first, equals(expected));
      },
    );

    test('returns exactly count slots', () {
      final from = DateTime(2026, 6, 24, 8, 0);
      final slots = buildScheduleSlots(
        from: from,
        intervalMin: intervalMin,
        activeStartHour: startHour,
        activeEndHour: endHour,
        count: 5,
      );
      expect(slots.length, 5);
    });

    test('all slots fall within active hours', () {
      final from = DateTime(2026, 6, 24, 8, 0);
      final slots = buildScheduleSlots(
        from: from,
        intervalMin: intervalMin,
        activeStartHour: startHour,
        activeEndHour: endHour,
        count: 10,
      );
      for (final slot in slots) {
        expect(
          isInActiveHours(
            now: slot,
            activeStartHour: startHour,
            activeEndHour: endHour,
          ),
          isTrue,
          reason: 'slot $slot is outside active hours',
        );
      }
    });

    // Within a single active day, consecutive slots are exactly intervalMin apart.
    // At day-rollover the slot resets to activeStartHour, so only test intra-day gaps.
    test('intra-day consecutive slots are intervalMin apart', () {
      // Starting at 08:00 on a 90-min interval: 08:00, 09:30, 11:00, 12:30
      // All fall within the 08:00–22:00 window — no rollover within 4 slots.
      final from = DateTime(2026, 6, 24, 8, 0);
      final slots = buildScheduleSlots(
        from: from,
        intervalMin: intervalMin,
        activeStartHour: startHour,
        activeEndHour: endHour,
        count: 4,
      );
      expect(slots.length, 4);
      for (var i = 1; i < slots.length; i++) {
        final gapMin = slots[i].difference(slots[i - 1]).inMinutes;
        expect(
          gapMin,
          intervalMin,
          reason: 'gap between slot ${i - 1} and slot $i was $gapMin min,'
              ' expected $intervalMin',
        );
      }
    });

    // After the active window ends the cursor resets to the next day's start hour.
    // Verify the day-boundary reset: last intra-day slot + interval overflows 22:00,
    // so the next slot should be the following day at 08:00.
    test('slot after window close resets to next day at activeStartHour', () {
      // 20:30 + 90 min = 22:00 which is exclusive, so next slot → next day 08:00.
      final from = DateTime(2026, 6, 24, 20, 30);
      final slots = buildScheduleSlots(
        from: from,
        intervalMin: intervalMin,
        activeStartHour: startHour,
        activeEndHour: endHour,
        count: 2,
      );
      expect(slots.length, 2);
      expect(slots.first, equals(DateTime(2026, 6, 24, 20, 30)));
      expect(slots[1], equals(DateTime(2026, 6, 25, startHour, 0)));
    });

    test('count=0 returns empty list', () {
      final slots = buildScheduleSlots(
        from: DateTime(2026, 6, 24, 9, 0),
        intervalMin: intervalMin,
        activeStartHour: startHour,
        activeEndHour: endHour,
        count: 0,
      );
      expect(slots, isEmpty);
    });

    // Regression: from before activeStartHour on the same day must produce
    // a slot at activeStartHour on that SAME day, not the next day.
    test('from before window start same day → first slot is same day at 08:00',
        () {
      final from = DateTime(2026, 6, 24, 6, 0); // 06:00, before 08:00 start
      final slots = buildScheduleSlots(
        from: from,
        intervalMin: intervalMin,
        activeStartHour: startHour,
        activeEndHour: endHour,
        count: 1,
      );
      expect(slots, isNotEmpty);
      expect(slots.first, equals(DateTime(2026, 6, 24, startHour, 0)));
    });
  });
}
