import 'package:fl_clash/widgets/input.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

void main() {
  testWidgets('toggle row presses through SurgePressable and flips value', (
    tester,
  ) async {
    bool? changed;
    await tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        child: SurgeToggleFieldRow(
          label: 'Allow LAN',
          subtitle: 'Accept connections from other devices',
          value: false,
          onChanged: (value) => changed = value,
        ),
      ),
    );
    expect(find.byType(InkWell), findsNothing);
    expect(
      find.ancestor(
        of: find.text('Allow LAN'),
        matching: find.byType(SurgePressable),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Allow LAN'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(changed, isTrue);
  });
}
