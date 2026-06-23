import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Requests OS notification permission on iOS and Android.
///
/// Wrapped in try/catch so that MissingPluginException (thrown in widget tests
/// and on platforms where the plugin is not initialised) never crashes the app.
/// Denial or unavailability is non-fatal — onboarding completes regardless.
class NotificationPermissionService {
  const NotificationPermissionService();

  /// Requests permission and returns whether the user granted it.
  ///
  /// Returns false on denial, plugin unavailability, or any exception.
  Future<bool> requestPermission() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();

      final ios = plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }

      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }

      return false;
    } catch (_) {
      return false;
    }
  }
}
