import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/core/service.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:path/path.dart';

import 'app_localizations.dart';
import 'constant.dart';
import 'local_proxy_auth.dart';
import 'path.dart';
import 'preferences.dart';
import 'print.dart';
import 'system.dart';
import 'tray.dart';

/// The tray that holds the core in lite mode (`lite.json`, written by
/// RoutaMiTray.exe, see core/tray).
typedef LiteTrayState = ({int pid, int port, String token});

/// What the tray reports when it hands the core back.
typedef LiteAttach = ({bool running, bool helper});

LiteTrayState? parseLiteState(String text) {
  try {
    final json = jsonDecode(text);
    if (json is! Map) return null;
    final port = json['port'];
    final token = json['token'];
    final pid = json['pid'];
    if (port is! int || token is! String || token.isEmpty || pid is! int) {
      return null;
    }
    return (pid: pid, port: port, token: token);
  } catch (_) {
    return null;
  }
}

LiteAttach parseLiteAttach(String text) {
  final json = jsonDecode(text) as Map;
  return (running: json['running'] == true, helper: json['helper'] == true);
}

/// The first line RoutaMiTray.exe prints: where the core should connect.
String? parseLiteCoreAddress(String line) {
  try {
    final address = (jsonDecode(line) as Map)['core'];
    return address is String && address.startsWith('tcp:') ? address : null;
  } catch (_) {
    return null;
  }
}

/// The labels, icons and settings RoutaMiTray.exe works from.
Map<String, dynamic> liteSnapshot({
  required String statePath,
  required String executableDir,
  required String corePath,
  required bool helper,
  required bool tun,
  required bool systemProxy,
  required int port,
  required List<String> bypass,
  required Map<String, String> labels,
}) {
  String icon(int index) => join(
    executableDir,
    'data',
    'flutter_assets',
    'assets',
    'images',
    'icon',
    'status_$index.ico',
  );
  return {
    'state': statePath,
    'app': join(executableDir, '$appName.exe'),
    'core': corePath,
    'helper': helper,
    'tun': tun,
    'systemProxy': {'enable': systemProxy, 'port': port, 'bypass': bypass},
    'icons': {'off': icon(1), 'on': icon(2), 'tun': icon(3)},
    'labels': labels,
  };
}

/// Lite mode on Windows: RoutaMi exits and RoutaMiTray.exe keeps the core,
/// the system proxy and a tray icon; opening RoutaMi takes the core back.
class LiteMode {
  /// RoutaMi.exe --lite: start, then go to the tray.
  bool launchRequested = false;

  static const trayExecutableName = 'RoutaMiTray.exe';
  static const _timeout = Duration(seconds: 3);

  Future<String> get statePath async =>
      join(await appPath.homeDirPath, 'lite.json');

  String get trayPath => join(appPath.executableDirPath, trayExecutableName);

  Future<HttpClientResponse> _request(
    LiteTrayState tray,
    String method,
    String path, [
    Object? body,
  ]) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.openUrl(
        method,
        Uri.parse('http://127.0.0.1:${tray.port}$path'),
      );
      request.headers.set('Authorization', 'Bearer ${tray.token}');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      return await request.close().timeout(const Duration(seconds: 15));
    } finally {
      client.close();
    }
  }

  /// The running tray, if any; a stale lite.json is removed.
  Future<LiteTrayState?> find() async {
    final file = File(await statePath);
    if (!await file.exists()) return null;
    final tray = parseLiteState(await file.readAsString());
    if (tray != null) {
      try {
        final response = await _request(tray, 'GET', '/status');
        await response.drain<void>();
        if (response.statusCode == HttpStatus.ok) return tray;
      } catch (_) {}
    }
    try {
      await file.delete();
    } catch (_) {}
    return null;
  }

  /// Whether the tray's core has its listeners on.
  Future<bool> isRunning(LiteTrayState tray) async {
    try {
      final response = await _request(tray, 'GET', '/status');
      final body = await response.transform(utf8.decoder).join();
      return (jsonDecode(body) as Map)['running'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Asks the tray to hand its core to the app listening at [address].
  Future<LiteAttach?> attach(String address) async {
    final tray = await find();
    if (tray == null) return null;
    try {
      final response = await _request(tray, 'POST', '/attach', {
        'address': address,
      });
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        commonPrint.log('lite attach: $body', logLevel: LogLevel.warning);
        return null;
      }
      return parseLiteAttach(body);
    } catch (e) {
      commonPrint.log('lite attach: $e', logLevel: LogLevel.warning);
      return null;
    }
  }

  /// Starts RoutaMiTray.exe with [snapshot] and returns the address it
  /// waits for the core on.
  Future<String> startTray(Map<String, dynamic> snapshot) async {
    final process = await Process.start(
      trayPath,
      const [],
      mode: ProcessStartMode.detachedWithStdio,
    );
    process.stdin.write(jsonEncode(snapshot));
    await process.stdin.close();
    final line = await process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(const Duration(seconds: 10));
    final address = parseLiteCoreAddress(line);
    if (address == null) throw 'unexpected tray output: $line';
    return address;
  }

  /// Hands the core to RoutaMiTray.exe and closes RoutaMi.
  Future<void> enter() async {
    final service = coreService;
    if (service == null) return;
    final container = globalState.container;
    final l10n = currentAppLocalizations;
    try {
      final ready = await container
          .read(coreActionProvider.notifier)
          .ensureCoreReady();
      if (!ready) throw 'the core is not running';
      final network = container.read(networkSettingProvider);
      final address = await startTray(
        liteSnapshot(
          statePath: await statePath,
          executableDir: appPath.executableDirPath,
          corePath: appPath.corePath,
          helper: service.startedByHelper,
          tun: container.read(realTunEnableProvider),
          systemProxy:
              network.systemProxy && network.authentication.credentials.isEmpty,
          port: container.read(patchClashConfigProvider).mixedPort,
          bypass: network.bypassDomain,
          labels: {
            'title': appName,
            'open': l10n.show,
            'start': l10n.start,
            'stop': l10n.stop,
            'restart': l10n.restartCore,
            'exit': l10n.exit,
          },
        ),
      );
      final message = await service.handover(address);
      if (message.isNotEmpty) throw message;
    } catch (e) {
      commonPrint.log('lite mode: $e', logLevel: LogLevel.warning);
      globalState.showNotifier(l10n.liteModeFailed('$e'));
      return;
    }
    // The core and the system proxy stay with the tray: no handleExit.
    await preferences.saveConfig(container.read(configProvider));
    await tray?.destroy();
    await system.exit();
  }

  /// `RoutaMi.exe --lite` goes to the tray once it has started.
  Future<void> enterIfRequested() async {
    if (launchRequested) await enter();
  }
}

final liteMode = LiteMode();
