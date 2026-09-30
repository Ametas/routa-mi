import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    catalogApp(brightness: Brightness.light, textScale: 1, child: child),
  );
}

SurgeTheme _surge(WidgetTester tester, Finder finder) =>
    SurgeTheme.of(tester.element(finder));

void main() {
  group('SurgeActionCard', () {
    Color background(WidgetTester tester) =>
        tester.widget<SurgeCard>(find.byType(SurgeCard)).backgroundColor!;

    testWidgets('variants map to Surge surfaces', (tester) async {
      await _pump(tester, const SurgeActionCard(child: Text('Plain')));
      final surge = _surge(tester, find.text('Plain'));
      expect(background(tester), surge.card);

      await _pump(
        tester,
        const SurgeActionCard(
          variant: SurgeActionCardVariant.tonal,
          child: Text('Tonal'),
        ),
      );
      expect(
        background(tester),
        surge.primary.withValues(alpha: SurgeAlpha.a08),
      );
    });

    testWidgets('selected and destructive override the variant', (
      tester,
    ) async {
      await _pump(
        tester,
        const SurgeActionCard(
          variant: SurgeActionCardVariant.filled,
          selected: true,
          child: Text('Selected'),
        ),
      );
      final surge = _surge(tester, find.text('Selected'));
      expect(background(tester), surge.selectedFill);

      await _pump(
        tester,
        const SurgeActionCard(destructive: true, child: Text('Delete')),
      );
      expect(background(tester), surge.red.withValues(alpha: SurgeAlpha.a12));
    });

    testWidgets('forwards taps', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        SurgeActionCard(onTap: () => taps++, child: const Text('Tap me')),
      );
      await tester.tap(find.text('Tap me'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('SurgeSection', () {
    testWidgets('renders title, rows and footer in one card', (tester) async {
      await _pump(
        tester,
        const SurgeSection(
          title: 'Network',
          footer: 'Applies on reconnect.',
          showDividers: true,
          children: [
            SurgeListTile(title: 'One'),
            SurgeListTile(title: 'Two'),
            SurgeListTile(title: 'Three'),
          ],
        ),
      );
      expect(find.text('Network'), findsOneWidget);
      expect(find.text('Applies on reconnect.'), findsOneWidget);
      expect(find.byType(SurgeCard), findsOneWidget);
      final title = tester.getRect(find.text('Network'));
      final card = tester.getRect(find.byType(SurgeCard));
      final footer = tester.getRect(find.text('Applies on reconnect.'));
      expect(title.bottom, lessThanOrEqualTo(card.top));
      expect(footer.top, greaterThanOrEqualTo(card.bottom));
    });

    testWidgets('dividers separate rows only when asked', (tester) async {
      int separators() => tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(SurgeCard),
              matching: find.byType(DecoratedBox),
            ),
          )
          .where((box) {
            final decoration = box.decoration;
            return decoration is BoxDecoration &&
                decoration.border is Border &&
                (decoration.border! as Border).top != BorderSide.none &&
                (decoration.border! as Border).bottom == BorderSide.none;
          })
          .length;
      const rows = [SurgeListTile(title: 'A'), SurgeListTile(title: 'B')];

      await _pump(
        tester,
        const SurgeSection(showDividers: true, children: rows),
      );
      expect(separators(), 1);

      await _pump(tester, const SurgeSection(children: rows));
      expect(separators(), 0);
    });
  });

  group('SurgeSegmentedControl', () {
    testWidgets('selected label is primary text and semibold', (tester) async {
      await _pump(
        tester,
        SurgeSegmentedControl<int>(
          value: 1,
          items: const [
            SurgeSegmentedItem(value: 0, label: 'Rule', icon: SurgeIcons.rule),
            SurgeSegmentedItem(value: 1, label: 'Global'),
          ],
          onChanged: (_) {},
        ),
      );
      final surge = SurgeTheme.of(tester.element(find.text('Rule')));
      TextStyle styleOf(String label) => tester
          .widget<AnimatedDefaultTextStyle>(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(AnimatedDefaultTextStyle),
                )
                .first,
          )
          .style;
      expect(styleOf('Global').color, surge.textPrimary);
      expect(styleOf('Global').fontWeight, FontWeight.w600);
      expect(styleOf('Rule').color, surge.textSecondary);
      final icon = tester.widget<Icon>(find.byIcon(SurgeIcons.rule));
      expect(icon.color, surge.textSecondary);
      expect(
        tester.getSemantics(find.text('Global')),
        matchesSemantics(
          label: 'Global',
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          isButton: true,
          hasTapAction: true,
          isEnabled: true,
          hasEnabledState: true,
          hasSelectedState: true,
        ),
      );
    });

    testWidgets('reports the tapped segment', (tester) async {
      int? picked;
      await _pump(
        tester,
        SurgeSegmentedControl<int>(
          value: 0,
          items: const [
            SurgeSegmentedItem(value: 0, label: 'Rule'),
            SurgeSegmentedItem(value: 1, label: 'Global'),
            SurgeSegmentedItem(value: 2, label: 'Direct'),
          ],
          onChanged: (value) => picked = value,
        ),
      );
      await tester.tap(find.text('Direct'));
      await tester.pumpAndSettle();
      expect(picked, 2);
    });

    testWidgets('segments share the width equally', (tester) async {
      await _pump(
        tester,
        SurgeSegmentedControl<int>(
          value: 0,
          items: const [
            SurgeSegmentedItem(value: 0, label: 'A'),
            SurgeSegmentedItem(value: 1, label: 'A much longer label'),
          ],
          onChanged: (_) {},
        ),
      );
      final first = tester.getCenter(find.text('A')).dx;
      final control = tester.getRect(find.byType(SurgeSegmentedControl<int>));
      expect(first, lessThan(control.center.dx));
      expect(
        first - control.left,
        moreOrLessEquals(control.width / 4, epsilon: 4),
      );
    });
  });
}
