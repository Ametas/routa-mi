import 'dart:io';

import 'package:proxy/proxy.dart' as plugin;

/// The Windows system proxy (WinINet, `plugins/proxy` from FlClash).
class SystemProxy {
  final _proxy = plugin.Proxy();

  Future<bool?> startProxy(int port, List<String> bypassDomain) =>
      _proxy.startProxy(port, bypassDomain);

  Future<bool?> stopProxy() => _proxy.stopProxy();
}

final proxy = Platform.isWindows ? SystemProxy() : null;
