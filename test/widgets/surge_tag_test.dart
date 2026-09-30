import 'package:fl_clash/theme/ui_scale.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

void main() {
  Future<SurgeTheme> pump(
    WidgetTester tester,
    Widget tag, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: textScale,
        child: Row(children: [tag]),
      ),
    );
    return SurgeTheme.of(tester.element(find.byType(SurgeTag)));
  }

  BoxDecoration decoration(WidgetTester tester) =>
      tester
              .widget<Container>(
                find.descendant(
                  of: find.byType(SurgeTag),
                  matching: find.byType(Container),
                ),
              )
              .decoration!
          as BoxDecoration;

  test('palettes', () {
    final accent = SurgeTagColors.accent(Colors.green);
    expect(accent.background, Colors.green.withValues(alpha: SurgeAlpha.a12));
    expect(accent.border, Colors.green.withValues(alpha: SurgeAlpha.a24));
    expect(accent.foreground, Colors.green.withValues(alpha: SurgeAlpha.a92));
  });

  testWidgets('neutral regular tag: status-pill height, stadium, grey', (
    tester,
  ) async {
    final surge = await pump(tester, const SurgeTag(label: 'url'));
    final neutral = SurgeTagColors.neutral(surge);
    final box = decoration(tester);
    expect(box.color, neutral.background);
    expect((box.border! as Border).top.color, neutral.border);
    expect(box.borderRadius, BorderRadius.circular(surge.radii.button));
    final text = tester.widget<Text>(find.text('url'));
    expect(text.style!.color, neutral.foreground);
    expect(text.textScaler, const TextScaler.linear(1));
    final size = tester.getSize(find.byType(SurgeTag));
    expect(size.width, lessThan(80), reason: 'hugs its label');
  });

  testWidgets('regular height does not grow with the text scale', (
    tester,
  ) async {
    await pump(tester, const SurgeTag(label: 'url'));
    final base = tester.getSize(find.byType(SurgeTag)).height;
    await pump(tester, const SurgeTag(label: 'url'), textScale: 2);
    final scaled = tester.getSize(find.byType(SurgeTag)).height;
    // Only the moderated Soft OS factor applies, not the raw 200 %.
    expect(scaled, lessThan(base * 1.5));
    final text = tester.widget<Text>(find.text('url'));
    expect(
      text.textScaler,
      TextScaler.linear(UiScale.moderatedText(2)),
      reason: 'the label grows with the capsule',
    );
  });

  testWidgets('accent compact tag tints with its colour and scales text', (
    tester,
  ) async {
    await pump(
      tester,
      const SurgeTag(
        label: '7',
        color: Colors.blue,
        size: SurgeTagSize.compact,
        minWidth: 30,
      ),
    );
    final box = decoration(tester);
    expect(box.color, Colors.blue.withValues(alpha: SurgeAlpha.a12));
    final text = tester.widget<Text>(find.text('7'));
    expect(text.style!.color, Colors.blue.withValues(alpha: SurgeAlpha.a92));
    expect(text.textScaler, isNull);
    expect(tester.getSize(find.byType(SurgeTag)).width, greaterThan(24));
  });

  testWidgets('max width ellipsizes long labels', (tester) async {
    await pump(
      tester,
      const SurgeTag(label: 'a very long label indeed', maxWidth: 64),
    );
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.getSize(find.byType(SurgeTag)).width, lessThanOrEqualTo(90));
  });

  testWidgets('onTap makes the tag pressable', (tester) async {
    var taps = 0;
    await pump(tester, SurgeTag(label: 'chain', onTap: () => taps++));
    expect(find.byType(SurgePressable), findsOneWidget);
    await tester.tap(find.byType(SurgeTag));
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 1);
  });

  testWidgets('without onTap the tag is static', (tester) async {
    await pump(tester, const SurgeTag(label: 'chain'));
    expect(find.byType(SurgePressable), findsNothing);
  });
}
