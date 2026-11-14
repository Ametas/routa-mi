import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';

enum WindowsHelperServiceStatus { none, presence, running }

/// Windows-only system calls: elevation and the TUN helper service
/// (`core/helper`). Ported from FlClash; the service registers itself
/// (`RoutaMiHelperService.exe install`), so its path is quoted correctly.
class Windows {
  static Windows? _instance;
  late final DynamicLibrary _shell32;

  Windows._internal() {
    _shell32 = DynamicLibrary.open('shell32.dll');
  }

  factory Windows() {
    _instance ??= Windows._internal();
    return _instance!;
  }

  /// Runs [command] elevated through the UAC prompt.
  bool runas(String command, String arguments) {
    final commandPtr = command.toNativeUtf16();
    final argumentsPtr = arguments.toNativeUtf16();
    final operationPtr = 'runas'.toNativeUtf16();
    final shellExecute = _shell32
        .lookupFunction<
          Int32 Function(
            Pointer<Utf16> hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            Int32 nShowCmd,
          ),
          int Function(
            Pointer<Utf16> hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            int nShowCmd,
          )
        >('ShellExecuteW');
    final result = shellExecute(
      nullptr,
      operationPtr,
      commandPtr,
      argumentsPtr,
      nullptr,
      0,
    );
    calloc.free(commandPtr);
    calloc.free(argumentsPtr);
    calloc.free(operationPtr);
    commonPrint.log(
      'windows runas: $command $arguments resultCode:$result',
      logLevel: LogLevel.warning,
    );
    return result > 32;
  }

  Future<WindowsHelperServiceStatus> checkService() async {
    final result = await Process.run('sc', ['query', appHelperService]);
    if (result.exitCode != 0) {
      return WindowsHelperServiceStatus.none;
    }
    if (result.stdout.toString().contains('RUNNING') &&
        await request.pingHelper()) {
      return WindowsHelperServiceStatus.running;
    }
    return WindowsHelperServiceStatus.presence;
  }

  /// Installs (or replaces) the helper service; one UAC prompt.
  Future<bool> registerService() async {
    if (await checkService() == WindowsHelperServiceStatus.running) {
      return true;
    }
    final launched = runas(appPath.helperPath, 'install');
    final status = await retry(
      task: checkService,
      maxAttempts: 8,
      retryIf: (status) => status != WindowsHelperServiceStatus.running,
      delay: const Duration(seconds: 1),
    );
    return launched && status == WindowsHelperServiceStatus.running;
  }
}

final windows = Platform.isWindows ? Windows() : null;
