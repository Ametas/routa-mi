import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import 'constant.dart';

/// Start with Windows (ported from FlClash). Android has no equivalent.
class AutoLaunch {
  static AutoLaunch? _instance;

  AutoLaunch._internal() {
    launchAtStartup.setup(
      appName: appName,
      appPath: Platform.resolvedExecutable,
    );
  }

  factory AutoLaunch() {
    _instance ??= AutoLaunch._internal();
    return _instance!;
  }

  Future<bool> get isEnable => launchAtStartup.isEnabled();

  Future<bool> enable() => launchAtStartup.enable();

  Future<bool> disable() => launchAtStartup.disable();

  Future<void> updateStatus(bool isAutoLaunch) async {
    if (kDebugMode) return;
    if (await isEnable == isAutoLaunch) return;
    if (isAutoLaunch) {
      await enable();
    } else {
      await disable();
    }
  }
}

final autoLaunch = Platform.isWindows ? AutoLaunch() : null;
