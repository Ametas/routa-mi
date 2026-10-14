import 'package:fl_clash/enum/profile_core.dart';
import 'package:fl_clash/views/profiles/profile_core_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/component_catalog.dart';

void main() {
  testWidgets('the switch picks the core and the tag names it', (tester) async {
    var core = ProfileCore.mihomo;
    await tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        child: StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              ProfileCoreField(
                value: core,
                onChanged: (value) => setState(() => core = value),
              ),
              ProfileCoreTag(core: core),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Xray'), findsOneWidget); // switch segment only
    await tester.tap(find.text('Xray'));
    await tester.pumpAndSettle();
    expect(core, ProfileCore.xray);
    expect(find.text('Xray'), findsNWidgets(2)); // segment + tag
    expect(
      find.text(
        'The server picks the subscription format by the core. '
        'A JSON subscription always runs on Xray.',
      ),
      findsOneWidget,
    );
  });
}
