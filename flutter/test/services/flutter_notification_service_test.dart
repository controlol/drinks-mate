import 'package:clock/clock.dart';
import 'package:drinks_mate/src/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// The channel `flutter_local_notifications` talks to natively — mocking it
/// lets slots that pass the plugin's own future-date validation "succeed"
/// headless instead of throwing `MissingPluginException`.
const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;

  final scheduledIds = <int>[];

  setUp(() {
    scheduledIds.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'zonedSchedule') {
        scheduledIds.add((call.arguments as Map)['id'] as int);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('FlutterNotificationService.scheduleRepeating resilience', () {
    // Regression: on-device, a cold-start reschedule produced zero
    // hydration reminders. `startTime` is a `clock.now()` snapshot taken
    // before this call's own awaits; by the time flutter_local_notifications'
    // own future-date check ran, wall-clock drift had pushed slot 0 into
    // the past, and it threw "Must be a date in the future". The whole
    // 48-slot loop shared one try/catch, so that single rejection aborted
    // every remaining (legitimately future) slot too.
    //
    // This reproduces the failure using the plugin's real validation logic:
    // the clock advances mid-call (simulating drift the
    // clampForSchedulingLatency margin didn't cover) so slot 0 — safely in
    // the future when computed — is in the past by the time it's validated,
    // while slots 1+ still land after the advanced clock.
    test(
      'a slot rejected by the real plugin validation does not abort '
      'scheduling of the remaining slots',
      () async {
        final service = FlutterNotificationService();
        final start = DateTime(2026, 6, 24, 10);
        final clock = _AdvancingClock(
          initial: start.subtract(const Duration(minutes: 40)),
          jumpTo: start.add(const Duration(minutes: 45)),
          jumpAfterCalls: 1,
        );

        await withClock(clock, () async {
          await service.scheduleRepeating(
            id: 1,
            title: 't',
            body: 'b',
            channelId: kHydrationChannelId,
            startTime: start,
            intervalMin: 90,
            activeStartHour: 0,
            activeEndHour: 23,
            count: 3,
          );
        });

        // clampForSchedulingLatency reads the clock BEFORE the jump
        // (start is already >30s out, so it's left unchanged): slot 0 =
        // start (10:00), slot 1 = 11:30, slot 2 = 13:00. The plugin's own
        // validation for every slot reads the clock AFTER it has jumped to
        // 10:45, so slot 0 (10:00) is rejected as past while slots 1
        // (11:30) and 2 (13:00) still pass and must still reach the
        // channel.
        expect(scheduledIds, [1001, 1002]);
      },
    );
  });
}

/// A [Clock] that returns [initial] for the first [jumpAfterCalls] calls to
/// [now], then [jumpTo] for every call after that — simulating wall-clock
/// drift occurring partway through a sequence of operations.
class _AdvancingClock extends Clock {
  _AdvancingClock({
    required this.initial,
    required this.jumpTo,
    required this.jumpAfterCalls,
  });

  final DateTime initial;
  final DateTime jumpTo;
  final int jumpAfterCalls;
  int _calls = 0;

  @override
  DateTime now() {
    _calls++;
    return _calls <= jumpAfterCalls ? initial : jumpTo;
  }
}
