import 'dart:async';
import 'dart:io';

import 'package:fl_clash/services/mihomo_config/full_apply_gate.dart';
import 'package:fl_clash/services/mihomo_config/runtime_config_commit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a display apply waits for a start instead of superseding it', () async {
    // The CI race: a start (with TUN) is materializing when provider
    // readiness applies the profile for display (TUN off). Without the gate
    // the later request wins and the start gives up.
    final owner = RuntimeConfigCommitOwner();
    final gate = FullApplyGate();
    final committed = <String>[];
    final materialized = Completer<void>();

    Future<RuntimeConfigCommitOutcome> apply(
      String name,
      Future<void> work,
    ) async {
      final generation = owner.beginRequest();
      await work;
      return owner.commit(
        generation: generation,
        transaction: (_) async => committed.add(name),
      );
    }

    final start = gate.run(() => apply('start+tun', materialized.future));
    final display = gate.idle().then((_) => apply('display', Future.value()));
    await Future<void>.delayed(Duration.zero);
    materialized.complete();

    expect(await start, RuntimeConfigCommitOutcome.committed);
    expect(await display, RuntimeConfigCommitOutcome.committed);
    expect(committed, ['start+tun', 'display']);
  });

  test(
    'idle is immediate when nothing runs or from inside a full apply',
    () async {
      final gate = FullApplyGate();
      await gate.idle();
      var inner = false;
      await gate.run(() async {
        await gate.idle();
        inner = true;
      });
      expect(inner, isTrue);
      expect(gate.busy, isFalse);
    },
  );

  test('a failing full apply still releases the waiters', () async {
    final gate = FullApplyGate();
    final failing = gate.run<void>(() async => throw StateError('core gone'));
    final waiting = gate.idle();
    await expectLater(failing, throwsStateError);
    await waiting;
    expect(gate.busy, isFalse);
  });

  test('a display apply keeps a running TUN and never brings one up', () {
    expect(displayApplyTun(isStart: true, runningTun: true), isTrue);
    expect(displayApplyTun(isStart: true, runningTun: false), isFalse);
    expect(displayApplyTun(isStart: false, runningTun: true), isFalse);
    expect(displayApplyTun(isStart: false, runningTun: false), isFalse);
  });

  test('starts and settings changes run through the gate', () {
    final source = File('lib/providers/action.dart').readAsStringSync();
    expect(
      RegExp(
        r'_fullApplies\.run\(\s*\(\) => _applyProfileOutcome\(',
      ).allMatches(source).length,
      2,
    );
    expect(source, contains('() => _applySettingsSnapshot('));
    final display = source.substring(
      source.indexOf(
        'Future<SetupConfigOutcome> _applyProfileForDisplayOutcome',
      ),
    );
    expect(
      display.substring(0, 400),
      contains('if (inheritedContext == null) await _fullApplies.idle();'),
    );
  });
}
