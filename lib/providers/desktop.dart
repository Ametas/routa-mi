import 'package:fl_clash/common/local_proxy_auth.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config.dart';
import 'state.dart';

/// What the Windows tray shows.
final trayStateProvider = Provider.autoDispose<TrayState>((ref) {
  final isStart = ref.watch(runTimeProvider.select((state) => state != null));
  final systemProxy = ref.watch(
    networkSettingProvider.select((state) => state.systemProxy),
  );
  final clash = ref.watch(
    patchClashConfigProvider.select(
      (state) => VM3(state.mode, state.mixedPort, state.tun.enable),
    ),
  );
  final app = ref.watch(
    appSettingProvider.select(
      (state) => VM3(state.autoLaunch, state.locale, state.showTrayTitle),
    ),
  );
  return TrayState(
    mode: clash.a,
    port: clash.b,
    autoLaunch: app.a,
    systemProxy: systemProxy,
    tunEnable: clash.c,
    isStart: isStart,
    locale: app.b,
    brightness: null,
    groups: const [],
    selectedMap: const {},
    showTrayTitle: app.c,
  );
});

/// The Windows system proxy RoutaMi should apply. Like Android's
/// VpnService proxy, WinINet cannot carry credentials, so the system proxy
/// stays off while the local port requires them.
typedef SystemProxyState = ({bool enable, int port, List<String> bypassDomain});

final systemProxyStateProvider = Provider.autoDispose<SystemProxyState>((ref) {
  final isStart =
      !ref.watch(suspendProvider) &&
      ref.watch(runTimeProvider.select((state) => state != null));
  final network = ref.watch(networkSettingProvider);
  final port = ref.watch(
    patchClashConfigProvider.select((state) => state.mixedPort),
  );
  return (
    enable:
        isStart &&
        network.systemProxy &&
        network.authentication.credentials.isEmpty,
    port: port,
    bypassDomain: network.bypassDomain,
  );
});
