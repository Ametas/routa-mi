import 'dart:math';

import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-owned authentication of the local http/socks/mixed listeners.
///
/// Without it any app on the device could send traffic through the tunnel
/// via `127.0.0.1:<mixed-port>` and skip per-app rules. RoutaMi turns it on
/// by default with random credentials and always owns the result: the
/// profile's own `authentication` and `skip-auth-prefixes` are replaced.
abstract final class LocalProxyAuth {
  static const usernameLength = 16;
  static const passwordLength = 32;

  /// URL-unreserved characters: credentials go into `user:pass@host` proxy
  /// strings unescaped, and mihomo splits `user:pass` on the first colon.
  static final allowedPattern = RegExp(r'^[A-Za-z0-9._~-]+$');

  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  static String randomSecret(int length, {Random? random}) {
    final source = random ?? Random.secure();
    return String.fromCharCodes(
      List.generate(
        length,
        (_) => _alphabet.codeUnitAt(source.nextInt(_alphabet.length)),
      ),
    );
  }

  static AuthenticationProps generate({Random? random}) {
    return AuthenticationProps(
      username: randomSecret(usernameLength, random: random),
      password: randomSecret(passwordLength, random: random),
    );
  }
}

extension AuthenticationPropsCredentials on AuthenticationProps {
  bool get isComplete => username.isNotEmpty && password.isNotEmpty;

  /// mihomo `authentication` entries; empty when authentication is off.
  List<String> get credentials =>
      enable && isComplete ? ['$username:$password'] : const [];

  /// `user:pass@` for proxy strings of the app's own clients.
  String get proxyUserInfo =>
      enable && isComplete ? '$username:$password@' : '';

  /// `HttpClient.findProxy` directive for the local mixed port; dart:io sends
  /// the credentials as `Proxy-Authorization` (also on CONNECT).
  String proxyDirective(String host, int port) =>
      'PROXY $proxyUserInfo$host:$port';
}

/// Fills in credentials when authentication is on but none exist yet:
/// a fresh install, a reset, or a backup made before this setting existed.
NetworkProps ensureLocalProxyCredentials(NetworkProps props, {Random? random}) {
  final authentication = props.authentication;
  if (!authentication.enable || authentication.isComplete) return props;
  final generated = LocalProxyAuth.generate(random: random);
  return props.copyWith(
    authentication: authentication.copyWith(
      username: authentication.username.isEmpty
          ? generated.username
          : authentication.username,
      password: authentication.password.isEmpty
          ? generated.password
          : authentication.password,
    ),
  );
}

/// Keeps credentials present for the lifetime of [container], whichever
/// path wrote the network settings.
void keepLocalProxyCredentials(ProviderContainer container) {
  container.listen<NetworkProps>(networkSettingProvider, (_, next) {
    final ensured = ensureLocalProxyCredentials(next);
    if (!identical(ensured, next)) {
      container.read(networkSettingProvider.notifier).value = ensured;
    }
  }, fireImmediately: true);
}
