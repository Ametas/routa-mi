import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

void main() {
  Future<SurgeTheme> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      catalogApp(brightness: Brightness.light, textScale: 1, child: child),
    );
    return SurgeTheme.of(tester.element(find.byType(Scaffold)));
  }

  testWidgets('actions share one row below the content', (tester) async {
    await pump(
      tester,
      CommonDialog(
        title: 'Title',
        actions: [
          SurgeDialogActionButton(label: 'Cancel', onPressed: () {}),
          SurgeDialogActionButton(
            label: 'Confirm',
            primary: true,
            onPressed: () {},
          ),
        ],
        child: const Text('Body'),
      ),
    );
    // Not the Material actions bar: the buttons are part of the content.
    expect(find.byType(OverflowBar), findsNothing);
    final cancel = tester.getRect(find.text('Cancel'));
    final confirm = tester.getRect(find.text('Confirm'));
    final body = tester.getRect(find.text('Body'));
    expect(cancel.center.dy, moreOrLessEquals(confirm.center.dy));
    expect(cancel.center.dx, lessThan(confirm.center.dx));
    expect(cancel.top, greaterThan(body.bottom + SurgeSpace.l));
    final left = tester.getSize(find.byType(FilledButton).first);
    final right = tester.getSize(find.byType(FilledButton).last);
    expect(left.width, moreOrLessEquals(right.width));
  });

  testWidgets('without actions the dialog is just the content', (tester) async {
    await pump(tester, const CommonDialog(title: 'Title', child: Text('Body')));
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('destructive action is tinted red', (tester) async {
    final surge = await pump(
      tester,
      Row(
        children: [
          SurgeDialogActionButton(
            label: 'Remove',
            destructive: true,
            onPressed: () {},
          ),
        ],
      ),
    );
    final style = tester.widget<FilledButton>(find.byType(FilledButton)).style!;
    expect(
      style.backgroundColor!.resolve({}),
      surge.red.withValues(alpha: SurgeAlpha.a12),
    );
    expect(style.foregroundColor!.resolve({}), surge.red);
  });

  testWidgets('showMessage uses Surge buttons: cancel, then confirm', (
    tester,
  ) async {
    globalState.container = ProviderContainer();
    addTearDown(globalState.container.dispose);
    await pump(tester, const SizedBox());
    final result = globalState.showMessage(
      context: tester.element(find.byType(Scaffold)),
      message: const TextSpan(text: 'Remove the profile?'),
    );
    await tester.pumpAndSettle();
    final buttons = tester
        .widgetList<SurgeDialogActionButton>(
          find.byType(SurgeDialogActionButton),
        )
        .toList();
    expect(buttons.map((b) => b.primary), [false, true]);
    expect(find.byType(TextButton), findsNothing);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });
}
