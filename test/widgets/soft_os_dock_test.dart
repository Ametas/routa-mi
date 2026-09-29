import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

Widget _dock(
  SoftOsDockStyle style, {
  VoidCallback? onPressed,
  bool loading = false,
}) {
  return Row(
    children: [
      SoftOsActionDock(
        style: style,
        children: [
          SoftOsActionDockButton(
            tooltip: 'Search',
            icon: SurgeIcons.search,
            loading: loading,
            onPressed: onPressed,
          ),
          const SoftOsDockDivider(),
          SoftOsActionDockButton(
            tooltip: 'Add',
            icon: SurgeIcons.add,
            onPressed: () {},
          ),
        ],
      ),
    ],
  );
}

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    catalogApp(brightness: Brightness.light, textScale: 1, child: child),
  );

  List<BoxDecoration> dockDecorations(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(SoftOsActionDock),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .where((decoration) => decoration.borderRadius != null)
      .toList();

  testWidgets('raised docks cast a shadow, inset docks are flat', (
    tester,
  ) async {
    await pump(tester, _dock(SoftOsDockStyle.raised, onPressed: () {}));
    expect(
      dockDecorations(tester).any((d) => (d.boxShadow ?? []).isNotEmpty),
      isTrue,
    );

    await pump(tester, _dock(SoftOsDockStyle.inset, onPressed: () {}));
    final inset = dockDecorations(tester);
    expect(inset, isNotEmpty);
    expect(inset.every((d) => (d.boxShadow ?? []).isEmpty), isTrue);
  });

  for (final style in SoftOsDockStyle.values) {
    testWidgets('${style.name} buttons press and stop while loading', (
      tester,
    ) async {
      var taps = 0;
      await pump(tester, _dock(style, onPressed: () => taps++));
      await tester.tap(find.byIcon(SurgeIcons.search));
      await tester.pumpAndSettle();
      expect(taps, 1);

      await pump(tester, _dock(style, loading: true, onPressed: () => taps++));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(
        find.byType(CircularProgressIndicator),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 1);
    });
  }

  testWidgets('inset buttons use the dock button metrics', (tester) async {
    await pump(tester, _dock(SoftOsDockStyle.inset, onPressed: () {}));
    final context = tester.element(find.byIcon(SurgeIcons.search));
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final button = tester.getSize(
      find.ancestor(
        of: find.byIcon(SurgeIcons.search),
        matching: find.byType(SurgePressable),
      ),
    );
    expect(
      button.width,
      moreOrLessEquals(metrics.value(surge.controls.dockButtonWidth)),
    );
    final icon = tester.widget<Icon>(find.byIcon(SurgeIcons.search));
    expect(
      icon.size,
      moreOrLessEquals(metrics.value(surge.controls.dockButtonIconSize)),
    );
  });
}
