import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'error.dart';

final _log = Logger('mihomo_patcher');

/// Applies every `core/patches/mihomo/*.patch` to the Mihomo submodule in
/// lexical file-name order. Each patch is idempotent: a patch whose reverse
/// applies cleanly is treated as already applied.
class MihomoPatcher {
  final String rootDir;

  MihomoPatcher({required this.rootDir});

  String get _mihomoPath => p.join(rootDir, 'core', 'Clash.Meta');
  String get _patchesDir => p.join(rootDir, 'core', 'patches', 'mihomo');

  /// Patches that must always be present; guards against an accidental
  /// deletion silently producing a build without them.
  static const _requiredPatches = ['proxy-only-traffic.patch'];

  List<String> get _patchPaths {
    final dir = Directory(_patchesDir);
    if (!dir.existsSync()) return const [];
    final paths =
        dir
            .listSync()
            .whereType<File>()
            .map((file) => file.path)
            .where((path) => path.endsWith('.patch'))
            .toList()
          ..sort((a, b) => p.basename(a).compareTo(p.basename(b)));
    return paths;
  }

  void apply() {
    if (!Directory(_mihomoPath).existsSync()) {
      throw BuildException('Mihomo submodule not found: $_mihomoPath');
    }
    final patchPaths = _patchPaths;
    for (final required in _requiredPatches) {
      if (!patchPaths.any((path) => p.basename(path) == required)) {
        throw BuildException(
          'Required Mihomo patch not found: ${p.join(_patchesDir, required)}',
        );
      }
    }
    for (final patchPath in patchPaths) {
      _applyOne(patchPath);
    }
  }

  void _applyOne(String patchPath) {
    final name = p.basename(patchPath);
    if (_gitApplyCheck(patchPath, reverse: true)) {
      _log.info('Mihomo patch $name is already applied.');
      return;
    }
    if (!_gitApplyCheck(patchPath)) {
      throw BuildException(
        'The Mihomo patch $name is incompatible with this core revision. '
        'Rebase core/patches/mihomo/$name before building or releasing.',
      );
    }

    final arguments = ['apply', '--whitespace=nowarn', patchPath];
    final result = Process.runSync(
      'git',
      arguments,
      workingDirectory: _mihomoPath,
      stdoutEncoding: systemEncoding,
      stderrEncoding: systemEncoding,
    );
    if (result.exitCode != 0) {
      throw CommandFailedException(
        executable: 'git',
        arguments: arguments,
        exitCode: result.exitCode,
        stdout: (result.stdout as String).trim(),
        stderr: (result.stderr as String).trim(),
      );
    }
    _log.info('Applied Mihomo patch $name.');
  }

  bool _gitApplyCheck(String patchPath, {bool reverse = false}) {
    final arguments = [
      'apply',
      if (reverse) '--reverse',
      '--check',
      patchPath,
    ];
    final result = Process.runSync(
      'git',
      arguments,
      workingDirectory: _mihomoPath,
      stdoutEncoding: systemEncoding,
      stderrEncoding: systemEncoding,
    );
    return result.exitCode == 0;
  }
}
