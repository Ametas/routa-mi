import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/connection/item.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/component_catalog.dart';

void main() {
  final tracker = TrackerInfo(
    id: '1',
    start: DateTime(2024),
    metadata: const Metadata(
      network: 'tcp',
      host: 'example.com',
      destinationIP: '1.2.3.4',
    ),
    chains: const ['Proxy', 'Relay'],
    rule: 'MATCH',
    rulePayload: '',
  );

  Future<void> pump(WidgetTester tester, {void Function(String)? onKeyword}) {
    return tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        child: TrackerInfoItem(
          trackerInfo: tracker,
          detailTitle: 'Connection',
          onClickKeyword: onKeyword,
        ),
      ),
    );
  }

  testWidgets('chains render as neutral tags that filter by keyword', (
    tester,
  ) async {
    final keywords = <String>[];
    await pump(tester, onKeyword: keywords.add);
    expect(find.byType(SurgeTag), findsNWidgets(2));
    final tag = tester.widget<SurgeTag>(find.widgetWithText(SurgeTag, 'Relay'));
    expect(tag.color, isNull, reason: 'neutral tone');
    await tester.tap(find.widgetWithText(SurgeTag, 'Relay'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(keywords, ['Relay']);
  });

  testWidgets('without a keyword handler the chain tags are static', (
    tester,
  ) async {
    await pump(tester);
    for (final tag in tester.widgetList<SurgeTag>(find.byType(SurgeTag))) {
      expect(tag.onTap, isNull);
    }
  });
}
