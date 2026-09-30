import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/theme/static_theme.dart';
import 'package:fl_clash/theme/surge_theme_data.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/views/config/dns.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/views/profiles/media_check.dart';
import 'package:fl_clash/views/theme.dart';
import 'package:fl_clash/views/views.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
const _heroGroups = [
  Group(
    type: GroupType.Selector,
    name: 'Proxy',
    now: 'JP01',
    all: [
      Proxy(name: 'JP01', type: 'Vless'),
      Proxy(name: 'HK01', type: 'Vless'),
      Proxy(name: 'SG01', type: 'Trojan'),
    ],
  ),
];

const _mediaProfiles = [
  Profile(id: 1, label: 'Daily', autoUpdateDuration: Duration(hours: 24)),
  Profile(id: 2, label: 'AI', autoUpdateDuration: Duration(hours: 24)),
];

// Dialogs are opened over an empty screen, the way the app shows them.
final _dialogs = <String, Future<void> Function(BuildContext)>{
  'dialog_message': (context) => globalState.showMessage(
    context: context,
    title: 'Delete profile',
    message: const TextSpan(
      text: 'The profile "Home" and its overrides will be removed.',
    ),
  ),
  'dialog_input': (context) => globalState.showCommonDialog<String>(
    context: context,
    child: const InputDialog(
      title: 'Port',
      value: '7890',
      labelText: 'Mixed port',
    ),
  ),
  'dialog_options': (context) => globalState.showCommonDialog<String>(
    context: context,
    child: OptionsDialog<String>(
      title: 'Log level',
      options: const ['debug', 'info', 'warning', 'error'],
      value: 'info',
      textBuilder: (value) => value,
    ),
  ),
};

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
    'network': () => const Scaffold(body: NetworkListView()),
    'dns': () => const Scaffold(body: DnsListView()),
    'profiles_manage': () => const Scaffold(
      body: ProfilesManageSheet(
        profiles: [
          Profile(id: 1, label: 'Home', autoUpdateDuration: Duration.zero),
          Profile(id: 2, label: 'Work', autoUpdateDuration: Duration.zero),
        ],
      ),
    ),
    'profile_item_menu': () => Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(SurgeSpace.l),
            child: ProfileItem(
              profile: const Profile(
                id: 1,
                label: 'Home',
                url: 'https://example.com/sub',
                autoUpdateDuration: Duration(hours: 12),
              ),
              groupValue: 1,
              onChanged: (_) {},
            ),
          ),
        ],
      ),
    ),
    'profiles_manage_empty': () =>
        const Scaffold(body: ProfilesManageSheet(profiles: [])),
    'logs': () => const LogsView(),
    'dashboard': () => const DashboardView(),
    'profiles': () => const ProfilesView(),
    'profiles_active': () => const ProfilesView(),
    'proxies': () => const ProxiesView(),
    'hero_node_sheet': () => const DashboardView(),
    'media_check': () => ProfileMediaCheckView(
      profiles: _mediaProfiles,
      initialProfile: _mediaProfiles.first,
      configLoader: (profileId) async => {
        'proxies': [
          {'name': 'JP01', 'type': 'Vless'},
          {'name': 'HK01', 'type': 'Vless'},
        ],
      },
    ),
    for (final name in _dialogs.keys) name: () => const Scaffold(),
  };

  for (final MapEntry(key: name, value: build) in views.entries) {
    testWidgets('shot $name', skip: skip != null, (tester) async {
      SharedPreferences.setMockInitialValues({});
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
          if (name == 'hero_node_sheet') ...[
            groupsProvider.overrideWithBuild((_, _) => _heroGroups),
            currentGroupsStateProvider.overrideWithValue(
              const GroupsState(value: _heroGroups),
            ),
          ],
          if (name == 'profiles_active') ...[
            profilesProvider.overrideWithBuild(
              (_, _) => const [
                Profile(
                  id: 1,
                  label: 'Home',
                  url: 'https://example.com/home',
                  autoUpdateDuration: Duration(hours: 12),
                ),
                Profile(
                  id: 2,
                  label: 'Work',
                  url: 'https://example.com/work',
                  autoUpdateDuration: Duration(hours: 12),
                ),
              ],
            ),
            currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          ],
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
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
      // Screens whose interesting state needs a tap first.
      final openDialog = _dialogs[name];
      if (openDialog != null) {
        unawaited(openDialog(tester.element(find.byType(Scaffold).first)));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      if (name == 'hero_node_sheet') {
        final bar = tester.getRect(find.byType(SurgeDualSelectBar));
        await tester.tapAt(Offset(bar.left + bar.width * 0.75, bar.center.dy));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      if (name == 'profile_item_menu') {
        await tester.tap(find.byIcon(SurgeIcons.more).first);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
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
