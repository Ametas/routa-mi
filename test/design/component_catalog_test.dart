import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

// Contract for the canonical components (design-system audit, stage 4):
// every catalog entry lays out without overflow or errors on a narrow
// screen, in both themes, at 100/130/200 % font scale.
const _textScales = [1.0, 1.3, 2.0];

void main() {
  for (final entry in componentCatalog) {
    for (final brightness in Brightness.values) {
      for (final textScale in _textScales) {
        testWidgets(
          '${entry.name} fits ($brightness, ${(textScale * 100).round()} %)',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(catalogWidth, 800));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              catalogApp(
                brightness: brightness,
                textScale: textScale,
                child: Builder(builder: entry.builder),
              ),
            );
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
