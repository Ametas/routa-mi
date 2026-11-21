import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/views/profiles/add_profile_sheet.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app() {
  final textTheme = buildSlclashTextTheme();
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      theme: ThemeData(
        textTheme: textTheme,
        extensions: <ThemeExtension<dynamic>>[
          SurgeTheme.dark(),
          SurgeTypography.fromTextTheme(textTheme),
        ],
      ),
      home: const Scaffold(body: AddProfileSheet()),
    ),
  );
}

OutlinePillButton _addButton(WidgetTester tester) =>
    tester.widget(find.byKey(const ValueKey('add-profile-submit')));

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('a subscription link unlocks the details and Add', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    expect(find.text(l10n.linkHint), findsOneWidget);
    expect(_addButton(tester).onPressed, isNull);
    expect(find.byKey(const ValueKey('add-profile-name')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('add-profile-url')),
      'https://sub.routa.example/s/7f3a9c',
    );
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.linkSubscription('sub.routa.example')),
      findsOneWidget,
    );
    expect(_addButton(tester).onPressed, isNotNull);
    expect(find.byKey(const ValueKey('add-profile-name')), findsOneWidget);
    expect(find.text(l10n.updateEvery(l10n.hoursShort(24))), findsOneWidget);
  });

  testWidgets('a node link is refused before anything is sent', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.enterText(
      find.byKey(const ValueKey('add-profile-url')),
      'vless://uuid@host:443',
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.linkNode), findsOneWidget);
    expect(_addButton(tester).onPressed, isNull);
  });

  testWidgets('a clash:// link fills the name it carries', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.enterText(
      find.byKey(const ValueKey('add-profile-url')),
      'clash://install-config?url=https%3A%2F%2Fvpn.example.net%2Fhome&name=Family',
    );
    await tester.pumpAndSettle();
    final name = tester.widget<TextField>(
      find.byKey(const ValueKey('add-profile-name')),
    );
    expect(name.controller!.text, 'Family');
  });

  test('intervals read as hours, then days', () {
    expect(addProfileIntervalLabel(l10n, const Duration(hours: 6)), '6 h');
    expect(addProfileIntervalLabel(l10n, const Duration(days: 1)), '24 h');
    expect(addProfileIntervalLabel(l10n, const Duration(days: 3)), '3 days');
  });
}
