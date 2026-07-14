// Tests for issue #24's party_notification_service.dart — the orchestrator
// that schedules/cancels the two Party Mode session-scoped notifications
// (approaching cap, sober estimate) and applies lock-screen visibility.
//
// Conventions mirror flutter/test/services/reminder_scheduler_test.dart:
// FakeNotificationService + `svc.scheduled`/`svc.cancelled` assertions, a
// UserPreferences fixture builder copying that file's `_prefs()` pattern
// (extended with the Party Mode fields this service reads), and a minimal
// PartySession fixture builder per party_session.dart's constructor.
//
// Source docs: party-session.md §Notifications during a session,
// notifications.md §Party Mode notifications / §Lock-screen visibility.

import 'package:drinks_mate/src/models/party_session.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/services/bac_estimator.dart';
import 'package:drinks_mate/src/services/notification_service.dart';
import 'package:drinks_mate/src/services/party_notification_guard.dart';
import 'package:drinks_mate/src/services/party_notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show NotificationVisibility;
import 'package:flutter_test/flutter_test.dart';

final _epoch = DateTime.utc(2026, 1, 1);

/// UserPreferences fixture builder — copies reminder_scheduler_test.dart's
/// `_prefs()` pattern, adding the Party Mode fields this service reads.
UserPreferences _prefs({
  double? bacCapGramsPerL,
  bool bacOnLockScreenEnabled = true,
  bool approachingCapNotifEnabled = true,
  bool soberEstimateNotifEnabled = true,
  bool reminderEnabled = true,
}) {
  final now = DateTime.now().toUtc();
  return UserPreferences(
    id: 'test-prefs',
    dailyGoalMl: 2000,
    dayBoundaryHour: 5,
    units: 'metric',
    currency: 'EUR',
    reminderEnabled: reminderEnabled,
    reminderStartHour: 8,
    reminderEndHour: 22,
    reminderIntervalMin: 90,
    inactivityReminderEnabled: false,
    weeklySummaryEnabled: false,
    bacCapGramsPerL: bacCapGramsPerL,
    bacOnLockScreenEnabled: bacOnLockScreenEnabled,
    approachingCapNotifEnabled: approachingCapNotifEnabled,
    soberEstimateNotifEnabled: soberEstimateNotifEnabled,
    alcoholicPresetsAlwaysVisible: true,
    installedAt: _epoch,
    createdAt: now,
    updatedAt: now,
  );
}

/// Minimal PartySession fixture builder (party_session.dart's constructor).
PartySession _session({
  String id = 's1',
  DateTime? startedAt,
}) {
  final started = startedAt ?? _epoch;
  return PartySession(
    id: id,
    startedAt: started,
    useSessionPrices: false,
    createdAt: started,
    updatedAt: started,
  );
}

/// BacEstimate fixture — only [gPerL] matters to this service; the other
/// fields are display-only and irrelevant to scheduling decisions.
BacEstimate _estimate(double gPerL) => BacEstimate(
      gPerL: gPerL,
      mmolPerL: 0,
      usedWatson: false,
      unspecifiedGenderConservative: false,
      bmiWarning: false,
    );

