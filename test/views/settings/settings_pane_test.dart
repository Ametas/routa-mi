import 'package:fl_clash/views/settings/settings_pane.dart';
import 'package:fl_clash/views/settings/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/component_catalog.dart';

void main() {
  Widget page(String text) => Center(child: Text('$text page'));

  Widget host() => catalogApp(
    brightness: Brightness.dark,
    textScale: 1,
    child: SizedBox(
      width: 1000,
      height: 600,
      child: SettingsTwoPane(
        initial: SettingsPaneSection(
          title: 'Theme',
          page: (_) => page('Theme'),
        ),
        list: SettingsGroup(
          label: 'Interface',
          children: [
            SettingsPageEntry(
              icon: const Icon(Icons.palette),
              title: 'Theme',
              page: (_) => page('Theme'),
            ),
            SettingsPageEntry(
              icon: const Icon(Icons.dns),
              title: 'DNS',
              page: (_) => page('DNS'),
            ),
          ],
        ),
      ),
    ),
  );

  bool selected(WidgetTester tester, String title) => tester
      .widget<SettingsTile>(
        find.ancestor(
          of: find.text(title),
          matching: find.byType(SettingsTile),
        ),
      )
      .selected;

  testWidgets('a row shows its page beside the list instead of opening it', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('Theme page'), findsOneWidget);
    expect(selected(tester, 'Theme'), isTrue);
    expect(selected(tester, 'DNS'), isFalse);

    await tester.tap(find.text('DNS'));
    await tester.pump();
    // Both pages while one fades into the other.
    expect(find.text('Theme page'), findsOneWidget);
    expect(find.text('DNS page'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Theme page'), findsNothing);
    expect(find.text('DNS page'), findsOneWidget);
    expect(selected(tester, 'DNS'), isTrue);
    // Nothing was pushed over the list.
    expect(find.byType(SettingsGroup), findsOneWidget);
  });
}
