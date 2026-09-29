import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

Widget _row({
  Widget? subtitle,
  bool? dense,
  double? minTileHeight,
  bool enabled = true,
  Color? leadingColor,
  VoidCallback? onTap,
  ListTileTitleAlignment alignment = ListTileTitleAlignment.center,
}) {
  return SurgeRow(
    title: const Text('Title'),
    subtitle: subtitle,
    leading: const Icon(SurgeIcons.logs),
    dense: dense,
    minTileHeight: minTileHeight,
    enabled: enabled,
    leadingColor: leadingColor,
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: SurgeSpace.l),
    minVerticalPadding: 0,
    titleAlignment: alignment,
  );
}

void main() {
  Future<void> pump(WidgetTester tester, Widget row) => tester.pumpWidget(
    catalogApp(brightness: Brightness.light, textScale: 1, child: row),
  );

  double height(WidgetTester tester) =>
      tester.getSize(find.byType(SurgeRow)).height;

  testWidgets('minimum heights follow density and subtitle', (tester) async {
    await pump(tester, _row());
    expect(height(tester), 56);
    await pump(tester, _row(subtitle: const Text('Subtitle')));
    expect(height(tester), 68);
    await pump(tester, _row(dense: true));
    expect(height(tester), 48);
    await pump(tester, _row(dense: true, subtitle: const Text('Subtitle')));
    expect(height(tester), 60);
    await pump(tester, _row(minTileHeight: 80));
    expect(height(tester), 80);
  });

  testWidgets('subtitle uses the secondary text colour', (tester) async {
    await pump(tester, _row(subtitle: const Text('Subtitle')));
    final surge = SurgeTheme.of(tester.element(find.text('Subtitle')));
    final style = DefaultTextStyle.of(tester.element(find.text('Subtitle')));
    expect(style.style.color, surge.textSecondary);
  });

  testWidgets('leading icon colour can be overridden', (tester) async {
    await pump(tester, _row(leadingColor: Colors.red));
    final icon = IconTheme.of(tester.element(find.byIcon(SurgeIcons.logs)));
    expect(icon.color, Colors.red);
  });

  testWidgets('disabled rows ignore taps', (tester) async {
    var taps = 0;
    await pump(tester, _row(enabled: false, onTap: () => taps++));
    await tester.tap(find.text('Title'));
    expect(taps, 0);
    await pump(tester, _row(onTap: () => taps++));
    await tester.tap(find.text('Title'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('top alignment pins the title to the top', (tester) async {
    await pump(
      tester,
      _row(minTileHeight: 120, alignment: ListTileTitleAlignment.top),
    );
    final row = tester.getRect(find.byType(SurgeRow));
    final title = tester.getRect(find.text('Title'));
    expect(title.top - row.top, lessThan(row.height / 4));
  });
}
