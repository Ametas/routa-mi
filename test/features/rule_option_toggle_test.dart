import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/overwrite/rule.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

void main() {
  testWidgets('rule parameter toggles are Surge action cards', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        // The catalog host scrolls; the dialog needs a bounded height.
        child: const SizedBox(
          height: 800,
          child: AddOrEditRuleDialog(
            rule: Rule(
              ruleAction: RuleAction.IP_CIDR,
              content: '10.0.0.0/8',
              ruleTarget: 'DIRECT',
              src: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    SurgeActionCard toggle(String label) => tester.widget<SurgeActionCard>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(SurgeActionCard),
      ),
    );

    expect(toggle('Source IP').selected, isTrue);
    expect(toggle('No resolve IP').selected, isFalse);

    await tester.tap(find.text('No resolve IP'));
    await tester.pumpAndSettle();
    expect(toggle('No resolve IP').selected, isTrue);

    await tester.tap(find.text('Source IP'));
    await tester.pumpAndSettle();
    expect(toggle('Source IP').selected, isFalse);
  });
}
