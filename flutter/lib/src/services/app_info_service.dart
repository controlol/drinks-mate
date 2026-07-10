import 'package:package_info_plus/package_info_plus.dart';

/// App version lookup — Settings → About (F6).
///
/// Implemented by [PackageInfoAppInfoService] in production and by
/// [FakeAppInfoService] in tests (where the native plugin is absent).
abstract interface class AppInfoService {
  /// Returns the display version string, e.g. "1.0.0 (3)".
  Future<String> versionString();
}

class PackageInfoAppInfoService implements AppInfoService {
  const PackageInfoAppInfoService();

  @override
  Future<String> versionString() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  }
}

/// Test double — returns a fixed string without touching platform channels.
class FakeAppInfoService implements AppInfoService {
  const FakeAppInfoService([this.value = '0.1.0 (1)']);

  final String value;

  @override
  Future<String> versionString() async => value;
}
