import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'common.dart';
import 'user_agent.dart';

extension PackageInfoExtension on PackageInfo {
  String get ua => subscriptionUserAgent(
    appName: appName,
    appVersion: version,
    platform: Platform.operatingSystem,
  );
}
