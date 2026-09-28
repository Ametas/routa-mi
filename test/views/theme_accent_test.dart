import 'package:fl_clash/common/color.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/theme/app_color_source.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/views/theme_accent.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _pumpPicker(
  WidgetTester tester,
  ThemeProps initial,
) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(themeSettingProvider.notifier).value = initial;
  final textTheme = buildSlclashTextTheme();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(
          textTheme: textTheme,
          extensions: [
            SurgeTheme.light(),
            SurgeTypography.fromTextTheme(textTheme),
          ],
        ),
        home: const Scaffold(body: ThemeAccentPicker()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows one swatch per accent and marks the selected one', (
    tester,
  ) async {
    const props = ThemeProps(
      dynamicColor: false,
      primaryColor: defaultAccentColor,
      primaryColors: [0xFF795548, 0xFF03A9F4],
    );
    await _pumpPicker(tester, props);

    expect(
      find.bySemanticsLabel(RegExp(r'^[#0-9A-Fa-f]{6,9}$')),
      findsNWidgets(3),
    );
    expect(find.byIcon(SurgeIcons.confirm), findsOneWidget);
    expect(find.byIcon(SurgeIcons.add), findsOneWidget);
  });

  testWidgets('tapping a swatch switches to that accent', (tester) async {
    const props = ThemeProps(
      dynamicColor: false,
      primaryColor: defaultAccentColor,
      primaryColors: [0xFF795548],
    );
    final container = await _pumpPicker(tester, props);

    await tester.tap(find.bySemanticsLabel(const Color(0xFF795548).hex));
    await tester.pumpAndSettle();

    final theme = container.read(themeSettingProvider);
    expect(theme.primaryColor, 0xFF795548);
    expect(theme.colorSource, AppColorSource.accent);
  });
}
