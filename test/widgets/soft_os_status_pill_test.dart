import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget pill) {
    return tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [pill],
        ),
      ),
    );
  }

  testWidgets('shrink-wraps its label in a bounded parent', (tester) async {
    await pump(tester, const SoftOsStatusPill(child: Text('Ready')));
    final pill = tester.getSize(find.byType(SoftOsStatusPill));
    final label = tester.getSize(find.text('Ready'));
    expect(pill.width, lessThan(catalogWidth / 2));
    expect(pill.width, greaterThan(label.width));
  });

  testWidgets('honours an explicit width and centres the label', (
    tester,
  ) async {
    await pump(tester, const SoftOsStatusPill(width: 160, child: Text('Ok')));
    final pill = tester.getRect(find.byType(SoftOsStatusPill));
    final label = tester.getRect(find.text('Ok'));
    expect(pill.width, moreOrLessEquals(160, epsilon: 20));
    expect(label.center.dx, moreOrLessEquals(pill.center.dx, epsilon: 1));
  });

  testWidgets('honours minWidth', (tester) async {
    await pump(
      tester,
      const SoftOsStatusPill(minWidth: 120, child: Text('Ok')),
    );
    final pill = tester.getSize(find.byType(SoftOsStatusPill));
    expect(pill.width, greaterThanOrEqualTo(100));
    expect(pill.width, lessThan(catalogWidth / 2));
  });
}
