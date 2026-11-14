import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// The Windows link to the core process (`core/ipc.go`): the app listens on
/// 127.0.0.1 and the core connects with `tcp:PORT:TOKEN`. The first frame
/// must be the token, so no other local process can pose as the core.
/// Frames are a 4-byte little-endian length and a UTF-8 JSON payload.
class CoreTransport {
  ServerSocket? _server;
  Socket? _socket;
  final _token = base64Url
      .encode(List.generate(24, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');
  Completer<void> _connected = Completer<void>();
  final _messages = StreamController<String>.broadcast();

  /// Called when the core connection drops.
  void Function()? onDisconnect;

  Stream<String> get messages => _messages.stream;

  Completer<void> get connectionCompleter => _connected;

  /// The argument the core process is started with.
  String get address => 'tcp:${_server!.port}:$_token';

  Future<void> init() async {
    _server ??= await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_accept);
  }

  void _accept(Socket socket) {
    var authenticated = false;
    final reader = FrameReader();
    socket.listen(
      (data) {
        for (final frame in reader.add(data)) {
          if (!authenticated) {
            if (utf8.decode(frame, allowMalformed: true) != _token) {
              socket.destroy();
              return;
            }
            authenticated = true;
            _socket?.destroy();
            _socket = socket;
            if (!_connected.isCompleted) _connected.complete();
            continue;
          }
          _messages.add(utf8.decode(frame));
        }
      },
      onDone: () => _closed(socket),
      onError: (_) => _closed(socket),
      cancelOnError: true,
    );
  }

  void _closed(Socket socket) {
    if (!identical(socket, _socket)) return;
    _socket = null;
    _connected = Completer<void>();
    onDisconnect?.call();
  }

  void send(String message) {
    _socket?.add(encodeFrame(utf8.encode(message)));
  }

  /// Forgets the current core connection before a restart.
  void disconnected() {
    _socket?.destroy();
    _socket = null;
    _connected = Completer<void>();
  }

  Future<void> close() async {
    disconnected();
    await _server?.close();
    _server = null;
    await _messages.close();
  }
}

Uint8List encodeFrame(List<int> payload) {
  final frame = Uint8List(4 + payload.length);
  ByteData.sublistView(frame).setUint32(0, payload.length, Endian.little);
  frame.setRange(4, frame.length, payload);
  return frame;
}

/// Splits a byte stream into length-prefixed frames.
class FrameReader {
  final _buffer = BytesBuilder(copy: false);
  Uint8List _pending = Uint8List(0);

  List<Uint8List> add(List<int> data) {
    _buffer.add(_pending);
    _buffer.add(data);
    var bytes = _buffer.takeBytes();
    final frames = <Uint8List>[];
    while (bytes.length >= 4) {
      final length = ByteData.sublistView(bytes).getUint32(0, Endian.little);
      if (bytes.length < 4 + length) break;
      frames.add(Uint8List.sublistView(bytes, 4, 4 + length));
      bytes = Uint8List.sublistView(bytes, 4 + length);
    }
    _pending = Uint8List.fromList(bytes);
    return frames;
  }
}
