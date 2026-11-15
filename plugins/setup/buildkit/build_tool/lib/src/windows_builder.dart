import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'logging.dart';
import 'mihomo_patcher.dart';
import 'util.dart';

final _log = Logger('windows_builder');

/// Builds the Windows side of RoutaMi into `libclash/windows/`:
/// `RoutaMiCore.exe` (the core as a separate process), the
/// `RoutaMiHelperService.exe` that runs it as LocalSystem for TUN (pinned to
/// the core's SHA-256), `RoutaMiTray.exe` that keeps the core in lite mode,
/// and Cronet's `libcronet.dll` for Naive. The core hash
/// also goes to `core_sha256.json` for `--dart-define-from-file`, so the app
/// can tell whether the installed helper belongs to this build.
class WindowsBuilder {
  WindowsBuilder({required this.rootDir, this.goarch = 'amd64'});

  final String rootDir;
  final String goarch;

  static const coreName = 'RoutaMiCore.exe';
  static const helperName = 'RoutaMiHelperService.exe';
  static const trayName = 'RoutaMiTray.exe';
  static const cronetName = 'libcronet.dll';
  static const tags = 'with_gvisor,with_naive,with_purego';

  String get _coreDir => p.join(rootDir, 'core');
  String get outputDir => p.join(rootDir, 'libclash', 'windows');

  Map<String, String> get _env => {
    'GOOS': 'windows',
    'GOARCH': goarch,
    'CGO_ENABLED': '0',
  };

  Future<String> build() async {
    MihomoPatcher(rootDir: rootDir).apply();
    ensureDir(outputDir);

    final version = mihomoVersion(rootDir);
    final versionFlag = version.isEmpty
        ? ''
        : ' -X "github.com/metacubex/mihomo/constant.Version=$version"';

    _log.info(kDoubleSeparator);
    _log.info('Building Windows core and helper (windows/$goarch)');
    _log.info(kSeparator);

    final corePath = p.join(outputDir, coreName);
    await runCommandStream('go', [
      'build',
      '-ldflags=-w -s -H=windowsgui$versionFlag',
      '-tags=$tags',
      '-o',
      corePath,
      '.',
    ], workingDirectory: _coreDir, environment: _env);

    final coreSha256 = await calcSha256(corePath);
    await runCommandStream('go', [
      'build',
      '-ldflags=-w -s -X main.coreSHA256=$coreSha256',
      '-o',
      p.join(outputDir, helperName),
      './helper',
    ], workingDirectory: _coreDir, environment: _env);

    await runCommandStream('go', [
      'build',
      '-ldflags=-w -s -H=windowsgui',
      '-o',
      p.join(outputDir, trayName),
      './tray',
    ], workingDirectory: _coreDir, environment: _env);

    final cronetDir = (runCommand('go', [
      'list',
      '-m',
      '-f',
      '{{.Dir}}',
      'github.com/sagernet/cronet-go/lib/windows_$goarch',
    ], workingDirectory: _coreDir).stdout as String).trim();
    copyFile(p.join(cronetDir, cronetName), p.join(outputDir, cronetName));

    File(p.join(rootDir, 'core_sha256.json')).writeAsStringSync(
      jsonEncode({'CORE_SHA256': coreSha256}),
    );
    _log.info('Built $outputDir (core SHA-256 $coreSha256)');
    return coreSha256;
  }
}

String mihomoVersion(String rootDir) {
  for (final path in [
    p.join(rootDir, 'core', 'Clash.Meta'),
    p.join(rootDir, 'core'),
  ]) {
    if (!Directory(path).existsSync()) continue;
    try {
      final result = Process.runSync('git', [
        'describe',
        '--tags',
        '--abbrev=0',
      ], workingDirectory: path);
      final version = (result.stdout as String).trim();
      if (result.exitCode == 0 && version.isNotEmpty) return version;
    } catch (_) {}
  }
  return '';
}
