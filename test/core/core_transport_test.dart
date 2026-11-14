import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/core/transport.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for RoutaMiCore.exe dialing the app (core/ipc.go).
Future<Socket> dialCore(String address) async {
  final [_, port, token] = address.split(':');
  final socket = await Socket.connect(
    InternetAddress.loopbackIPv4,
    int.parse(port),
  );
  socket.add(encodeFrame(utf8.encode(token)));
  return socket;
}

void main() {
  test('frames survive arbitrary chunking', () {
    final reader = FrameReader();
    final bytes = [
      ...encodeFrame(utf8.encode('first')),
      ...encodeFrame(utf8.encode('')),
      ...encodeFrame(utf8.encode('second')),
    ];
    final frames = <String>[];
    for (var i = 0; i < bytes.length; i += 3) {
      final end = i + 3 > bytes.length ? bytes.length : i + 3;
      frames.addAll(reader.add(bytes.sublist(i, end)).map(utf8.decode));
    }
    expect(frames, ['first', '', 'second']);
    expect(
      ByteData.sublistView(encodeFrame([1, 2])).getUint32(0, Endian.little),
      2,
    );
  });

  test('the core connects with the token and talks in frames', () async {
    final transport = CoreTransport();
    addTearDown(transport.close);
    await transport.init();
    expect(transport.address, matches(RegExp(r'^tcp:\d+:[\w-]{20,}$')));

    final messages = <String>[];
    transport.messages.listen(messages.add);
    final core = await dialCore(transport.address);
    addTearDown(core.destroy);
    await transport.connectionCompleter.future.timeout(
      const Duration(seconds: 5),
    );

    core.add(encodeFrame(utf8.encode('{"id":"1"}')));
    await core.flush();
    final received = Completer<List<Uint8List>>();
    final reader = FrameReader();
    core.listen((data) {
      final frames = reader.add(data);
      if (frames.isNotEmpty && !received.isCompleted) received.complete(frames);
    });
    transport.send('{"method":"init"}');
    final frames = await received.future.timeout(const Duration(seconds: 5));
    expect(utf8.decode(frames.single), '{"method":"init"}');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(messages, ['{"id":"1"}']);
  });

  test('a connection without the token is dropped', () async {
    final transport = CoreTransport();
    addTearDown(transport.close);
    await transport.init();
    final port = transport.address.split(':')[1];
    final intruder = await Socket.connect(
      InternetAddress.loopbackIPv4,
      int.parse(port),
    );
    intruder.add(encodeFrame(utf8.encode('guess')));
    await intruder.drain<void>().timeout(const Duration(seconds: 5));
    expect(transport.connectionCompleter.isCompleted, isFalse);
  });

  test('a dropped core reports the disconnect', () async {
    final transport = CoreTransport();
    addTearDown(transport.close);
    final disconnected = Completer<void>();
    transport.onDisconnect = disconnected.complete;
    await transport.init();
    final core = await dialCore(transport.address);
    await transport.connectionCompleter.future;
    core.destroy();
    await disconnected.future.timeout(const Duration(seconds: 5));
    expect(transport.connectionCompleter.isCompleted, isFalse);
  });
}
