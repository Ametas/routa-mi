import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

void main() {
  Future<SurgeTheme> pump(WidgetTester tester, Widget tile) async {
    await tester.pumpWidget(
      catalogApp(brightness: Brightness.light, textScale: 1, child: tile),
    );
    return SurgeTheme.of(tester.element(find.byType(SurgeIconTile)));
  }

  BoxDecoration decoration(WidgetTester tester) =>
      tester
              .widget<Container>(
                find.descendant(
                  of: find.byType(SurgeIconTile),
                  matching: find.byType(Container),
                ),
              )
              .decoration!
          as BoxDecoration;

  testWidgets('rounded tiles use the input radius and scale alphas', (
    tester,
  ) async {
    final surge = await pump(
      tester,
      const SurgeIconTile(icon: SurgeIcons.logs, color: Colors.blue),
    );
    final box = decoration(tester);
    expect(box.borderRadius, BorderRadius.circular(surge.radii.input));
    expect(box.color, Colors.blue.withValues(alpha: SurgeAlpha.a08));
    final icon = tester.widget<Icon>(find.byIcon(SurgeIcons.logs));
    expect(icon.size, SurgeIconSize.inline);
    expect(icon.color, Colors.blue.withValues(alpha: SurgeAlpha.a92));
    expect(tester.getSize(find.byType(SurgeIconTile)), const Size(30, 30));
  });

  testWidgets('circle tiles are fully rounded', (tester) async {
    await pump(
      tester,
      const SurgeIconTile(
        icon: SurgeIcons.logs,
        color: Colors.blue,
        size: 40,
        shape: SurgeIconTileShape.circle,
      ),
    );
    expect(decoration(tester).borderRadius, BorderRadius.circular(20));
  });

  testWidgets('section subtitle sits next to the title', (tester) async {
    await tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        child: const SurgeSection(
          title: 'Sort profiles',
          subtitle: '2',
          children: [SurgeListTile(title: 'Home')],
        ),
      ),
    );
    expect(find.textContaining('Sort profiles'), findsOneWidget);
    expect(find.textContaining('2', findRichText: true), findsWidgets);
  });
}
