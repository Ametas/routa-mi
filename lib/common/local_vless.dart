import 'dart:math';

import 'package:fl_clash/models/models.dart';

/// Optional plain VLESS inbound for local clients, modelled on the SOCKS
/// authentication (`local_proxy_auth.dart`): off by default; when on, its
/// random UUID is the credential and RoutaMi owns the listener.
///
/// Plain means no TLS, Reality or transport: it is meant for loopback, or
/// the LAN when "Allow LAN" is on, like the mixed port.
abstract final class LocalVless {
  static const listenerName = 'routami-vless';
  static const username = 'routami';
  static const minPort = 1024;
  static const maxPort = 49151;

  static final uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  /// Random version 4 UUID from [Random.secure].
  static String generateUuid({Random? random}) {
    final source = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => source.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Null when [port] can be used: in range and not taken by another
  /// inbound of [patch].
  static String? portError(int? port, PatchClashConfig patch) {
    if (port == null || port < minPort || port > maxPort) {
      return '$minPort–$maxPort';
    }
    final taken = {
      patch.mixedPort,
      patch.socksPort,
      patch.port,
      patch.redirPort,
      patch.tproxyPort,
    }..remove(0);
    return taken.contains(port) ? 'port $port' : null;
  }
}

extension LocalVlessPropsListener on LocalVlessProps {
  bool get isComplete => uuid.isNotEmpty;

  /// mihomo `listeners` entry, or null when the inbound is off.
  Map<String, dynamic>? listener({required bool allowLan}) {
    if (!enable || !isComplete) return null;
    return {
      'name': LocalVless.listenerName,
      'type': 'vless',
      'listen': allowLan ? '0.0.0.0' : '127.0.0.1',
      'port': port,
      // mihomo refuses a VLESS listener without TLS/Reality/decryption
      // unless this is set explicitly.
      'allow-insecure': true,
      'users': [
        {'username': LocalVless.username, 'uuid': uuid},
      ],
    };
  }

  /// `vless://` share link for clients on this device.
  String shareLink({String host = '127.0.0.1'}) =>
      'vless://$uuid@$host:$port?encryption=none&security=none&type=tcp'
      '#RoutaMi';
}

/// Fills in the UUID when the inbound is on but has none yet.
NetworkProps ensureLocalVlessUuid(NetworkProps props, {Random? random}) {
  final vless = props.localVless;
  if (!vless.enable || vless.isComplete) return props;
  return props.copyWith(
    localVless: vless.copyWith(uuid: LocalVless.generateUuid(random: random)),
  );
}
