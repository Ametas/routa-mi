import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/widgets/proxy_name_icon.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  final textTheme = buildSlclashTextTheme();
  return MaterialApp(
    theme: ThemeData(
      textTheme: textTheme,
      extensions: [SurgeTheme.dark(), SurgeTypography.fromTextTheme(textTheme)],
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('the tile shows the flag a node name starts with', (
    tester,
  ) async {
    final parts = splitProxyNameIcon('★ 🇩🇪 Emerald');
    await tester.pumpWidget(_host(ProxyNameIconTile(icon: parts.icon)));
    expect(
      tester.getSize(find.byType(ProxyNameIconTile)),
      const Size.square(ProxyNameIconTile.rowSize),
    );
    final text = tester.widget<RichText>(
      find.descendant(
        of: find.byType(ProxyNameIconTile),
        matching: find.byType(RichText),
      ),
    );
    expect(text.text.toPlainText(), '🇩🇪');
    expect(find.byIcon(SurgeIcons.target), findsNothing);
  });

  testWidgets('a name without a prefix gets the neutral icon', (tester) async {
    await tester.pumpWidget(
      _host(ProxyNameIconTile(icon: splitProxyNameIcon('DIRECT').icon)),
    );
    expect(find.byIcon(SurgeIcons.target), findsOneWidget);
  });
}
