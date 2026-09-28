import 'package:fl_clash/common/icons.dart';
import 'package:fl_clash/theme/ui_scale.dart';
import 'package:fl_clash/widgets/surge/surge_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UiScale', () {
    test('is 1.0 on the 384dp reference and bounded elsewhere', () {
      expect(UiScale.viewport(384), 1);
      expect(UiScale.viewport(360), closeTo(0.9375, 1e-9));
      expect(UiScale.viewport(200), UiScale.minViewport);
      expect(UiScale.viewport(800), UiScale.maxViewport);
    });

    test('moderated text keeps half of the growth, within bounds', () {
      expect(UiScale.moderatedText(1), 1);
      expect(UiScale.moderatedText(1.2), closeTo(1.1, 1e-9));
      expect(UiScale.moderatedText(0.5), 0.92);
      expect(UiScale.moderatedText(3), 1.22);
    });

    testWidgets('reads the shortest side, so rotation does not change it', (
      tester,
    ) async {
      double? portrait;
      double? landscape;
      for (final size in const [Size(384, 800), Size(800, 384)]) {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size),
            child: Builder(
              builder: (context) {
                final value = UiScale.viewportOf(context);
                if (size.width < size.height) {
                  portrait = value;
                } else {
                  landscape = value;
                }
                return const SizedBox();
              },
            ),
          ),
        );
      }
      expect(portrait, 1);
      expect(landscape, portrait);
    });
  });

  test('spacing and icon scales snap to the nearest step, ties up', () {
    expect(SurgeSpace.snap(0), 0);
    expect(SurgeSpace.snap(3), SurgeSpace.xs);
    expect(SurgeSpace.snap(6), SurgeSpace.s);
    expect(SurgeSpace.snap(10), SurgeSpace.m);
    expect(SurgeSpace.snap(11), SurgeSpace.m);
    expect(SurgeSpace.snap(13), SurgeSpace.m);
    expect(SurgeSpace.snap(14), SurgeSpace.l);
    expect(SurgeSpace.snap(28), SurgeSpace.xxxl);
    expect(SurgeIconSize.snap(15), SurgeIconSize.inline);
    expect(SurgeIconSize.snap(15.5), SurgeIconSize.inline);
    expect(SurgeIconSize.snap(17), SurgeIconSize.compact);
    expect(SurgeIconSize.snap(22), SurgeIconSize.navigation);
    expect(SurgeSpace.values, orderedEquals([...SurgeSpace.values]..sort()));
    expect(
      SurgeIconSize.values,
      orderedEquals([...SurgeIconSize.values]..sort()),
    );
  });
}
