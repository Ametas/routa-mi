import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widgets/home_panels.dart';
import 'package:fl_clash/widgets/proxy_name_icon.dart';
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

void main() {
  testWidgets('the group panel lists five nodes and links to all of them', (
    tester,
  ) async {
    await tester.pumpWidget(
      catalogApp(
        brightness: Brightness.dark,
        textScale: 1,
        overrides: [
          profilesProvider.overrideWithBuild((_, _) => const []),
          currentGroupsStateProvider.overrideWithValue(
            const GroupsState(value: [_group]),
          ),
          selectedProxyNameProvider(
            _group.name,
          ).overrideWithValue('🇫🇮 Legacy'),
        ],
        child: const SingleChildScrollView(child: HomeGroupPanel()),
      ),
    );
    await tester.pump();

    // The title loses its symbol to the icon rule; the type sits on the right.
    expect(find.text('Auto', findRichText: true), findsOneWidget);
    expect(find.text('URLTEST'), findsOneWidget);
    expect(find.byType(ProxyNameIconTile), findsNWidgets(5));
    expect(find.text('All 6 nodes'), findsOneWidget);
    // The selected node comes first.
    final first = tester.getTopLeft(find.text('Legacy', findRichText: true)).dy;
    final second = tester
        .getTopLeft(find.text('Emerald', findRichText: true))
        .dy;
    expect(first, lessThan(second));
    expect(find.text('DIRECT', findRichText: true), findsNothing);
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
