import 'package:fl_clash/enum/profile_core.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/mihomo_only.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

Future<void> pump(WidgetTester tester, ProfileCore core, VoidCallback onTap) {
  return tester.pumpWidget(
    catalogApp(
      brightness: Brightness.light,
      textScale: 1,
      overrides: [
        profilesProvider.overrideWithBuild(
          (_, _) => [
            Profile(id: 1, autoUpdateDuration: Duration.zero, core: core),
          ],
        ),
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
      ],
      child: MihomoOnly(
        child: ListTile(title: const Text('Find process'), onTap: onTap),
      ),
    ),
  );
}

void main() {
  testWidgets('mihomo profiles use the setting as usual', (tester) async {
    var taps = 0;
    await pump(tester, ProfileCore.mihomo, () => taps++);
    await tester.tap(find.text('Find process'));
    expect(taps, 1);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('Xray profiles dim it and explain instead of acting', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, ProfileCore.xray, () => taps++);
    expect(find.byType(Opacity), findsOneWidget);
    await tester.tap(find.text('Find process'));
    await tester.pump();
    expect(taps, 0);
    // The app shell shows the same text as a notice on tap.
    expect(find.bySemanticsLabel(RegExp('Find process')), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(MihomoOnly)).hint,
      'Not available for Xray profiles: this setting belongs to mihomo.',
    );
  });
}
