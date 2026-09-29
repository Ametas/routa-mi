import 'package:fl_clash/views/config/dns.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/component_catalog.dart';

// Settings pages are lists of SurgeSections: each group is its own card,
// titles sit above the card, and rows are separated once (no Divider
// widgets stacked on top of the section's own separators).
void main() {
  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(384, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        child: SizedBox(height: 2300, child: page),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  void expectTitleOutsideCard(WidgetTester tester, String title) {
    final finder = find.text(title);
    expect(finder, findsOneWidget);
    expect(
      find.ancestor(of: finder, matching: find.byType(SurgeCard)),
      findsNothing,
      reason: '"$title" should label a card, not be a row inside one',
    );
  }

  testWidgets('network settings are grouped into section cards', (
    tester,
  ) async {
    await pumpPage(tester, const NetworkListView());
    expect(find.byType(SurgeSectionList), findsOneWidget);
    expect(find.byType(SurgeSection), findsAtLeastNWidgets(2));
    expectTitleOutsideCard(tester, 'Options');
    expect(
      find.descendant(
        of: find.byType(SurgeCard),
        matching: find.byType(Divider),
      ),
      findsNothing,
    );
  });

  testWidgets('dns options and fallback filter are separate sections', (
    tester,
  ) async {
    // DnsListView itself reads the profile database; its sections do not.
    await pumpPage(
      tester,
      const SurgeSectionList(sections: [DnsOptions(), FallbackFilterOptions()]),
    );
    expect(find.byType(SurgeSection), findsNWidgets(2));
    expectTitleOutsideCard(tester, 'Options');
    expectTitleOutsideCard(tester, 'Fallback filter');
  });
}
