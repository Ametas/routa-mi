import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/profiles/profiles.dart';
import 'package:fl_clash/widgets/popup.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/component_catalog.dart';

void main() {
  testWidgets('profile actions open the shared popup menu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(384, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        child: ProfileItem(
          profile: const Profile(
            id: 1,
            label: 'Home',
            url: 'https://example.com/sub',
            autoUpdateDuration: Duration(hours: 12),
          ),
          groupValue: 1,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.byIcon(SurgeIcons.more).first);
    await tester.pumpAndSettle();

    final menu = tester.widget<CommonPopupMenu>(find.byType(CommonPopupMenu));
    expect(menu.items.map((item) => item.label), [
      'Edit',
      'Preview',
      'Sync',
      'Override',
      'Copy link',
      'Export file',
      'Delete',
    ]);
    expect(menu.items.where((item) => item.danger).map((item) => item.label), [
      'Delete',
    ]);
    expect(menu.items.every((item) => item.icon != null), isTrue);
  });
}
