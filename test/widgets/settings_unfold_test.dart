import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/widgets/settings_unfold.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
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
      home: Scaffold(body: child),
    ),
  );
}

class _Host extends StatefulWidget {
  const _Host({required this.rowTop});

  final double rowTop;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool lan = false;
  String level = 'info';
  String port = '7890';
  int opened = 0;

  List<UnfoldOption> options(BuildContext context, WidgetRef ref) => [
    UnfoldField(
      'Port',
      value: port,
      validator: (value) =>
          int.tryParse(value) == null ? 'Port must be a number' : null,
      onSubmitted: (value) => setState(() => port = value),
    ),
    UnfoldSwitch('LAN', value: lan, onChanged: (v) => setState(() => lan = v)),
    UnfoldChoice<String>(
      'Level',
      values: const ['debug', 'info', 'warning', 'error'],
      value: level,
      labelOf: (v) => v,
      onChanged: (v) => setState(() => level = v),
    ),
    UnfoldChoice<String>(
      'Mode',
      values: const ['rule', 'global'],
      value: 'rule',
      labelOf: (v) => v,
      onChanged: (_) {},
    ),
    UnfoldLink('All', onTap: () => setState(() => opened++)),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: widget.rowTop,
          left: 16,
          right: 16,
          height: 64,
          child: Builder(
            builder: (rowContext) => Consumer(
              builder: (_, ref, _) => GestureDetector(
                onTap: () => showSettingsUnfold(
                  rowContext,
                  count: options(rowContext, ref).length,
                  options: (context, ref) => options(context, ref),
                  anchorBuilder: (_, _) => const ColoredBox(
                    color: Colors.black,
                    child: Center(child: Text('Section')),
                  ),
                ),
                child: const Center(child: Text('Row')),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _open(WidgetTester tester, double rowTop) async {
  await tester.binding.setSurfaceSize(const Size(384, 853));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(_Host(rowTop: rowTop)));
  await tester.tap(find.text('Row'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('options keep their order around the row, which stays put', (
    tester,
  ) async {
    await _open(tester, 400);
    final row = tester.getRect(find.text('Section'));
    expect(tester.getCenter(find.text('Section')).dy, closeTo(432, 1));
    final labels = ['Port', 'LAN', 'Level', 'Mode', 'All'];
    final tops = [for (final l in labels) tester.getRect(find.text(l)).top];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: labels[i]);
    }
    expect(tops.where((top) => top < row.top), isNotEmpty);
    expect(tops.where((top) => top > row.bottom), isNotEmpty);
    // The nearest options sit one gap from the row (400–464).
    Rect card(String label) => tester.getRect(
      find
          .ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final above = labels.where((l) => tester.getRect(find.text(l)).top < 400);
    final below = labels.where((l) => tester.getRect(find.text(l)).top > 464);
    expect(card(above.last).bottom, closeTo(400 - SettingsUnfoldLayout.gap, 1));
    expect(card(below.first).top, closeTo(464 + SettingsUnfoldLayout.gap, 1));
  });

  testWidgets('a pick applies at once and folds its editor', (tester) async {
    await _open(tester, 400);
    await tester.tap(find.text('Level'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('error'));
    await tester.pump(SurgeMotion.reveal);
    await tester.pumpAndSettle();
    expect(find.text('warning'), findsNothing);
    expect(find.text('error'), findsOneWidget);
  });

  testWidgets('a field keeps a bad value out and says why', (tester) async {
    await _open(tester, 400);
    await tester.tap(find.text('Port'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Port must be a number'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '7891');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('7891'), findsOneWidget);
  });

  testWidgets('the dimmed screen and the row itself fold it back', (
    tester,
  ) async {
    await _open(tester, 400);
    await tester.tapAt(const Offset(200, 820));
    await tester.pumpAndSettle();
    expect(find.text('Port'), findsNothing);
    await tester.tap(find.text('Row'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    expect(find.text('Port'), findsNothing);
  });

  testWidgets('a row near the top unfolds downward only', (tester) async {
    await _open(tester, 60);
    final row = tester.getRect(find.text('Section'));
    for (final label in ['Port', 'LAN', 'Level', 'Mode', 'All']) {
      expect(tester.getRect(find.text(label)).top, greaterThan(row.bottom));
    }
  });
}
