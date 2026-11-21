import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/theme/app_color_source.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/views/theme_amoled.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _pump(WidgetTester tester, ThemeProps initial) async {
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
            SurgeTheme.dark(),
            SurgeTypography.fromTextTheme(textTheme),
          ],
        ),
        home: const Scaffold(body: ThemeAmoledItem()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  const routa = ThemeProps(
    dynamicColor: false,
    primaryColor: routaPresetColor,
    themeMode: ThemeMode.light,
  );

  testWidgets('turning AMOLED on moves light mode to dark and offers accents', (
    tester,
  ) async {
    final container = await _pump(tester, routa);
    expect(find.bySemanticsLabel('Cyan'), findsNothing);

    await tester.tap(find.text('AMOLED'));
    await tester.pumpAndSettle();

    var theme = container.read(themeSettingProvider);
    expect(theme.pureBlack, isTrue);
    expect(theme.themeMode, ThemeMode.dark);

    await tester.tap(find.bySemanticsLabel('Cyan'));
    await tester.pumpAndSettle();
    theme = container.read(themeSettingProvider);
    expect(theme.amoledAccent, AmoledAccent.cyan);
  });

  testWidgets('own accents and Material You get no AMOLED accents', (
    tester,
  ) async {
    await _pump(tester, const ThemeProps(dynamicColor: true, pureBlack: true));
    expect(find.bySemanticsLabel('Violet'), findsNothing);
  });
}
