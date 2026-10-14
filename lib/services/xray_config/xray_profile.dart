import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/local_proxy_auth.dart';
import 'package:fl_clash/core/xray_runtime.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/enum/profile_core.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/services/settings/settings_contract.dart';
import 'package:fl_clash/services/xray_config/xray_runtime_config.dart';

/// The runtime config of an Xray [profile] (JSON and its md5), or null for
/// a mihomo profile. Remembers the build for the next core setup.
Future<VM2<String, String>?> materializeXrayProfile({
  required Profile? profile,
  required PatchClashConfig patch,
  required Config config,
}) async {
  if (profile == null || profile.core != ProfileCore.xray) {
    xrayRuntime.pending = null;
    return null;
  }
  final path = await appPath.getProfilePath(profile.id.toString());
  final network = config.networkProps;
  final vless = network.localVless;
  final runtime = buildXrayRuntimeConfig(
    await File(path).readAsString(),
    XrayRuntimeOptions(
      // On Android the VpnService hands its TUN to Xray.
      tun: system.isAndroid && config.vpnProps.enable,
      mixedPort: patch.mixedPort,
      allowLan: patch.allowLan,
      credentials: network.authentication.credentials,
      localVless: vless.enable && vless.uuid.isNotEmpty
          ? (port: vless.port, uuid: vless.uuid)
          : null,
      logLevel: patch.logLevel,
      mode: patch.mode,
      selectedNode: profile.selectedMap[XrayRuntimeConfig.groupName],
    ),
  );
  xrayRuntime.pending = runtime;
  return VM2(runtime.json, runtime.json.toMd5());
}

/// The TUN descriptor belongs to the running core, so a switch between a
/// mihomo and an Xray profile while the VPN runs rebuilds the VPN interface
/// and hands the new descriptor to the new core.
Future<void> reconnectVpnAfterCoreSwitch(Config config) async {
  final native = service;
  if (native == null) return;
  final snapshot = await native.getSessionSnapshot();
  final sessionId = snapshot['sessionId'];
  if (snapshot['state'] != 'RUNNING' || sessionId is! int) return;
  final error = await native.reconfigureSettings(
    settingsVpnOptions(config),
    sessionId,
  );
  if (error.isNotEmpty) {
    commonPrint.log(
      'core switch: VPN reconnect failed: $error',
      logLevel: LogLevel.warning,
    );
  }
}
