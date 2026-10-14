import 'dart:convert';

import 'package:fl_clash/enum/profile_core.dart';
import 'package:flutter_test/flutter_test.dart';

ProfileCore? detect(String text) => detectProfileCore(utf8.encode(text));

void main() {
  test('Xray JSON: one config or a panel array of configs', () {
    expect(detect('{"outbounds": [{"protocol": "vless"}]}'), ProfileCore.xray);
    expect(
      detect('﻿  [{"remarks": "JP", "outbounds": []}, {"inbounds": []}]'),
      ProfileCore.xray,
    );
  });

  test('Clash YAML, also written as JSON, is mihomo', () {
    expect(detect('mixed-port: 7890\nproxies: []\n'), ProfileCore.mihomo);
    expect(detect('# comment\nproxies:\n  - name: a\n'), ProfileCore.mihomo);
    expect(detect('{"proxies": [], "rules": []}'), ProfileCore.mihomo);
    expect(detect('{proxies: []}'), ProfileCore.mihomo); // YAML flow
  });

  test('links and unknown content keep the chosen core', () {
    expect(detect('vless://id@host:443#JP\nvmess://abc'), isNull);
    expect(detect(base64.encode(utf8.encode('vless://id@h:1'))), isNull);
    expect(detect('[1, 2]'), isNull);
    expect(detect('{"foo": 1}'), isNull);
    expect(detect(''), isNull);
  });
}
