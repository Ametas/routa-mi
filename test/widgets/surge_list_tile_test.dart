import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester, SurgeListTile tile) {
    return tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        child: SurgeCard(padding: EdgeInsets.zero, child: tile),
      ),
    );
  }

  testWidgets('title without subtitle is centred in the row', (tester) async {
    await pumpTile(tester, const SurgeListTile(title: 'Only title'));
    final row = tester.getRect(find.byType(SurgeListTile));
    final title = tester.getRect(find.text('Only title'));
    expect(row.height, greaterThanOrEqualTo(64));
    expect(title.center.dy, moreOrLessEquals(row.center.dy, epsilon: 1));
  });

  testWidgets('dense rows are shorter and still centred', (tester) async {
    await pumpTile(tester, const SurgeListTile(title: 'Dense', dense: true));
    final row = tester.getRect(find.byType(SurgeListTile));
    final title = tester.getRect(find.text('Dense'));
    expect(row.height, moreOrLessEquals(52, epsilon: 0.5));
    expect(title.center.dy, moreOrLessEquals(row.center.dy, epsilon: 1));
  });

  testWidgets('disabled rows ignore taps and dim the title', (tester) async {
    var taps = 0;
    await pumpTile(
      tester,
      SurgeListTile(title: 'Disabled', enabled: false, onTap: () => taps++),
    );
    await tester.tap(find.text('Disabled'));
    expect(taps, 0);
    final surge = SurgeTheme.light();
    final text = tester.widget<Text>(find.text('Disabled'));
    expect(text.style?.color?.a, lessThan(surge.textSecondary.a));
  });

  testWidgets('destructive rows use the red status colour', (tester) async {
    await pumpTile(
      tester,
      SurgeListTile(title: 'Delete', destructive: true, onTap: () {}),
    );
    final context = tester.element(find.text('Delete'));
    final text = tester.widget<Text>(find.text('Delete'));
    expect(text.style?.color, SurgeTheme.of(context).red);
  });
}
