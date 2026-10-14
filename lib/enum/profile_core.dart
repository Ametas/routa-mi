import 'dart:convert';

/// The core a profile runs on: mihomo for Clash YAML, Xray for Xray JSON.
enum ProfileCore { mihomo, xray }

extension ProfileCoreLabel on ProfileCore {
  /// Badge and switch label.
  String get label => switch (this) {
    ProfileCore.mihomo => 'mihomo',
    ProfileCore.xray => 'Xray',
  };
}

/// The core [bytes] are written for, or null when the content cannot tell
/// (share links, base64): then the core the user picked stays.
///
/// Xray JSON is one config object or, from panels like Remnawave, an array
/// of them (one per node). JSON with Clash keys is still a mihomo profile:
/// YAML is a superset of JSON.
ProfileCore? detectProfileCore(List<int> bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  text = text.trimLeft();
  if (text.isEmpty) return null;
  if (text.startsWith('{') || text.startsWith('[')) {
    final Object? value;
    try {
      value = jsonDecode(text);
    } on FormatException {
      return ProfileCore.mihomo; // YAML flow syntax, not JSON.
    }
    if (value is List) {
      return value.isNotEmpty && value.every(_isXrayConfig)
          ? ProfileCore.xray
          : null;
    }
    if (value is Map) {
      if (_isXrayConfig(value)) return ProfileCore.xray;
      if (_clashKeys.any(value.containsKey)) return ProfileCore.mihomo;
    }
    return null;
  }
  // A YAML mapping starts with `key:`; share links and base64 do not.
  final firstLine = text.split('\n').first.trim();
  if (firstLine.contains('://')) return null;
  return RegExp(r'^[\w.-]+\s*:').hasMatch(firstLine) ||
          firstLine.startsWith('#')
      ? ProfileCore.mihomo
      : null;
}

const _clashKeys = ['proxies', 'proxy-groups', 'proxy-providers', 'rules'];

bool _isXrayConfig(Object? value) =>
    value is Map &&
    (value.containsKey('outbounds') || value.containsKey('inbounds'));
