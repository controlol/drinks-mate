// Tests for `buildBacChartSeries` (flutter/lib/src/services/bac_chart_series.dart,
// issue #86) — the Party tab's BAC line chart data (party-session.md §BAC
// line chart).
//
// Contract points covered (bac_chart_series.dart's own doc comments plus
// party-session.md §BAC line chart):
//   1. No alcoholic entries -> a synthetic empty-state series, not null
//      (party-session.md §BAC line chart "Empty state": "The chart area is
//      reserved and rendered from the moment the session starts, even
//      before any drink is logged ... it shows a flat line at 0.00 g/L
//      across a default three-hour window (startedAt to startedAt + 3h),
//      with no dashed projection segment"; Parity Rulebook "BAC chart
//      empty-state window").
//   2. axisEnd == roundUpToNextHalfHour(projectedSoberTime(...).toLocal())
//      — same wiring the implementation itself does, cross-checked against
//      a real half-hour-boundary assertion independent of the
//      implementation (axisEnd always lands on :00 or :30, per the "rounded
//      up to the next 30 minutes" rule already vector-tested with concrete
//      times in packages/core/test/bac_test.dart).
//   3. The actual/solid segment's last sampled point never exceeds axisEnd.
//   4. The projected/dashed segment is empty once now >= axisEnd (fully in
//      the past — an ended session viewed later).
//   5. Sampled gPerL values are cross-checked against `estimateSessionBac`
//      directly at the same instants, not hand-derived magic numbers.
//
// Worked-example fixture (design/party-session.md §Worked example): 75 kg,
// 180 cm, 30-year-old male. Two simultaneous 250 ml 5% ABV beers are
// modelled as one 500 ml 5% ABV entry with the same total alcohol dose —
// same convention documented in
// flutter/test/widgets/party_screen_test.dart's file-header comment: since
// estimateSessionBac pools same-instant entries into one running total,
// this is just the simpler fixture, not a behavioral requirement.
import 'package:core/core.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_entry.dart';
import 'package:drinks_mate/src/models/user_profile.dart';
import 'package:drinks_mate/src/services/bac_chart_series.dart';
import 'package:drinks_mate/src/services/bac_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

final _epoch = DateTime.utc(2020, 1, 1);

// Birthdate ~30 years and 1 month before consumedAt (not exactly 30 calendar
// years) — same margin-of-safety convention as party_screen_test.dart's
// _workedBirthDate: age.dart's `floor((today - birthDate) / 365.25)` rounds
// an *exact* 30-calendar-year gap down to 29.
const _workedBirthDate = '1996-06-01';
final _workedConsumedAt = DateTime.utc(2026, 7, 1, 12, 0);
final _workedAgeYears = ageYearsFromBirthDate(
  birthDate: DateTime.parse(_workedBirthDate),
  today: _workedConsumedAt.toLocal(),
);
final _workedGrams = alcoholGrams(volumeMl: 500, abvPercent: 5.0);
final _workedTbw = watsonTbwLitres(
  gender: Gender.male,
  ageYears: _workedAgeYears,
  heightCm: 180,
  weightKg: 75,
);
final _workedBacInitial = bacInitialWatson(
  alcoholGrams: _workedGrams,
  tbwLitres: _workedTbw,
);

