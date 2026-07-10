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

/// Android notification channel for Party Mode's approaching-cap and
/// sober-estimate notifications (notifications.md §Party Mode notifications).
const String kPartyModeChannelId = 'party_mode';
const String kPartyModeChannelName = 'Party Mode';

/// Action id for the hydration reminder's quick-log button.
///
/// notifications.md §Notification quick-log action: tapping it should log the
/// default drink without opening the app. Phase 1 only wires the visible
/// action button (this id + the iOS category below); handling the tap to
/// actually log a drink requires a native background-isolate callback and is
/// deferred — see [FlutterNotificationService] class doc.
const String kLogDrinkActionId = 'log_drink';

/// iOS notification category carrying the quick-log action, registered at
/// [FlutterNotificationService.initialize] time.
const String kHydrationReminderCategoryId = 'hydration_reminder_category';

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
  ///
  /// [payload] is forwarded verbatim to `zonedSchedule` so a registered
  /// delivery-time callback can re-query the DB and re-evaluate the fire
  /// predicate at delivery time.
  ///
  /// [quickLogActionLabel], when non-null, adds a "Log a drink"-style action
  /// button (see [kLogDrinkActionId]) to every scheduled occurrence.
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
    String? payload,
    String? quickLogActionLabel,
  });

  /// Schedules a single notification at [scheduledTime].
  ///
  /// [payload] is forwarded verbatim to `zonedSchedule` so a registered
  /// delivery-time callback can re-query the DB and re-evaluate the fire
  /// predicate at delivery time.
  ///
  /// [visibility] controls the Android lock-screen preview
  /// (notifications.md §Lock-screen visibility). Defaults to `private`;
  /// Party Mode callers pass `public` when
  /// `UserPreferences.bacOnLockScreenEnabled` is true. No iOS equivalent
  /// exists in this plugin — iOS lock-screen previews are controlled by the
  /// user at the OS level, not per-notification.
  ///
  /// Calling this again with the same [id] replaces any still-pending
  /// notification previously scheduled under that id (the underlying plugin
  /// overwrites by id) — callers rely on this to reschedule (e.g. the
  /// sober-estimate notification moving as new drinks are logged).
  Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required DateTime scheduledTime,
    String? payload,
    NotificationVisibility visibility = NotificationVisibility.private,
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
      final darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [
          DarwinNotificationCategory(
            kHydrationReminderCategoryId,
            actions: [
              DarwinNotificationAction.plain(kLogDrinkActionId, 'Log a drink'),
            ],
          ),
        ],
      );
      final initSettings = InitializationSettings(
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
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          kPartyModeChannelId,
          kPartyModeChannelName,
          description:
              'Approaching-cap and sober-estimate alerts during a Party '
              'Session.',
          importance: Importance.high,
        ),
      );

      _initialised = true;
    } catch (e) {
      // Allow retry on failure by clearing the cached future.
      _initFuture = null;
      // Swallow MissingPluginException in test/headless environments. Log
      // anything else (debug/profile only) so real device misconfigurations
      // are diagnosable without leaking exception detail in release builds.
      if (kDebugMode) {
        debugPrint('[NotificationService] initialize failed: $e');
      }
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
    String? payload,
    String? quickLogActionLabel,
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
        if (kDebugMode) {
          debugPrint(
            '[NotificationService] id $id too large — skipping schedule',
          );
        }
        return;
      }
      final details = _notificationDetails(
        channelId,
        quickLogActionLabel: quickLogActionLabel,
      );
      for (var i = 0; i < slots.length; i++) {
        final slotId = id * 1000 + i;
        final tzTime = tz.TZDateTime.from(slots[i], tz.local);
        await _plugin.zonedSchedule(
          slotId,
          title,
          body,
          tzTime,
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      // Swallow; callers must not crash when the plugin is unavailable.
      if (kDebugMode) {
        debugPrint('[NotificationService] scheduleRepeating failed: $e');
      }
    }
  }

  @override
  Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required DateTime scheduledTime,
    String? payload,
    NotificationVisibility visibility = NotificationVisibility.private,
  }) async {
    try {
      final details = _notificationDetails(channelId, visibility: visibility);
      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] scheduleOnce failed: $e');
      }
    }
  }

  @override
  Future<void> cancelRepeating(int id, {int count = 48}) async {
    try {
      for (var i = 0; i < count; i++) {
        await _plugin.cancel(id * 1000 + i);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] cancelRepeating failed: $e');
      }
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] cancel failed: $e');
      }
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] cancelAll failed: $e');
      }
    }
  }

  NotificationDetails _notificationDetails(
    String channelId, {
    String? quickLogActionLabel,
    NotificationVisibility visibility = NotificationVisibility.private,
  }) {
    final String channelName;
    switch (channelId) {
      case kHydrationChannelId:
        channelName = kHydrationChannelName;
      case kWeeklySummaryChannelId:
        channelName = kWeeklySummaryChannelName;
      case kPartyModeChannelId:
        channelName = kPartyModeChannelName;
      default:
        // Never surface an internal channel id as the user-visible name in
        // Android Settings.
        assert(false, 'unknown channelId: $channelId');
        channelName = 'Notifications';
    }
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        // Hydration/weekly-summary calls never pass a non-default visibility
        // (notifications.md §Lock-screen visibility: their content is always
        // safe to show). Party Mode calls pass `public` when
        // bacOnLockScreenEnabled is true.
        visibility: visibility,
        actions: quickLogActionLabel == null
            ? null
            : [
                AndroidNotificationAction(
                  kLogDrinkActionId,
                  quickLogActionLabel,
                ),
              ],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier:
            quickLogActionLabel == null ? null : kHydrationReminderCategoryId,
      ),
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

  final List<
      ({
        int id,
        DateTime scheduledTime,
        String title,
        String body,
        String? payload,
        String? quickLogActionLabel,
        NotificationVisibility visibility,
      })> scheduled = [];
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
    String? payload,
    String? quickLogActionLabel,
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
        payload: payload,
        quickLogActionLabel: quickLogActionLabel,
        visibility: NotificationVisibility.private,
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
    String? payload,
    NotificationVisibility visibility = NotificationVisibility.private,
  }) async {
    // Mirrors the real plugin's zonedSchedule: scheduling under an id that's
    // already pending replaces it, rather than appending a duplicate — see
    // NotificationService.scheduleOnce's doc.
    scheduled.removeWhere((e) => e.id == id);
    scheduled.add((
      id: id,
      scheduledTime: scheduledTime,
      title: title,
      body: body,
      payload: payload,
      quickLogActionLabel: null,
      visibility: visibility,
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
