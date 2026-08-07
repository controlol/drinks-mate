import 'package:drinks_mate/src/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeNotificationService', () {
    test('cancelRepeating records exactly count ids, not 1000', () async {
      final svc = FakeNotificationService();

      // Schedule 10 slots then cancel with matching count.
      await svc.scheduleRepeating(
        id: 1,
        title: 't',
        body: 'b',
        channelId: kHydrationChannelId,
        startTime: DateTime(2026, 1, 1, 8),
        intervalMin: 60,
        activeStartHour: 8,
        activeEndHour: 22,
        count: 10,
      );

      await svc.cancelRepeating(1, count: 10);

      expect(svc.cancelled.length, 10);
      expect(svc.cancelled, [
        1000,
        1001,
        1002,
        1003,
        1004,
        1005,
        1006,
        1007,
        1008,
        1009,
      ]);
    });

    test('cancelRepeating default count is 48', () async {
      final svc = FakeNotificationService();
      await svc.cancelRepeating(2);
      expect(svc.cancelled.length, 48);
    });

    test('cancelRepeating removes slots from scheduled', () async {
      final svc = FakeNotificationService();
      await svc.scheduleRepeating(
        id: 1,
        title: 't',
        body: 'b',
        channelId: kHydrationChannelId,
        startTime: DateTime(2026, 1, 1, 8),
        intervalMin: 60,
        activeStartHour: 8,
        activeEndHour: 22,
        count: 5,
      );
      expect(svc.scheduled.length, 5);

      await svc.cancelRepeating(1, count: 5);

      expect(svc.scheduled, isEmpty);
      expect(svc.cancelled.length, 5);
    });

    test('cancel removes the entry from scheduled', () async {
      final svc = FakeNotificationService();
      await svc.scheduleOnce(
        id: 42,
        title: 't',
        body: 'b',
        channelId: kHydrationChannelId,
        scheduledTime: DateTime(2026, 1, 1, 9),
      );
      expect(svc.scheduled.length, 1);

      await svc.cancel(42);

      expect(svc.scheduled, isEmpty);
      expect(svc.cancelled, [42]);
    });

    test('requestPermission reflects permissionGranted = false', () async {
      final svc = FakeNotificationService()..permissionGranted = false;

      expect(await svc.requestPermission(), isFalse);
    });
  });
}
