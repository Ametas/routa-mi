import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/views/proxies/setting.dart';
import 'package:fl_clash/widgets/setting.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/component_catalog.dart';

void main() {
  testWidgets('proxy settings are SurgeSections of SurgeSettingOptions', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: catalogApp(
          brightness: Brightness.light,
          textScale: 1,
          child: const SizedBox(height: 900, child: ProxiesSetting()),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SurgeSection), findsNWidgets(2));
    expect(
      find.byType(SurgeSettingOption),
      findsNWidgets(
        ProxiesSortType.values.length + ProxiesIconStyle.values.length,
      ),
    );
    final selected = tester
        .widgetList<SurgeSettingOption>(find.byType(SurgeSettingOption))
        .where((option) => option.selected);
    expect(selected, hasLength(2), reason: 'one choice per section');
    // The last option of each section has no divider below it.
    final options = tester
        .widgetList<SurgeSettingOption>(find.byType(SurgeSettingOption))
        .toList();
    expect(options[ProxiesSortType.values.length - 1].showDivider, isFalse);
    expect(options.last.showDivider, isFalse);

    final nameOption =
        options[ProxiesSortType.values.indexOf(ProxiesSortType.name)];
    await tester.tap(find.text(nameOption.title));
    await tester.pump();
    expect(
      container.read(proxiesStyleSettingProvider).sortType,
      ProxiesSortType.name,
    );
  });

  testWidgets('SurgeSettingOption reports its selected state', (tester) async {
    await tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        child: SurgeSettingOption(title: 'Daily', selected: true, onTap: () {}),
      ),
    );
    expect(
      tester.getSemantics(find.text('Daily')),
      matchesSemantics(
        label: 'Daily',
        isSelected: true,
        hasSelectedState: true,
        isButton: true,
        hasTapAction: true,
        isEnabled: true,
        hasEnabledState: true,
      ),
    );
  });
}