void main() {
  group('Approaching-cap — gating', () {
    test(
      'approachingCapNotifEnabled=false → nothing scheduled even when BAC '
      'is at/above 80% of cap',
      () async {
        final svc = FakeNotificationService();
        final service = PartyNotificationService(
          svc,
          InMemoryPartyNotificationGuard(),
        );

        await service.sync(
          session: _session(),
          prefs: _prefs(
            approachingCapNotifEnabled: false,
            soberEstimateNotifEnabled: false,
          ),
          estimate: _estimate(0.9), // well above 80% of any reasonable cap
          capGPerL: 1.0,
          now: _epoch,
        );

        expect(
          svc.scheduled.any((e) => e.id == kApproachingCapNotificationId),
          isFalse,
        );
      },
    );

    test(
      'toggling approachingCapNotifEnabled off after a previous fire '
      'cancels id 400',
      () async {
        final svc = FakeNotificationService();
        final service = PartyNotificationService(
          svc,
          InMemoryPartyNotificationGuard(),
        );
        final session = _session();

        await service.sync(
          session: session,
          prefs: _prefs(soberEstimateNotifEnabled: false),
          estimate: _estimate(0.8),
          capGPerL: 1.0,
          now: _epoch,
        );
        expect(
          svc.scheduled.any((e) => e.id == kApproachingCapNotificationId),
          isTrue,
        );

        await service.sync(
          session: session,
          prefs: _prefs(
            approachingCapNotifEnabled: false,
            soberEstimateNotifEnabled: false,
          ),
          estimate: _estimate(0.8),
          capGPerL: 1.0,
          now: _epoch,
        );

        expect(
          svc.scheduled.any((e) => e.id == kApproachingCapNotificationId),
          isFalse,
        );
        expect(svc.cancelled, contains(kApproachingCapNotificationId));
      },
    );
  });

  group(
    'Approaching-cap — boundary (party-session.md §Notifications during a '
    'session: "pushes the estimated BAC to 80% or more of the cap")',
    () {
      test('79.9% of cap → does not fire', () async {
        final svc = FakeNotificationService();
        final service = PartyNotificationService(
          svc,
          InMemoryPartyNotificationGuard(),
        );

        await service.sync(
          session: _session(),
          prefs: _prefs(soberEstimateNotifEnabled: false),
          estimate: _estimate(0.799), // cap 1.0 → 79.9%
          capGPerL: 1.0,
          now: _epoch,
        );

        expect(
          svc.scheduled.any((e) => e.id == kApproachingCapNotificationId),
          isFalse,
        );
      });

      test(
        'exactly 80.0% of cap → fires, with the cap value in the body',
        () async {
          final svc = FakeNotificationService();
          final service = PartyNotificationService(
            svc,
            InMemoryPartyNotificationGuard(),
          );

          await service.sync(
            session: _session(),
            prefs: _prefs(soberEstimateNotifEnabled: false),
            estimate: _estimate(0.8), // cap 1.0 → exactly 80%
            capGPerL: 1.0,
            now: _epoch,
          );

          final entry = svc.scheduled
              .singleWhere((e) => e.id == kApproachingCapNotificationId);
          expect(entry.body, contains('1.00 g/L'));
        },
      );
    },
  );

  group('Approaching-cap — fires at most once per session', () {
    test(
      'a second sync for the same session with BAC still >=80% (even '
      'higher, simulating a second drink) does not re-fire',
      () async {
        final svc = FakeNotificationService();
        final service = PartyNotificationService(
          svc,
          InMemoryPartyNotificationGuard(),
        );
        final session = _session();
        final t1 = _epoch;
        final t2 = _epoch.add(const Duration(minutes: 30));

        await service.sync(
          session: session,
          prefs: _prefs(soberEstimateNotifEnabled: false),
          estimate: _estimate(0.8), // exactly 80%
          capGPerL: 1.0,
          now: t1,
        );
        await service.sync(
          session: session,
          prefs: _prefs(soberEstimateNotifEnabled: false),
          estimate: _estimate(0.95), // second drink pushes it higher still
          capGPerL: 1.0,
          now: t2,
        );

        final entries = svc.scheduled
            .where((e) => e.id == kApproachingCapNotificationId)
            .toList();
        expect(entries, hasLength(1));
        // Discriminating assertion: if the guard had failed to block the
        // second sync, scheduleOnce's overwrite-by-id behaviour would still
        // leave exactly one entry, but it would carry t2's time, not t1's —
        // asserting the scheduledTime is t1+1s (not t2+1s) is what actually
        // proves the guard suppressed the second fire.
        expect(
            entries.single.scheduledTime, t1.add(const Duration(seconds: 1)));
      },
    );
  });

  group('Approaching-cap — resets for a new session', () {
    test(
      'session A fires; a different session B with BAC >=80% fires again',
      () async {
        final svc = FakeNotificationService();
        final service = PartyNotificationService(
          svc,
          InMemoryPartyNotificationGuard(),
        );
        final sessionA = _session(id: 'session-A');
        final sessionB = _session(id: 'session-B');
        final tA = _epoch;
        final tB = _epoch.add(const Duration(hours: 3));

        await service.sync(
          session: sessionA,
          prefs: _prefs(soberEstimateNotifEnabled: false),
          estimate: _estimate(0.8),
          capGPerL: 1.0,
          now: tA,
        );
        final afterA = svc.scheduled
            .singleWhere((e) => e.id == kApproachingCapNotificationId);
        expect(afterA.scheduledTime, tA.add(const Duration(seconds: 1)));

        await service.sync(
          session: sessionB,
          prefs: _prefs(soberEstimateNotifEnabled: false),
          estimate: _estimate(0.85),
          capGPerL: 1.0,
          now: tB,
        );

        final entries = svc.scheduled
            .where((e) => e.id == kApproachingCapNotificationId)
            .toList();
        expect(entries, hasLength(1));
        // Must carry session B's fire time — proves it actually re-fired for
        // B rather than leaving session A's stale entry in place.
        expect(
            entries.single.scheduledTime, tB.add(const Duration(seconds: 1)));
      },
    );
  });

  group('Sober-estimate — gating', () {
    test(
      'soberEstimateNotifEnabled=false → nothing scheduled at id 500',
      () async {
        final svc = FakeNotificationService();
        final service = PartyNotificationService(
          svc,
          InMemoryPartyNotificationGuard(),
        );

        await service.sync(
          session: _session(),
          prefs: _prefs(
            approachingCapNotifEnabled: false,
            soberEstimateNotifEnabled: false,
          ),
          projectedSoberTime: _epoch.add(const Duration(hours: 2)),
          now: _epoch,
        );

        expect(
          svc.scheduled.any((e) => e.id == kSoberEstimateNotificationId),
          isFalse,
        );
      },
    );

    test(
      'toggling soberEstimateNotifEnabled off after being scheduled cancels '
      'id 500',
      () async {
        final svc = FakeNotificationService();
        final service = PartyNotificationService(
          svc,
          InMemoryPartyNotificationGuard(),
        );
        final session = _session();
        final projected = _epoch.add(const Duration(hours: 2));

        await service.sync(
          session: session,
          prefs: _prefs(approachingCapNotifEnabled: false),
          projectedSoberTime: projected,
          now: _epoch,
        );
        expect(
          svc.scheduled.any((e) => e.id == kSoberEstimateNotificationId),
          isTrue,
        );

        await service.sync(
          session: session,
          prefs: _prefs(
            approachingCapNotifEnabled: false,
            soberEstimateNotifEnabled: false,
          ),
          projectedSoberTime: projected,
          now: _epoch,
        );

        expect(
          svc.scheduled.any((e) => e.id == kSoberEstimateNotificationId),
          isFalse,
        );
        expect(svc.cancelled, contains(kSoberEstimateNotificationId));
      },
    );
  });

  group('Sober-estimate — scheduled at the correct time', () {
    test('scheduledTime equals the given future projectedSoberTime', () async {
      final svc = FakeNotificationService();
      final service = PartyNotificationService(
        svc,
        InMemoryPartyNotificationGuard(),
      );
      final projected = _epoch.add(const Duration(hours: 3, minutes: 15));

      await service.sync(
        session: _session(),
        prefs: _prefs(approachingCapNotifEnabled: false),
        projectedSoberTime: projected,
        now: _epoch,
      );

      final entry = svc.scheduled
          .singleWhere((e) => e.id == kSoberEstimateNotificationId);
      expect(entry.scheduledTime, projected);
    });
  });

  group('Sober-estimate — rescheduled when the projection changes', () {
    test(
      'a later projectedSoberTime (new drink pushes it out) leaves exactly '
      'one id-500 entry, at the newer time',
      () async {
        final svc = FakeNotificationService();
        final service = PartyNotificationService(
          svc,
          InMemoryPartyNotificationGuard(),
        );
        final session = _session();
        final p1 = _epoch.add(const Duration(hours: 2));
        final p2 = _epoch.add(const Duration(hours: 4));

        await service.sync(
          session: session,
          prefs: _prefs(approachingCapNotifEnabled: false),
          projectedSoberTime: p1,
          now: _epoch,
        );
        await service.sync(
          session: session,
          prefs: _prefs(approachingCapNotifEnabled: false),
          projectedSoberTime: p2,
          now: _epoch,
        );

        final entries = svc.scheduled
            .where((e) => e.id == kSoberEstimateNotificationId)
            .toList();
        expect(entries, hasLength(1));
        expect(entries.single.scheduledTime, p2);
      },
    );
  });

  group('Sober-estimate — past-time guard', () {
    test(
      'projectedSoberTime equal to now → not scheduled, cancelled instead',
      () async {
        final svc = FakeNotificationService();
        final service = PartyNotificationService(
          svc,
          InMemoryPartyNotificationGuard(),
        );

        await service.sync(
          session: _session(),
          prefs: _prefs(approachingCapNotifEnabled: false),
          projectedSoberTime: _epoch, // == now
          now: _epoch,
        );

        expect(
          svc.scheduled.any((e) => e.id == kSoberEstimateNotificationId),
          isFalse,
        );
        expect(svc.cancelled, contains(kSoberEstimateNotificationId));
      },
    );

    test(
      'projectedSoberTime before now (stale, e.g. app reopened long after '
      'BAC hit 0) → not scheduled, cancelled instead',
      () async {
        final svc = FakeNotificationService();
        final service = PartyNotificationService(
          svc,
          InMemoryPartyNotificationGuard(),
        );

        await service.sync(
          session: _session(),
          prefs: _prefs(approachingCapNotifEnabled: false),
          projectedSoberTime: _epoch.subtract(const Duration(hours: 1)),
          now: _epoch,
        );

        expect(
          svc.scheduled.any((e) => e.id == kSoberEstimateNotificationId),
          isFalse,
        );
        expect(svc.cancelled, contains(kSoberEstimateNotificationId));
      },
    );
  });

  group('Session ends / no active session', () {
    test(
      'sync(session: null) cancels both id 400 and id 500 if they were '
      'previously scheduled',
      () async {
        final svc = FakeNotificationService();
        final service = PartyNotificationService(
          svc,
          InMemoryPartyNotificationGuard(),
        );
        final session = _session();

        await service.sync(
          session: session,
          prefs: _prefs(),
          estimate: _estimate(0.8),
          capGPerL: 1.0,
          projectedSoberTime: _epoch.add(const Duration(hours: 2)),
          now: _epoch,
        );
        expect(
          svc.scheduled.any((e) => e.id == kApproachingCapNotificationId),
          isTrue,
        );
        expect(
          svc.scheduled.any((e) => e.id == kSoberEstimateNotificationId),
          isTrue,
        );

        await service.sync(session: null, prefs: _prefs(), now: _epoch);

        expect(svc.cancelled, contains(kApproachingCapNotificationId));
        expect(svc.cancelled, contains(kSoberEstimateNotificationId));
        expect(
          svc.scheduled.any((e) => e.id == kApproachingCapNotificationId),
          isFalse,
        );
        expect(
          svc.scheduled.any((e) => e.id == kSoberEstimateNotificationId),
          isFalse,
        );
      },
    );
  });

  group(
    'Master reminderEnabled toggle (notifications.md §Configuration: '
    '"master on/off toggle. When off, no notifications of any type fire.")',
    () {
      test(
        'reminderEnabled=false cancels both id 400 and id 500 even with an '
        'active session that would otherwise fire both',
        () async {
          final svc = FakeNotificationService();
          final service = PartyNotificationService(
            svc,
            InMemoryPartyNotificationGuard(),
          );
          final session = _session();

          // First prove both would fire with the master toggle on.
          await service.sync(
            session: session,
            prefs: _prefs(),
            estimate: _estimate(0.8),
            capGPerL: 1.0,
            projectedSoberTime: _epoch.add(const Duration(hours: 2)),
            now: _epoch,
          );
          expect(
            svc.scheduled.any((e) => e.id == kApproachingCapNotificationId),
            isTrue,
          );
          expect(
            svc.scheduled.any((e) => e.id == kSoberEstimateNotificationId),
            isTrue,
          );

          await service.sync(
            session: session,
            prefs: _prefs(reminderEnabled: false),
            estimate: _estimate(0.8),
            capGPerL: 1.0,
            projectedSoberTime: _epoch.add(const Duration(hours: 2)),
            now: _epoch,
          );

          expect(svc.cancelled, contains(kApproachingCapNotificationId));
          expect(svc.cancelled, contains(kSoberEstimateNotificationId));
          expect(
            svc.scheduled.any((e) => e.id == kApproachingCapNotificationId),
            isFalse,
          );
          expect(
            svc.scheduled.any((e) => e.id == kSoberEstimateNotificationId),
            isFalse,
          );
        },
      );
    },
  );

  group(
    'Lock-screen visibility (notifications.md §Lock-screen visibility)',
    () {
      test(
        'bacOnLockScreenEnabled=true → both scheduled types are public',
        () async {
          final svc = FakeNotificationService();
          final service = PartyNotificationService(
            svc,
            InMemoryPartyNotificationGuard(),
          );

          await service.sync(
            session: _session(),
            prefs: _prefs(bacOnLockScreenEnabled: true),
            estimate: _estimate(0.8),
            capGPerL: 1.0,
            projectedSoberTime: _epoch.add(const Duration(hours: 2)),
            now: _epoch,
          );

          final cap = svc.scheduled
              .singleWhere((e) => e.id == kApproachingCapNotificationId);
          final sober = svc.scheduled
              .singleWhere((e) => e.id == kSoberEstimateNotificationId);
          expect(cap.visibility, NotificationVisibility.public);
          expect(sober.visibility, NotificationVisibility.public);
        },
      );

      test(
        'bacOnLockScreenEnabled=false → both scheduled types are private',
        () async {
          final svc = FakeNotificationService();
          final service = PartyNotificationService(
            svc,
            InMemoryPartyNotificationGuard(),
          );

          await service.sync(
            session: _session(),
            prefs: _prefs(bacOnLockScreenEnabled: false),
            estimate: _estimate(0.8),
            capGPerL: 1.0,
            projectedSoberTime: _epoch.add(const Duration(hours: 2)),
            now: _epoch,
          );

          final cap = svc.scheduled
              .singleWhere((e) => e.id == kApproachingCapNotificationId);
          final sober = svc.scheduled
              .singleWhere((e) => e.id == kSoberEstimateNotificationId);
          expect(cap.visibility, NotificationVisibility.private);
          expect(sober.visibility, NotificationVisibility.private);
        },
      );
    },
  );
}
