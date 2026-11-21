import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/proxies/list_metrics.dart';
import 'package:fl_clash/views/proxies/top_bar.dart';
import 'package:fl_clash/widgets/proxy_group_bits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/widgets/surge/surge.dart';

const _groups = [
  Group(type: GroupType.Selector, name: 'A'),
  Group(type: GroupType.URLTest, name: 'B', fixed: 'x'),
  Group(type: GroupType.Selector, name: 'C', fixed: 'x'),
];

Widget surgeTestApp(Widget child) {
  final textTheme = buildSlclashTextTheme();
  final typography = SurgeTypography.fromTextTheme(textTheme);
  return MaterialApp(
    theme: ThemeData(
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[SurgeTheme.light(), typography],
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  test('the bolt tests open groups, or all of them when none is open', () {
    List<String> names(Set<String> unfold, [String query = '']) => [
      for (final group in proxiesGroupsToTest(
        groups: _groups,
        unfold: unfold,
        query: query,
      ))
        group.name,
    ];
    expect(names({'B'}), ['B']);
    expect(names({}), ['A', 'B', 'C']);
    expect(names({'A'}, 'de'), ['A', 'B', 'C']);
  });

  test('only automatic groups can be pinned by hand', () {
    expect(proxyGroupPinned(_groups[0]), isNull);
    expect(proxyGroupPinned(_groups[1]), 'x');
    expect(proxyGroupPinned(_groups[2]), isNull);
  });

  test('grid columns fill the width with cards of at least 220', () {
    expect(ProxyListMetrics.columnsFor(300), 1);
    expect(ProxyListMetrics.columnsFor(24 + 220 * 2 + 8), 2);
    expect(ProxyListMetrics.columnsFor(24 + 220 * 3 + 16), 3);
  });

  testWidgets('row extents grow with the text scale', (tester) async {
    late ProxyListMetrics small, large;
    Widget probe(double scale, void Function(ProxyListMetrics) out) =>
        surgeTestApp(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Builder(
              builder: (context) {
                out(ProxyListMetrics.of(context));
                return const SizedBox();
              },
            ),
          ),
        );
    await tester.pumpWidget(probe(1, (m) => small = m));
    await tester.pumpWidget(probe(1.5, (m) => large = m));
    expect(small.headerHeight, greaterThanOrEqualTo(24 + 34));
    expect(large.rowHeight, greaterThan(small.rowHeight));
    expect(large.tileHeight, greaterThan(small.tileHeight));
    expect(large.headerHeight, greaterThan(small.headerHeight));
  });
}
