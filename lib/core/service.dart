import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/core.dart';

import 'interface.dart';
import 'transport.dart';

/// The core on Windows: `RoutaMiCore.exe` as a separate process, started by
/// the helper service (LocalSystem, needed for TUN) when it is installed, or
/// as the user otherwise. Ported from FlClash; the transport is
/// [CoreTransport] instead of FlClash's Rust named pipe.
class CoreService extends CoreHandlerInterface {
  static CoreService? _instance;

  final _transport = CoreTransport();
  late final Future<void> _ready;

  Completer<bool> _shutdownCompleter = Completer();

  final Map<String, Completer> _callbackCompleterMap = {};

  Process? _process;

  factory CoreService() {
    _instance ??= CoreService._internal();
    return _instance!;
  }

  CoreService._internal() {
    _ready = _initServer();
  }

  Future<void> _initServer() async {
    await _transport.init();
    _transport.onDisconnect = () {
      _handleCrash();
      if (!_shutdownCompleter.isCompleted) {
        _shutdownCompleter.complete(true);
      }
    };
    _transport.messages.listen((data) async {
      try {
        final result = ActionResult.fromJson(
          await data.trim().commonToJSON<dynamic>(),
        );
        await _handleResult(result);
      } catch (e) {
        commonPrint.log(
          'Failed to parse core data: $e',
          logLevel: LogLevel.error,
        );
      }
    });
  }

  Future<void> _handleResult(ActionResult result) async {
    if (result.id?.isEmpty ?? true) {
      coreEventManager.sendEvent(CoreEvent.fromJson(result.data));
      return;
    }
    final completer = _callbackCompleterMap[result.id];
    if (completer == null || completer.isCompleted) return;
    completer.complete(await parasResult(result));
  }

  void _handleCrash() {
    coreEventManager.sendEvent(
      const CoreEvent(type: CoreEventType.crash, data: 'core done'),
    );
  }

  Future<void> start() async {
    await _ready;
    if (_process != null) {
      await shutdown(false);
    }
    final address = _transport.address;
    if (await system.checkIsAdmin()) {
      if (await request.startCoreByHelper(address)) {
        await _transport.connectionCompleter.future;
        return;
      }
    }
    try {
      _process = await Process.start(appPath.corePath, [address]);
    } catch (e) {
      commonPrint.log('Failed to start core: $e', logLevel: LogLevel.error);
      _handleCrash();
      return;
    }
    _process?.stdout.listen((_) {});
    _process?.stderr.listen((data) {
      final error = utf8.decode(data, allowMalformed: true);
      if (error.isNotEmpty) {
        commonPrint.log(error, logLevel: LogLevel.warning);
      }
    });
    await _transport.connectionCompleter.future;
  }

  @override
  FutureOr<bool> destroy() async {
    await shutdown(false);
    await _transport.close();
    return true;
  }

  @override
  Future<bool> shutdown(bool isUser) async {
    _shutdownCompleter = Completer();
    await request.stopCoreByHelper();
    _transport.disconnected();
    _process?.kill();
    _process = null;
    for (final completer in _callbackCompleterMap.values) {
      completer.safeCompleter(null);
    }
    _callbackCompleterMap.clear();
    return isUser ? _shutdownCompleter.future : true;
  }

  @override
  Future<String> preload() async {
    await start();
    return '';
  }

  @override
  Future<T?> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
  }) async {
    final id = '${method.name}#${utils.id}';
    final completer = Completer<T?>();
    _callbackCompleterMap[id] = completer;
    await _transport.connectionCompleter.future;
    _transport.send(json.encode(Action(id: id, method: method, data: data)));
    return completer.future.withTimeout(
      timeout: timeout,
      onLast: () {
        _callbackCompleterMap.remove(id)?.safeCompleter(null);
      },
      tag: id,
      onTimeout: () => null,
    );
  }

  @override
  Completer get completer => _transport.connectionCompleter;
}

final coreService = Platform.isWindows ? CoreService() : null;
