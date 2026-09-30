import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

void main() {
  testWidgets('search keywords are removable tags', (tester) async {
    globalState.container = ProviderContainer();
    addTearDown(globalState.container.dispose);
    final key = GlobalKey<CommonScaffoldState>();
    final updates = <List<String>>[];
    await tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        child: SizedBox(
          height: 400,
          child: CommonScaffold(
            key: key,
            title: 'Connections',
            body: const SizedBox(),
            onKeywordsUpdate: updates.add,
          ),
        ),
      ),
    );
    key.currentState!
      ..addKeyword('Proxy')
      ..addKeyword('Relay');
    await tester.pump();
    expect(find.byType(SurgeTag), findsNWidgets(2));
    expect(find.byIcon(SurgeIcons.close), findsNWidgets(2));

    await tester.tap(find.widgetWithText(SurgeTag, 'Relay'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SurgeTag), findsOneWidget);
    expect(updates.last, ['Proxy']);
  });
}
