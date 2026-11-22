import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widgets/home_group_panel.dart';
import 'package:fl_clash/views/dashboard/widgets/home_panels.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/component_catalog.dart';

const _group = Group(
  type: GroupType.URLTest,
  name: '◈ Auto',
  now: '🇫🇮 Legacy',
  all: [
    Proxy(name: '🇩🇪 Emerald', type: 'Vless'),
    Proxy(name: '🇫🇮 Legacy', type: 'Vless'),
    Proxy(name: '🇵🇱 Syrena', type: 'Trojan'),
    Proxy(name: '🇳🇱 Delta', type: 'Hysteria2'),
    Proxy(name: '🇪🇪 Toompea', type: 'Shadowsocks'),
    Proxy(name: 'DIRECT', type: 'Direct'),
  ],
);

const _manual = Group(
  type: GroupType.Selector,
  name: 'Manual',
  now: '🇩🇪 Emerald',
  all: [
    Proxy(name: '🇩🇪 Emerald', type: 'Vless'),
    Proxy(name: 'DIRECT', type: 'Direct'),
  ],
);

void main() {
  Widget host({bool expand = false}) => catalogApp(
    brightness: Brightness.dark,
    textScale: 1,
    overrides: [
      profilesProvider.overrideWithBuild((_, _) => const []),
      currentGroupsStateProvider.overrideWithValue(
        const GroupsState(value: [_group, _manual]),
      ),
      selectedProxyNameProvider(_group.name).overrideWithValue('🇫🇮 Legacy'),
      selectedProxyNameProvider(_manual.name).overrideWithValue('🇩🇪 Emerald'),
    ],
    child: expand
        ? const SizedBox(height: 600, child: HomeGroupPanel(expand: true))
        : const SingleChildScrollView(child: HomeGroupPanel()),
  );

  testWidgets('the group panel keeps the profile order of a selector', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();

    // The title loses its symbol to the icon rule; the type is a chip.
    expect(find.text('Auto', findRichText: true), findsOneWidget);
    expect(find.text('URLTEST'), findsOneWidget);
    // Every member, in profile order: the choice is not moved up.
    final emerald = tester.getTopLeft(find.text('Emerald', findRichText: true));
    // The header shows the choice too; the member row comes last.
    final legacy = tester.getTopLeft(
      find.text('Legacy', findRichText: true).last,
    );
    expect(emerald.dy, lessThan(legacy.dy));
    expect(find.text('DIRECT', findRichText: true), findsOneWidget);
    // The choice carries the check.
    expect(find.byIcon(SurgeIcons.confirm), findsOneWidget);
  });

  testWidgets('the header opens every group full screen and closes again', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Profile groups'));
    await tester.pumpAndSettle();
    expect(find.text('2 groups · tap one to show it here'), findsOneWidget);
    expect(find.text('Manual', findRichText: true), findsOneWidget);

    await tester.tap(find.byIcon(SurgeIcons.expand).last);
    await tester.pumpAndSettle();
    expect(find.text('2 groups · tap one to show it here'), findsNothing);
  });

  testWidgets('the desktop panel drops its groups below the header', (
    tester,
  ) async {
    await tester.pumpWidget(host(expand: true));
    await tester.pump();
    final header = tester.getRect(find.bySemanticsLabel('Profile groups'));

    await tester.tap(find.bySemanticsLabel('Profile groups'));
    await tester.pumpAndSettle();
    // Not the full-screen sheet: no title, the list hangs under the header.
    expect(find.text('2 groups · tap one to show it here'), findsNothing);
    final manual = tester.getRect(find.text('Manual', findRichText: true));
    expect(manual.top, greaterThan(header.bottom));
    expect(manual.left, greaterThan(header.left));
    expect(manual.right, lessThan(header.right));

    // A tap beside the list closes it.
    await tester.tapAt(Offset(header.center.dx, 590));
    await tester.pumpAndSettle();
    expect(find.text('Manual', findRichText: true), findsNothing);
  });

  testWidgets('the brand bar leaves the brand to the desktop side menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      catalogApp(
        brightness: Brightness.dark,
        textScale: 1,
        overrides: [profilesProvider.overrideWithBuild((_, _) => const [])],
        child: const HomeBrandBar(showBrand: false),
      ),
    );
    expect(find.byType(Image), findsNothing);
  });
}
