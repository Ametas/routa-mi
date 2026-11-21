import 'dart:async';

/// Full profile applies (a start, a settings change) in flight.
///
/// A display-only apply (provider readiness loading groups) starts a newer
/// commit generation, so it would supersede a full apply still running: the
/// start then gives up and the core stays without the TUN it was asked
/// for. A display-only apply waits here for the full ones instead; they
/// load the groups too.
final class FullApplyGate {
  int _running = 0;
  Completer<void>? _idle;

  bool get busy => _running > 0;

  Future<T> run<T>(Future<T> Function() apply) async {
    _running++;
    try {
      return await runZoned(apply, zoneValues: {this: true});
    } finally {
      _running--;
      if (_running == 0) {
        _idle?.complete();
        _idle = null;
      }
    }
  }

  /// Completes once no full apply runs; at once when none does, or when
  /// asked from inside a full apply, which must not wait for itself.
  Future<void> idle() {
    if (_running == 0 || Zone.current[this] == true) {
      return Future<void>.value();
    }
    return (_idle ??= Completer<void>()).future;
  }
}

/// The TUN a display-only apply hands the core: off while the proxy is
/// stopped (a paused session stays paused), the running TUN otherwise, so
/// loading groups never takes TUN down under a running proxy.
bool displayApplyTun({required bool isStart, required bool runningTun}) =>
    isStart && runningTun;
