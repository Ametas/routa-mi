import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:fl_clash/common/windows.dart';
import 'package:fl_clash/common/window.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:flutter/services.dart';

/// RoutaMi ships for Android and Windows. Anything that is not Windows takes
/// the Android paths, which keeps host test runs on the Android behaviour.
class System {
  static System? _instance;

  System._internal();

  factory System() {
    _instance ??= System._internal();
    return _instance!;
  }

  bool get isDesktop => isWindows;

  bool get isWindows => Platform.isWindows;

  bool get isMacOS => false;

  bool get isAndroid => !isWindows;

  bool get isLinux => false;

  Future<int> get version async {
    if (isWindows) {
      return (await DeviceInfoPlugin().windowsInfo).majorVersion;
    }
    return (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  }

  /// On Windows, whether the TUN helper service of this build is running.
  Future<bool> checkIsAdmin() async {
    if (!isWindows) return true;
    return await windows?.checkService() == WindowsHelperServiceStatus.running;
  }

  Future<AuthorizeCode> authorizeCore() async {
    if (!isWindows) return AuthorizeCode.error;
    if (await checkIsAdmin()) return AuthorizeCode.none;
    return await windows?.registerService() == true
        ? AuthorizeCode.success
        : AuthorizeCode.error;
  }

  Future<void> back() async {
    await app?.moveTaskToBack();
    await window?.hide();
  }

  Future<void> exit() async {
    if (isAndroid) {
      await SystemNavigator.pop();
      return;
    }
    await window?.close();
    window?.forceExit();
  }
}

final system = System();
