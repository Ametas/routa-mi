import 'package:fl_clash/enum/enum.dart';

/// How long the helper service may take to start the core: it hashes the
/// whole RoutaMiCore.exe first (and Defender scans it on a first read), and
/// an app that gave up early would start a second core of its own.
const helperStartTimeout = Duration(seconds: 15);

/// Whether TUN can be switched on while the helper service runs (Windows).
/// Only a core the helper started runs as LocalSystem and can create the
/// Wintun adapter; a core the app started itself cannot, whatever the
/// service does.
AuthorizeCode tunAuthorizationWithService({
  required bool coreUnderHelper,
  required String? helperError,
}) {
  if (coreUnderHelper) return AuthorizeCode.none;
  // The core started before the service ran: restart it through the service.
  if (helperError == null) return AuthorizeCode.success;
  // The service refused the core: restarting would only refuse again.
  return AuthorizeCode.error;
}
