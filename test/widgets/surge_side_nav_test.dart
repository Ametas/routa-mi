import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/side_nav.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = [
  SurgeSideNavItem(
    icon: Icons.home,
    iconOutlined: Icons.home_outlined,
    label: 'Home',
  ),
  SurgeSideNavItem(
    icon: Icons.public,
    iconOutlined: Icons.public_outlined,
    label: 'Proxies',
  ),
  SurgeSideNavItem(
    icon: Icons.list,
    iconOutlined: Icons.list,
    label: 'Requests',
    group: 'Activity',
  ),
];

Widget _host(Widget child) {
  final textTheme = buildSlclashTextTheme();
  return MaterialApp(
    theme: ThemeData(
      textTheme: textTheme,
      extensions: [SurgeTheme.dark(), SurgeTypography.fromTextTheme(textTheme)],
    ),
    home: Scaffold(body: Row(children: [child])),
  );
}

void main() {
  test('window width picks island, rail or side menu', () {
    expect(utils.getViewMode(400), ViewMode.mobile);
    expect(utils.getViewMode(600), ViewMode.mobile);
    expect(utils.getViewMode(601), ViewMode.laptop);
    expect(utils.getViewMode(1023), ViewMode.laptop);
    expect(utils.getViewMode(1024), ViewMode.desktop);
  });

  testWidgets('the rail is 72 wide and reports the tapped item', (
    tester,
  ) async {
    int? tapped;
    await tester.pumpWidget(
      _host(
        SurgeNavRail(
          items: _items,
          currentIndex: 0,
          onTap: (index) => tapped = index,
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(SurgeNavRail)).width,
      SurgeSideNavLayout.railWidth,
    );
    // The rail shows labels, not group headings.
    expect(find.text('Activity'), findsNothing);
    await tester.tap(find.text('Proxies'));
    expect(tapped, 1);
  });

  testWidgets('the side menu is 240 wide with group headings', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      _host(
        SurgeSideMenu(
          items: _items,
          currentIndex: 1,
          onTap: (index) => tapped = index,
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(SurgeSideMenu)).width,
      SurgeSideNavLayout.menuWidth,
    );
    expect(find.text('Activity'), findsOneWidget);
    await tester.tap(find.text('Requests'));
    expect(tapped, 2);
  });

  testWidgets('labels get the theme text style outside a Scaffold', (
    tester,
  ) async {
    // AppSidebarContainer puts the menu in a bare Row next to the page.
    final textTheme = buildSlclashTextTheme();
    for (final nav in [
      SurgeNavRail(items: _items, currentIndex: 0, onTap: (_) {}),
      SurgeSideMenu(items: _items, currentIndex: 0, onTap: (_) {}),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            textTheme: textTheme,
            extensions: [
              SurgeTheme.dark(),
              SurgeTypography.fromTextTheme(textTheme),
            ],
          ),
          home: Row(children: [nav]),
        ),
      );
      final label = tester.widget<RichText>(
        find.descendant(
          of: find.text('Proxies'),
          matching: find.byType(RichText),
        ),
      );
      expect(label.text.style?.decoration, isNot(TextDecoration.underline));
    }
  });

  test('the Activity heading opens the desktop-only pages', () {
    Widget page(BuildContext _) => const SizedBox();
    final items = AppSideNav.itemsFor([
      NavigationItem(
        icon: const Icon(SurgeIcons.dashboard),
        label: PageLabel.dashboard,
        builder: page,
      ),
      NavigationItem(
        icon: const Icon(SurgeIcons.requests),
        label: PageLabel.requests,
        builder: page,
        modes: const [NavigationItemMode.desktop, NavigationItemMode.more],
      ),
      NavigationItem(
        icon: const Icon(SurgeIcons.connections),
        label: PageLabel.connections,
        builder: page,
        modes: const [NavigationItemMode.desktop, NavigationItemMode.more],
      ),
    ], activityGroup: 'Activity');
    expect(items.map((item) => item.group), [null, 'Activity', null]);
  });
}
