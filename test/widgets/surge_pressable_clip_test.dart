import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool clipChild}) {
    return tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        child: SurgePressable(
          onTap: () {},
          borderRadius: BorderRadius.circular(10),
          clipChild: clipChild,
          child: const Text('Edge'),
        ),
      ),
    );
  }

  bool childClipped(WidgetTester tester) => find
      .ancestor(of: find.text('Edge'), matching: find.byType(ClipRRect))
      .evaluate()
      .isNotEmpty;

  testWidgets('clips the child to its radius by default', (tester) async {
    await pump(tester, clipChild: true);
    expect(childClipped(tester), isTrue);
  });

  testWidgets('clipChild: false leaves edge text whole', (tester) async {
    await pump(tester, clipChild: false);
    expect(childClipped(tester), isFalse);
    // The press overlay is still clipped to the radius.
    expect(find.byType(ClipRRect), findsOneWidget);
  });
}
