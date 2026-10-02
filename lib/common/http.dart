import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/local_proxy_auth.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String formatNetworkRouteLog(Uri url, {required bool proxy}) =>
    'network-route host=${url.host} scheme=${url.scheme} proxy=$proxy';

class FlClashHttpOverrides extends HttpOverrides {
  static String handleFindProxy(Uri url) {
    if ([localhost].contains(url.host)) {
      return 'DIRECT';
    }
    final ref = globalState.container;
    final isStart = ref.read(isStartProvider);
    final suspend = ref.read(suspendProvider);
    commonPrint.log(formatNetworkRouteLog(url, proxy: isStart));
    if (!isStart || suspend) return 'DIRECT';
    final mixedPort = ref.read(
      patchClashConfigProvider.select((state) => state.mixedPort),
    );
    return localProxyDirective(mixedPort);
  }

  /// Proxy directive for the local mixed port with the app's credentials.
  static String localProxyDirective(int port, {String host = 'localhost'}) {
    final authentication = globalState.container.read(
      networkSettingProvider.select((state) => state.authentication),
    );
    return authentication.proxyDirective(host, port);
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (_, _, _) => true;
    client.findProxy = handleFindProxy;
    return client;
  }
}