UserProfile _profile() {
  return UserProfile(
    id: 'profile-1',
    gender: 'male',
    weightKg: 75.0,
    heightCm: 180.0,
    birthDate: _workedBirthDate,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

DrinkEntry _workedEntry({DateTime? consumedAt}) {
  return DrinkEntry(
    id: 'e1',
    beverageType: BeverageType.beer,
    volumeMl: 500,
    abvPercent: 5.0,
    consumedAt: consumedAt ?? _workedConsumedAt,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

void main() {
  test('sanity: matches the (formula-correct) worked example', () {
    expect(_workedBacInitial, closeTo(0.360, 0.001));
  });

  group(
    'buildBacChartSeries — empty state (party-session.md §BAC line chart '
    '"Empty state"; Parity Rulebook "BAC chart empty-state window")',
    () {
      // Expected values below are literal spec numbers (3h window, flat
      // 0.00 g/L, no dashed projection, 30-min ticks), not the
      // implementation's own `bacChartEmptyStateWindow`/`bacChartTickInterval`
      // constants/calls — asserting against the impl's own constant would
      // pass even if that constant silently drifted from the doc.
      test(
        'alcoholicEntries.isEmpty -> non-null synthetic series: axisStart is '
        'sessionStartedAt (local), axisEnd is exactly 3h later, a flat '
        '2-point 0.00 g/L "actual" line, an empty "projected" list, and a '
        '30-minute tick interval',
        () {
          final startedAt = _workedConsumedAt;
          final series = buildBacChartSeries(
            profile: _profile(),
            sessionStartedAt: startedAt,
            alcoholicEntries: const [],
            meals: const [],
            now: startedAt,
          );

          expect(series, isNotNull);
          expect(series!.axisStart, startedAt.toLocal());
          expect(
            series.axisEnd.difference(series.axisStart),
            const Duration(hours: 3),
          );

          expect(series.actual, hasLength(2));
          expect(series.actual.first.time, series.axisStart);
          expect(series.actual.first.gPerL, 0);
          expect(series.actual.last.time, series.axisEnd);
          expect(series.actual.last.gPerL, 0);

          expect(series.projected, isEmpty);

          expect(series.tickInterval, const Duration(minutes: 30));
        },
      );

      test(
        'empty state ignores "now" entirely — the window is always exactly '
        '3h from sessionStartedAt regardless of how much time has elapsed',
        () {
          final startedAt = _workedConsumedAt;
          final series = buildBacChartSeries(
            profile: _profile(),
            sessionStartedAt: startedAt,
            alcoholicEntries: const [],
            meals: const [],
            now: startedAt.add(const Duration(hours: 5)),
          );

          expect(series, isNotNull);
          expect(
            series!.axisEnd.difference(series.axisStart),
            const Duration(hours: 3),
          );
          expect(series.actual, hasLength(2));
          expect(series.actual.every((p) => p.gPerL == 0), isTrue);
          expect(series.projected, isEmpty);
        },
      );
    },
  );

  group(
    'buildBacChartSeries — axis (party-session.md §BAC line chart "Time '
    'axis (X)")',
    () {
      test(
        'axisEnd equals roundUpToNextHalfHour(projectedSoberTime.toLocal()) '
        '— the same wiring the implementation performs',
        () {
          final entries = [_workedEntry()];
          final series = buildBacChartSeries(
            profile: _profile(),
            sessionStartedAt: _workedConsumedAt,
            alcoholicEntries: entries,
            meals: const [],
            now: _workedConsumedAt,
          );
          expect(series, isNotNull);

          final expectedSoberTime = projectedSoberTime(
            profile: _profile(),
            alcoholicEntries: entries,
            meals: const [],
            at: _workedConsumedAt,
          )!;
          expect(
            series!.axisEnd,
            roundUpToNextHalfHour(expectedSoberTime.toLocal()),
          );
        },
      );

      test(
        'axisEnd always lands exactly on a half-hour mark (:00 or :30), '
        'independent of how the underlying projection rounds',
        () {
          final entries = [_workedEntry()];
          final series = buildBacChartSeries(
            profile: _profile(),
            sessionStartedAt: _workedConsumedAt,
            alcoholicEntries: entries,
            meals: const [],
            now: _workedConsumedAt,
          );
          expect(series!.axisEnd.minute, anyOf(0, 30));
          expect(series.axisEnd.second, 0);
          expect(series.axisEnd.millisecond, 0);
        },
      );

      test('axisStart is the session\'s startedAt (local)', () {
        final entries = [_workedEntry()];
        final series = buildBacChartSeries(
          profile: _profile(),
          sessionStartedAt: _workedConsumedAt,
          alcoholicEntries: entries,
          meals: const [],
          now: _workedConsumedAt,
        );
        expect(series!.axisStart, _workedConsumedAt.toLocal());
      });

      test(
        'tickInterval matches bacChartTickInterval(axisEnd - axisStart)',
        () {
          final entries = [_workedEntry()];
          final series = buildBacChartSeries(
            profile: _profile(),
            sessionStartedAt: _workedConsumedAt,
            alcoholicEntries: entries,
            meals: const [],
            now: _workedConsumedAt,
          );
          expect(
            series!.tickInterval,
            bacChartTickInterval(series.axisEnd.difference(series.axisStart)),
          );
        },
      );
    },
  );

  group(
    'buildBacChartSeries — actual vs projected segments (party-session.md '
    '§BAC line chart "The line itself")',
    () {
      test(
        'the actual segment\'s last point never exceeds axisEnd, and its '
        'gPerL values match estimateSessionBac at the same instants',
        () {
          final entries = [_workedEntry()];
          // 2 hours after consumedAt — well before the session is fully
          // eliminated, so both actual and projected segments are non-empty.
          final now = _workedConsumedAt.add(const Duration(hours: 2));
          final series = buildBacChartSeries(
            profile: _profile(),
            sessionStartedAt: _workedConsumedAt,
            alcoholicEntries: entries,
            meals: const [],
            now: now,
          );

          expect(series, isNotNull);
          expect(series!.actual, isNotEmpty);
          expect(
            series.actual.last.time.isAfter(series.axisEnd),
            isFalse,
            reason: 'the actual/solid segment must never run past axisEnd',
          );

          // Cross-check every actual point's gPerL against estimateSessionBac
          // directly, filtering to only-already-consumed entries the same
          // way the implementation's `_gPerLAt` always does (a single entry
          // here, always already consumed by any sampled instant on/after
          // consumedAt).
          for (final point in series.actual) {
            final expected = estimateSessionBac(
              profile: _profile(),
              alcoholicEntries: entries,
              meals: const [],
              at: point.time.toUtc(),
            ).gPerL;
            expect(point.gPerL, closeTo(expected, 0.001));
          }
        },
      );

      test(
        'projected segment is empty once now >= axisEnd (session fully in '
        'the past, e.g. viewed after it ended)',
        () {
          final entries = [_workedEntry()];
          final probe = buildBacChartSeries(
            profile: _profile(),
            sessionStartedAt: _workedConsumedAt,
            alcoholicEntries: entries,
            meals: const [],
            now: _workedConsumedAt,
          )!;
          // Push `now` well past axisEnd.
          final farFuture = probe.axisEnd.toUtc().add(const Duration(days: 1));

          final series = buildBacChartSeries(
            profile: _profile(),
            sessionStartedAt: _workedConsumedAt,
            alcoholicEntries: entries,
            meals: const [],
            now: farFuture,
          );

          expect(series, isNotNull);
          expect(series!.projected, isEmpty);
          // The actual segment instead runs all the way to axisEnd.
          expect(series.actual.last.time, series.axisEnd);
        },
      );

      test(
        'at now == consumedAt (session just started): the actual segment is '
        'a single point at axisStart, and the projected segment covers the '
        'rest of the projection',
        () {
          final entries = [_workedEntry()];
          final series = buildBacChartSeries(
            profile: _profile(),
            sessionStartedAt: _workedConsumedAt,
            alcoholicEntries: entries,
            meals: const [],
            now: _workedConsumedAt,
          )!;

          expect(series.actual, hasLength(1));
          expect(series.actual.single.time, series.axisStart);
          expect(series.actual.single.gPerL, closeTo(_workedBacInitial, 0.001));
          expect(series.projected, isNotEmpty);
          expect(series.projected.last.time, series.axisEnd);
        },
      );

      test(
        'a future-dated consumedAt entry (S9 edit sheet allows this) does '
        'not inflate an earlier projected sample — regression for the '
        '"filter to already-consumed entries" rule applying to the '
        'projected segment too, not just the actual one',
        () {
          // One already-decaying entry (drives a real, non-trivial
          // projection) plus a second entry deliberately consumedAt in the
          // future relative to `now`.
          final normalEntry = _workedEntry();
          final now = _workedConsumedAt.add(const Duration(hours: 2));
          final futureEntry = DrinkEntry(
            id: 'future',
            beverageType: BeverageType.beer,
            volumeMl: 500,
            abvPercent: 5.0,
            consumedAt: now.add(const Duration(hours: 1)),
            createdAt: _epoch,
            updatedAt: _epoch,
          );
          final entries = [normalEntry, futureEntry];

          final series = buildBacChartSeries(
            profile: _profile(),
            sessionStartedAt: _workedConsumedAt,
            alcoholicEntries: entries,
            meals: const [],
            now: now,
          )!;

          expect(series.projected, isNotEmpty);
          for (final point in series.projected) {
            // The future entry must never contribute before its own
            // consumedAt — every projected point's gPerL should match
            // estimateSessionBac restricted to entries actually consumed by
            // that instant, not the full (unfiltered) entry list.
            final consumedByPoint = entries
                .where((e) => !e.consumedAt.isAfter(point.time))
                .toList();
            final expected = estimateSessionBac(
              profile: _profile(),
              alcoholicEntries: consumedByPoint,
              meals: const [],
              at: point.time,
            ).gPerL;
            expect(point.gPerL, closeTo(expected, 0.001));

            // Concretely: before the future entry's own consumedAt, its
            // ~0.18 g/L undecayed contribution must be absent entirely —
            // proving it wasn't unconditionally included.
            if (point.time.isBefore(futureEntry.consumedAt)) {
              final withoutFuture = estimateSessionBac(
                profile: _profile(),
                alcoholicEntries: [normalEntry],
                meals: const [],
                at: point.time,
              ).gPerL;
              expect(point.gPerL, closeTo(withoutFuture, 0.001));
            }
          }
        },
      );
    },
  );
}
