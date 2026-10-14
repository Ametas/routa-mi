/// User-Agent for subscription downloads.
///
/// Subscription panels (Marzban, Remnawave and similar) pick the response
/// format by matching the User-Agent, usually from its start (`^mihomo`,
/// `^clash…`). An unrecognised client gets share links or Xray JSON, which
/// the core cannot load, so the core's name comes first and the brand last.
String subscriptionUserAgent({
  required String appName,
  required String appVersion,
  required String platform,
  String mihomoVersion = const String.fromEnvironment('MIHOMO_VERSION'),
}) => [
  mihomoVersion.isEmpty ? 'mihomo' : 'mihomo/$mihomoVersion',
  'clash-verge',
  '$appName/v$appVersion',
  'Platform/$platform',
].join(' ');
