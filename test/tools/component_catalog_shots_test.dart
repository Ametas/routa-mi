import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

// Component showcase, not a regular test: renders every catalog entry with
// real fonts into one PNG per theme and font scale. Skipped unless SHOT_DIR
// is set:
//
//   SHOT_DIR=/tmp/catalog flutter test test/tools/component_catalog_shots_test.dart
//
// Text styles with no font family (Material button labels) render in the
// test font here; on Android they resolve to the system Roboto.
void main() {
  final out = Platform.environment['SHOT_DIR'] ?? '';
  final skip = out.isEmpty ? 'set SHOT_DIR to render the catalog' : null;
  final fonts =
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  setUpAll(() async {
    if (skip != null) return;
    await _loadFont('Roboto', [
      '$fonts/Roboto-Regular.ttf',
      '$fonts/Roboto-Medium.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
  });

  for (final brightness in Brightness.values) {
    for (final textScale in [1.0, 1.3, 2.0]) {
      final name = '${brightness.name}_${(textScale * 100).round()}';
      testWidgets('catalog $name', skip: skip != null, (tester) async {
        const height = 6000.0;
        await tester.binding.setSurfaceSize(const Size(catalogWidth, height));
        tester.view.devicePixelRatio = 2;
        final key = GlobalKey();
        await tester.pumpWidget(
          catalogApp(
            brightness: brightness,
            textScale: textScale,
            child: RepaintBoundary(
              key: key,
              child: Builder(
                builder: (context) {
                  final surge = SurgeTheme.of(context);
                  return ColoredBox(
                    color: surge.background,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final entry in componentCatalog) ...[
                          Padding(
                            padding: const EdgeInsets.only(
                              top: SurgeSpace.l,
                              bottom: SurgeSpace.xs,
                            ),
                            child: Text(
                              entry.name,
                              style: context.typography.supporting.copyWith(
                                color: surge.textSecondary,
                              ),
                            ),
                          ),
                          Builder(builder: entry.builder),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$out/catalog_$name.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      });
    }
  }
}
