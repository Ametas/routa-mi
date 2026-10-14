/// User-Agent for subscription downloads: the app, then the core the
/// profile runs on, e.g. `RoutaMi/0.1.0 mihomo/1.19.31`. Panels pick the
/// response format by it (Clash YAML for mihomo).
String subscriptionUserAgent({
  required String appVersion,
  String coreName = 'mihomo',
  String coreVersion = const String.fromEnvironment('MIHOMO_VERSION'),
}) {
  String bare(String version) =>
      version.startsWith('v') ? version.substring(1) : version;
  final core = coreVersion.isEmpty
      ? coreName
      : '$coreName/${bare(coreVersion)}';
  return 'RoutaMi/${bare(appVersion)} $core';
}
