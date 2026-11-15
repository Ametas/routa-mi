import 'dart:async';
import 'dart:collection';

/// How long the core may spend on one delay test (Clash Verge Rev uses 10 s).
const delayTestTimeout = Duration(seconds: 10);

/// How much longer the app waits for the answer: IPC and the core's own
/// scheduling. The app must never give up before the core does.
const delayTestAnswerGrace = Duration(seconds: 3);

/// Delay tests in flight at once. Firing every node of a profile at the core
/// together made the later ones wait in the core's queue while the app's
/// deadline ran, and race each other's handshakes: they came back "Timeout"
/// although the nodes answered a moment later.
const delayTestConcurrency = 10;

/// Runs delay tests a few at a time; tests of the same node and URL that
/// overlap share one run (proxy groups resolve to the node they use).
class DelayTestQueue {
  DelayTestQueue({this.concurrency = delayTestConcurrency});

  final int concurrency;

  int _running = 0;
  final _waiting = Queue<Completer<void>>();
  final _inFlight = <String, Future<String>>{};

  int get running => _running;

  Future<String> run(String key, Future<String> Function() test) {
    return _inFlight[key] ??= _schedule(key, test);
  }

  Future<String> _schedule(String key, Future<String> Function() test) async {
    try {
      if (_running >= concurrency) {
        final slot = Completer<void>();
        _waiting.add(slot);
        await slot.future;
      }
      _running++;
      try {
        return await test();
      } finally {
        _running--;
        if (_waiting.isNotEmpty) _waiting.removeFirst().complete();
      }
    } finally {
      _inFlight.remove(key);
    }
  }
}

final delayTestQueue = DelayTestQueue();
