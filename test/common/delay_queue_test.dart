import 'dart:async';

import 'package:fl_clash/common/delay_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'no more than the limit run at once; the rest wait their turn',
    () async {
      final queue = DelayTestQueue(concurrency: 3);
      final gates = List.generate(8, (_) => Completer<String>());
      var peak = 0;
      var started = 0;
      final results = [
        for (var i = 0; i < gates.length; i++)
          queue.run('node$i', () {
            started++;
            if (queue.running > peak) peak = queue.running;
            return gates[i].future;
          }),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(started, 3);
      for (var i = 0; i < gates.length; i++) {
        gates[i].complete('$i');
        await Future<void>.delayed(Duration.zero);
      }
      expect(await Future.wait(results), [for (var i = 0; i < 8; i++) '$i']);
      expect(peak, 3);
      expect(queue.running, 0);
    },
  );

  test('overlapping tests of one node share a run', () async {
    final queue = DelayTestQueue();
    final gate = Completer<String>();
    var runs = 0;
    Future<String> test() {
      runs++;
      return gate.future;
    }

    final a = queue.run('url\nEmerald', test);
    final b = queue.run('url\nEmerald', test);
    gate.complete('86');
    expect(await a, '86');
    expect(await b, '86');
    expect(runs, 1);
    // Once settled, the next request tests again.
    await queue.run('url\nEmerald', () async => '90');
    expect(runs, 1);
  });

  test('a failed test frees its slot', () async {
    final queue = DelayTestQueue(concurrency: 1);
    await expectLater(
      queue.run('bad', () async => throw StateError('core gone')),
      throwsStateError,
    );
    expect(await queue.run('next', () async => 'ok'), 'ok');
    expect(queue.running, 0);
  });

  test('the app waits longer than the core may test', () {
    expect(delayTestTimeout, const Duration(seconds: 10));
    expect(delayTestAnswerGrace, greaterThan(Duration.zero));
  });
}
