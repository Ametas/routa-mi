import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

/// Registers URL schemes (clash://install-config?url=…) for the current user.
class Protocol {
  static Protocol? _instance;

  Protocol._internal();

  factory Protocol() {
    _instance ??= Protocol._internal();
    return _instance!;
  }

  void register(String scheme) {
    final key = Registry.currentUser.createKey('Software\\Classes\\$scheme');
    key.createValue(const RegistryValue.string('URL Protocol', ''));
    key
        .createKey('shell\\open\\command')
        .createValue(
          RegistryValue.string('', '"${Platform.resolvedExecutable}" "%1"'),
        );
  }
}

final protocol = Protocol();
