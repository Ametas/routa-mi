import 'dart:io';

import 'package:fl_clash/common/common.dart';

/// One RoutaMi window per user on Windows: a second launch exits.
class SingleInstanceLock {
  static SingleInstanceLock? _instance;
  RandomAccessFile? _accessFile;

  SingleInstanceLock._internal();

  factory SingleInstanceLock() {
    _instance ??= SingleInstanceLock._internal();
    return _instance!;
  }

  Future<bool> acquire() async {
    try {
      final lockFile = File(await appPath.lockFilePath);
      await lockFile.create(recursive: true);
      _accessFile = await lockFile.open(mode: FileMode.write);
      await _accessFile?.lock();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final singleInstanceLock = SingleInstanceLock();
