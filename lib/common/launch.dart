import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import 'constant.dart';

/// The command Windows runs at sign-in. The path is quoted: unquoted, a path
/// under "Program Files" with arguments is ambiguous to Windows.
String autoLaunchCommand(String executable, {required bool toTray}) =>
    toTray ? '"$executable" --lite' : '"$executable"';

/// Start with Windows (ported from FlClash). Android has no equivalent.
/// With [toTray] RoutaMi starts straight in lite mode (lib/common/lite.dart).
class AutoLaunch {
  static AutoLaunch? _instance;

  AutoLaunch._internal();

  factory AutoLaunch() {
    _instance ??= AutoLaunch._internal();
    return _instance!;
  }

  void _setup(bool toTray) {
    launchAtStartup.setup(
      appName: appName,
      appPath: '"${Platform.resolvedExecutable}"',
      args: toTray ? const ['--lite'] : const [],
    );
  }

  Future<void> updateStatus(bool isAutoLaunch, {bool toTray = false}) async {
    if (kDebugMode) return;
    // isEnabled compares the whole command, so a changed mode re-registers.
    _setup(toTray);
    if (await launchAtStartup.isEnabled() == isAutoLaunch) return;
    if (isAutoLaunch) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }
}

final autoLaunch = Platform.isWindows ? AutoLaunch() : null;
