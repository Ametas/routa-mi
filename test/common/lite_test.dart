import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/lite.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';

void main() {
  test('lite.json is read only when complete', () {
    expect(parseLiteState('{"pid":12,"port":5000,"token":"t"}'), (
      pid: 12,
      port: 5000,
      token: 't',
    ));
    expect(parseLiteState('{"pid":12,"port":5000,"token":""}'), isNull);
    expect(parseLiteState('{"port":"5000"}'), isNull);
    expect(parseLiteState('not json'), isNull);
  });

  test('the tray address and attach reply', () {
    expect(parseLiteCoreAddress('{"core":"tcp:5000:abc"}'), 'tcp:5000:abc');
    expect(parseLiteCoreAddress('{"core":"5000"}'), isNull);
    expect(parseLiteCoreAddress('garbage'), isNull);
    expect(parseLiteAttach('{"running":true,"helper":false}'), (
      running: true,
      helper: false,
    ));
  });

  test('the snapshot names the files next to RoutaMi.exe', () {
    final dir = join('C:', 'Program Files', 'RoutaMi');
    final snapshot = liteSnapshot(
      statePath: 'lite.json',
      executableDir: dir,
      corePath: join(dir, 'RoutaMiCore.exe'),
      helper: true,
      tun: true,
      systemProxy: true,
      port: 7890,
      bypass: const ['localhost'],
      labels: const {'open': 'Show'},
    );
    expect(snapshot['app'], join(dir, 'RoutaMi.exe'));
    expect(snapshot['helper'], isTrue);
    expect(snapshot['systemProxy'], {
      'enable': true,
      'port': 7890,
      'bypass': ['localhost'],
    });
    final icons = snapshot['icons'] as Map;
    expect(
      icons['tun'],
      join(
        dir,
        'data',
        'flutter_assets',
        'assets',
        'images',
        'icon',
        'status_3.ico',
      ),
    );
  });

  test('the Dart and Go sides agree on the tray', () {
    final helper = File('core/helper/helper.go').readAsStringSync();
    final builder = File(
      'plugins/setup/buildkit/build_tool/lib/src/windows_builder.dart',
    ).readAsStringSync();
    final installer = File('windows/packaging/routami.iss').readAsStringSync();
    const name = LiteMode.trayExecutableName;
    expect(helper, contains('trayExeName = "$name"'));
    expect(builder, contains("trayName = '$name'"));
    expect(installer, contains('/IM $name'));
    // lite.json fields and the tray's control API (core/tray/lite.go).
    final tray = File('core/tray/lite.go').readAsStringSync();
    for (final key in ['"pid"', '"port"', '"token"', '"running"']) {
      expect(tray, contains(key));
    }
    for (final route in ['GET /status', 'POST /attach']) {
      expect(tray, contains(route));
    }
  });

  test('every core action encodes, handover included', () {
    for (final method in ActionMethod.values) {
      final frame = jsonEncode(Action(id: '1', method: method, data: 'x'));
      expect(frame, contains('"method":"${method.name}"'));
    }
  });
}
