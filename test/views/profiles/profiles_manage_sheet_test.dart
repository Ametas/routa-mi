import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/profiles/profiles.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/component_catalog.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<Profile> profiles) async {
    await tester.binding.setSurfaceSize(const Size(384, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        child: SizedBox(
          height: 850,
          child: ProfilesManageSheet(profiles: profiles),
        ),
      ),
    );
  }

  testWidgets('manage sheet is built from Surge sections and rows', (
    tester,
  ) async {
    await pump(tester, const [
      Profile(id: 1, label: 'Home', autoUpdateDuration: Duration.zero),
      Profile(id: 2, label: 'Work', autoUpdateDuration: Duration.zero),
    ]);
    // Adding moved to the "New profile" sheet; this one only sorts.
    expect(find.byType(SurgeSection), findsOneWidget);
    expect(find.byType(SurgeListTile), findsNWidgets(2));
    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
  });

  testWidgets('empty profile list shows a disabled placeholder row', (
    tester,
  ) async {
    await pump(tester, const []);
    final placeholder = tester.widget<SurgeListTile>(
      find.byType(SurgeListTile).last,
    );
    expect(placeholder.enabled, isFalse);
    expect(find.byType(SurgeIconTile), findsOneWidget);
  });
}
