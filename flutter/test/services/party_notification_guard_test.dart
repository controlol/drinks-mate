// Tests for issue #24's party_notification_guard.dart, using the in-memory
// test double (mirrors the pattern this repo uses elsewhere for
// SharedPreferences-backed guards — see goal_celebration_guard.dart, which
// has no dedicated unit test file of its own to mirror, so this follows its
// doc comment directly instead).
//
// party-session.md §Notifications during a session / notifications.md §Party
// Mode notifications: the approaching-cap notification "fires exactly once
// per session"; starting a new session resets the trigger.

import 'package:drinks_mate/src/services/party_notification_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryPartyNotificationGuard', () {
    test('shouldFireApproachingCap is true initially for a fresh session',
        () async {
      final guard = InMemoryPartyNotificationGuard();
      expect(await guard.shouldFireApproachingCap('session-1'), isTrue);
    });

    test(
      'shouldFireApproachingCap is false for the same session id after '
      'markApproachingCapFired',
      () async {
        final guard = InMemoryPartyNotificationGuard();
        await guard.markApproachingCapFired('session-1');
        expect(await guard.shouldFireApproachingCap('session-1'), isFalse);
      },
    );

    test(
      'shouldFireApproachingCap is true again for a different session id — '
      'a new session resets the trigger',
      () async {
        final guard = InMemoryPartyNotificationGuard();
        await guard.markApproachingCapFired('session-1');
        expect(await guard.shouldFireApproachingCap('session-1'), isFalse);
        expect(await guard.shouldFireApproachingCap('session-2'), isTrue);
      },
    );
  });
}
