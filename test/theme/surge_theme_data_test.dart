import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/theme/static_theme.dart';
import 'package:fl_clash/theme/surge_theme_data.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/views/theme.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

({ThemeData theme, SurgeTheme surge, SurgeTypography typography}) _build(
  Brightness brightness,
) {
  final spec = StaticThemeSpec.resolve(StaticThemePreset.blueWhite, brightness);
  final textTheme = buildSlclashTextTheme();
  final surge = SurgeTheme.fromColors(
    spec.colors,
    stateColors: spec.stateColors,
  );
  final typography = SurgeTypography.fromTextTheme(textTheme);
  return (
    theme: buildSurgeThemeData(
      colorScheme: spec.colorScheme,
      textTheme: textTheme,
      surge: surge,
      typography: typography,
    ),
    surge: surge,
    typography: typography,
  );
}

void main() {
  for (final brightness in Brightness.values) {
    group('buildSurgeThemeData ($brightness)', () {
      final (:theme, :surge, :typography) = _build(brightness);

      test('carries the Surge extensions and surfaces', () {
        expect(theme.extension<SurgeTheme>(), same(surge));
        expect(theme.extension<SurgeTypography>(), same(typography));
        expect(theme.colorScheme.brightness, brightness);
        expect(theme.scaffoldBackgroundColor, surge.background);
        expect(theme.appBarTheme.backgroundColor, surge.background);
        expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
      });

      test('component themes come from Surge tokens', () {
        expect(theme.dividerTheme.color, surge.separator);
        expect(theme.dialogTheme.backgroundColor, surge.card);
        expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
        expect(
          theme.dialogTheme.titleTextStyle,
          typography.dialogTitle.copyWith(color: surge.textPrimary),
        );
        expect(theme.bottomSheetTheme.surfaceTintColor, Colors.transparent);
        expect(theme.progressIndicatorTheme.color, surge.primary);
        expect(theme.progressIndicatorTheme.linearTrackColor, surge.fill);
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
        expect(theme.textSelectionTheme.cursorColor, surge.primary);
        expect(
          theme.switchTheme.trackColor!.resolve({WidgetState.selected}),
          surge.semantic.state.toggleActive,
        );
      });
    });
  }

  testWidgets('bare widgets pick up the Surge theme', (tester) async {
    final (:theme, :surge, :typography) = _build(Brightness.light);
    Widget app(Widget home) => ProviderScope(
      overrides: [
        viewSizeProvider.overrideWithBuild((_, _) => const Size(384, 853)),
      ],
      child: MaterialApp(theme: theme, home: home),
    );

    await tester.pumpWidget(app(const Scaffold(body: Divider(height: 1))));
    final divider = tester.widget<Container>(
      find.descendant(
        of: find.byType(Divider),
        matching: find.byType(Container),
      ),
    );
    final border = (divider.decoration! as BoxDecoration).border! as Border;
    expect(border.bottom.color, surge.separator);

    await tester.pumpWidget(app(const CommonDialog(title: 'Title')));
    final dialog = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(dialog.color, surge.card);
    final title = tester.renderObject<RenderParagraph>(find.text('Title'));
    expect(title.text.style?.color, surge.textPrimary);
    expect(title.text.style?.fontSize, typography.dialogTitle.fontSize);
  });
}
