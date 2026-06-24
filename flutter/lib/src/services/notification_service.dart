import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:core/core.dart';

// ---------------------------------------------------------------------------
// Channel constants
// ---------------------------------------------------------------------------

/// Android notification channel for hydration reminders.
const String kHydrationChannelId = 'hydration_reminders';
const String kHydrationChannelName = 'Hydration reminders';

/// Android notification channel for weekly summaries.
const String kWeeklySummaryChannelId = 'weekly_summary';
const String kWeeklySummaryChannelName = 'Weekly summary';

// ---------------------------------------------------------------------------
// Abstract interface — all callers program against this, not the plugin.
// ---------------------------------------------------------------------------

/// Notification scheduling / cancellation primitives.
///
/// Implemented by [FlutterNotificationService] in production and by
/// [FakeNotificationService] in tests (where the native plugin is absent).
abstract interface class NotificationService {
  /// Initialises the plugin and Android notification channels.
  ///
  /// Must be called once before any other method. Safe to call multiple times
  /// (idempotent).
  Future<void> initialize();

  /// Requests OS notification permission.
  ///
  /// Returns true if granted, false on denial or unavailability. Non-fatal:
  /// reminders simply won't fire when denied.
  Future<bool> requestPermission();

  /// Schedules [count] one-shot notifications at [intervalMin]-minute intervals
  /// starting at or after [startTime], restricted to [activeStartHour, activeEndHour).
  ///
  /// Each occurrence is assigned an id derived from [id] (id × 1000 + index),
  /// so the entire batch can be cancelled with [cancelRepeating].
  Future<void> scheduleRepeating({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required DateTime startTime,
    required int intervalMin,
    required int activeStartHour,
    required int activeEndHour,
    int count = 48,
  });

  /// Schedules a single notification at [scheduledTime].
  Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required DateTime scheduledTime,
  });

  /// Cancels the repeating batch previously scheduled with id [id].
  ///
  /// [count] must match the value used in the corresponding [scheduleRepeating]
  /// call (default 48). Only that many slots are cancelled.
  Future<void> cancelRepeating(int id, {int count = 48});

  /// Cancels the single notification with id [id].
  Future<void> cancel(int id);

  /// Cancels every pending notification.
  Future<void> cancelAll();
}

// ---------------------------------------------------------------------------
// Production implementation
// ---------------------------------------------------------------------------

/// Production [NotificationService] backed by [FlutterLocalNotificationsPlugin].
///
/// Wrapped in try/catch so that [MissingPluginException] (thrown on platforms
/// where the plugin is not initialised or in headless tests) never crashes the
/// app.
class FlutterNotificationService implements NotificationService {
  FlutterNotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialised = false;

  // Cached future prevents double-init when concurrent callers both see
  // _initialised == false before either completes.
  Future<void>? _initFuture;

  @override
  Future<void> initialize() {
    if (_initialised) return Future.value();
    return _initFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    try {
      tz.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );
      await _plugin.initialize(initSettings);

      // Create Android notification channels.
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          kHydrationChannelId,
          kHydrationChannelName,
          description:
              'Reminders to keep you on track with your daily hydration goal.',
          importance: Importance.defaultImportance,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          kWeeklySummaryChannelId,
          kWeeklySummaryChannelName,
          description: 'A weekly recap of your hydration goal achievement.',
          importance: Importance.low,
        ),
      );

      _initialised = true;
    } catch (e) {
      // Allow retry on failure by clearing the cached future.
      _initFuture = null;
      // Swallow MissingPluginException in test/headless environments. Log
      // anything else so real device misconfigurations are diagnosable.
      debugPrint('[NotificationService] initialize failed: $e');
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> scheduleRepeating({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required DateTime startTime,
    required int intervalMin,
    required int activeStartHour,
    required int activeEndHour,
    int count = 48,
  }) async {
    try {
      final slots = buildScheduleSlots(
        from: startTime,
        intervalMin: intervalMin,
        activeStartHour: activeStartHour,
        activeEndHour: activeEndHour,
        count: count,
      );

      // Android notification IDs are int32; guard against overflow for
      // monotonically-growing DB primary keys. Assert for debug, hard-return
      // for release (assert is stripped in release/profile builds).
      assert(
        id < 2000000,
        'notification id $id too large: id*1000+47 overflows int32',
      );
      if (id >= 2000000) {
        debugPrint(
          '[NotificationService] id $id too large — skipping schedule',
        );
        return;
      }
      final details = _notificationDetails(channelId);
      for (var i = 0; i < slots.length; i++) {
        final slotId = id * 1000 + i;
        final tzTime = tz.TZDateTime.from(slots[i], tz.local);
        await _plugin.zonedSchedule(
          slotId,
          title,
          body,
          tzTime,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (_) {
      // Swallow; callers must not crash when the plugin is unavailable.
    }
  }

  @override
  Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required DateTime scheduledTime,
  }) async {
    try {
      final details = _notificationDetails(channelId);
      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  @override
  Future<void> cancelRepeating(int id, {int count = 48}) async {
    try {
      for (var i = 0; i < count; i++) {
        await _plugin.cancel(id * 1000 + i);
      }
    } catch (_) {}
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  NotificationDetails _notificationDetails(String channelId) {
    final channelName = channelId == kHydrationChannelId
        ? kHydrationChannelName
        : channelId == kWeeklySummaryChannelId
            ? kWeeklySummaryChannelName
            : channelId;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }
}

// ---------------------------------------------------------------------------
// Fake implementation for tests
// ---------------------------------------------------------------------------

/// In-memory [NotificationService] for widget/unit tests.
///
/// No native plugin calls — records scheduled/cancelled ids for assertion.
class FakeNotificationService implements NotificationService {
  bool initialised = false;
  bool permissionGranted = true;

  final List<({int id, DateTime scheduledTime, String title, String body})>
      scheduled = [];
  final List<int> cancelled = [];
  bool allCancelled = false;

  @override
  Future<void> initialize() async => initialised = true;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> scheduleRepeating({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required DateTime startTime,
    required int intervalMin,
    required int activeStartHour,
    required int activeEndHour,
    int count = 48,
  }) async {
    final slots = buildScheduleSlots(
      from: startTime,
      intervalMin: intervalMin,
      activeStartHour: activeStartHour,
      activeEndHour: activeEndHour,
      count: count,
    );
    for (var i = 0; i < slots.length; i++) {
      scheduled.add((
        id: id * 1000 + i,
        scheduledTime: slots[i],
        title: title,
        body: body,
      ));
    }
  }

  @override
  Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required DateTime scheduledTime,
  }) async {
    scheduled.add((
      id: id,
      scheduledTime: scheduledTime,
      title: title,
      body: body,
    ));
  }

  @override
  Future<void> cancelRepeating(int id, {int count = 48}) async {
    for (var i = 0; i < count; i++) {
      final slotId = id * 1000 + i;
      cancelled.add(slotId);
      scheduled.removeWhere((e) => e.id == slotId);
    }
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> cancelAll() async {
    allCancelled = true;
    cancelled.addAll(scheduled.map((e) => e.id));
    scheduled.clear();
  }
}
