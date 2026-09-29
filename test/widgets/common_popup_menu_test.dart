import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/widgets/popup.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<PopupMenuItemData> items) {
    return tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        child: Align(
          alignment: Alignment.centerLeft,
          child: CommonPopupMenu(minWidth: 188, items: items),
        ),
      ),
    );
  }

  testWidgets('items show their icon on a round tile, without dividers', (
    tester,
  ) async {
    await pump(tester, const [
      PopupMenuItemData(icon: SurgeIcons.edit, label: 'Edit', onPressed: _noop),
      PopupMenuItemData(
        icon: SurgeIcons.delete,
        label: 'Delete',
        danger: true,
        onPressed: _noop,
      ),
    ]);
    final tiles = tester
        .widgetList<SurgeIconTile>(find.byType(SurgeIconTile))
        .toList();
    expect(tiles, hasLength(2));
    expect(tiles.every((t) => t.shape == SurgeIconTileShape.circle), isTrue);
    expect(find.byType(Divider), findsNothing);

    final surge = SurgeTheme.of(tester.element(find.text('Delete')));
    expect(tiles.last.color, surge.red);
    expect(tiles.last.backgroundAlpha, SurgeAlpha.a08);
    expect(tiles.first.backgroundAlpha, SurgeAlpha.a04);
  });

  testWidgets('rows are compact and disabled items are dimmed', (tester) async {
    await pump(tester, const [
      PopupMenuItemData(icon: SurgeIcons.edit, label: 'Edit', onPressed: _noop),
      PopupMenuItemData(icon: SurgeIcons.share, label: 'Disabled'),
    ]);
    final row = tester.getSize(
      find.ancestor(of: find.text('Edit'), matching: find.byType(TextButton)),
    );
    expect(row.height, moreOrLessEquals(46, epsilon: 0.5));
    final disabled = tester.widget<Text>(find.text('Disabled'));
    expect(disabled.style?.color?.a, lessThan(0.3));
  });

  testWidgets('tapping an item closes the menu route and runs it', (
    tester,
  ) async {
    var runs = 0;
    await tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              PageRouteBuilder<void>(
                opaque: false,
                pageBuilder: (_, _, _) => Center(
                  child: CommonPopupMenu(
                    items: [
                      PopupMenuItemData(
                        icon: SurgeIcons.edit,
                        label: 'Run',
                        onPressed: () => runs++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    expect(runs, 1);
    expect(find.text('Run'), findsNothing);
  });
}

void _noop() {}
