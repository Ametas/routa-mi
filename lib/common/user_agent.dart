import 'package:fl_clash/enum/profile_core.dart';

/// Xray-core bundled in libclash.so; `core/go.mod` pins the same release
/// (test/common/user_agent_test.dart keeps them in sync).
const xrayCoreVersion = '26.3.27';

/// User-Agent for subscription downloads: the app, then the core the
/// profile runs on, e.g. `RoutaMi/0.1.0 mihomo/1.19.31` or
/// `RoutaMi/0.1.0 xray/26.3.27`. Panels pick the format by it.
String subscriptionUserAgent({
  required String appVersion,
  ProfileCore core = ProfileCore.mihomo,
  String mihomoVersion = const String.fromEnvironment('MIHOMO_VERSION'),
}) {
  String bare(String version) =>
      version.startsWith('v') ? version.substring(1) : version;
  final coreVersion = switch (core) {
    ProfileCore.mihomo => mihomoVersion,
    ProfileCore.xray => xrayCoreVersion,
  };
  final coreName = core.name;
  final coreTag = coreVersion.isEmpty
      ? coreName
      : '$coreName/${bare(coreVersion)}';
  return 'RoutaMi/${bare(appVersion)} $coreTag';
}
