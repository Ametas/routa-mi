import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/theme/static_theme.dart';
import 'package:fl_clash/theme/surge_theme_data.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/views/theme.dart';
import 'package:fl_clash/views/views.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

// Screenshot harness for design work, not a regular test: renders the main
// screens with real Roboto/Material Icons fonts on a 384dp screen and
// writes PNGs. Skipped unless SHOT_DIR is set:
//
//   SHOT_DIR=/tmp/shots flutter test test/tools/screenshots_test.dart
// Light theme by default; SHOT_BRIGHTNESS=dark renders the dark one.
//
// Screens that need a running core may log errors but still render.
void main() {
  final out = Platform.environment['SHOT_DIR'] ?? '';
  final skip = out.isEmpty ? 'set SHOT_DIR to render screenshots' : null;
  final brightness = Platform.environment['SHOT_BRIGHTNESS'] == 'dark'
      ? Brightness.dark
      : Brightness.light;
  final fonts =
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  setUpAll(() async {
    if (skip != null) return;
    await _loadFont('Roboto', [
      '$fonts/Roboto-Regular.ttf',
      '$fonts/Roboto-Medium.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
    Directory(out).createSync(recursive: true);
  });

  final views = <String, Widget Function()>{
    'theme': () => const ThemeView(),
    'tools': () => const ToolsView(),
    'about': () => const AboutView(),
    'application_setting': () => const ApplicationSettingView(),
    'developer': () => const DeveloperView(),
    'resources': () => const ResourcesView(),
    'backup': () => const BackupAndRestore(),
    'access': () => const AccessView(),
    'config': () => const ConfigView(),
    'logs': () => const LogsView(),
    'dashboard': () => const DashboardView(),
    'profiles': () => const ProfilesView(),
    'proxies': () => const ProxiesView(),
  };

  for (final MapEntry(key: name, value: build) in views.entries) {
    testWidgets('shot $name', skip: skip != null, (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 853));
      tester.view.devicePixelRatio = 2.5;
      final spec = StaticThemeSpec.resolve(
        StaticThemePreset.blueWhite,
        brightness,
      );
      final textTheme = buildSlclashTextTheme();
      final key = GlobalKey();
      final container = ProviderContainer(
        overrides: [
          viewSizeProvider.overrideWithBuild((_, _) => const Size(384, 853)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              theme: buildSurgeThemeData(
                colorScheme: spec.colorScheme,
                textTheme: textTheme,
                surge: SurgeTheme.fromColors(
                  spec.colors,
                  stateColors: spec.stateColors,
                ),
                typography: SurgeTypography.fromTextTheme(textTheme),
              ),
              home: build(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });
  }
}
