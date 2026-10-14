import 'package:package_info_plus/package_info_plus.dart';

import 'user_agent.dart';

extension PackageInfoExtension on PackageInfo {
  String get ua => subscriptionUserAgent(appVersion: version);
}
