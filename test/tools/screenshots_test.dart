import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/common/measure.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/common/local_proxy_auth.dart';
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
import 'package:fl_clash/views/proxies/setting.dart';
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
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/component_catalog.dart';

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

const _proxyGroups = [
  Group(
    type: GroupType.Selector,
    name: 'Proxy',
    now: 'JP01',
    all: [
      Proxy(name: 'JP01', type: 'Vless'),
      Proxy(name: 'HK01', type: 'Vless'),
      Proxy(name: 'SG01', type: 'Trojan'),
      Proxy(name: 'US01', type: 'Hysteria2'),
      Proxy(name: 'DE01', type: 'Shadowsocks'),
      Proxy(name: 'NL01', type: 'Vmess'),
    ],
  ),
  Group(
    type: GroupType.URLTest,
    name: 'Auto',
    now: 'HK01',
    all: [
      Proxy(name: 'HK01', type: 'Vless'),
      Proxy(name: 'SG01', type: 'Trojan'),
    ],
  ),
  Group(
    type: GroupType.Selector,
    name: 'Streaming',
    now: 'US01',
    all: [Proxy(name: 'US01', type: 'Hysteria2')],
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

// Scale styles carry no family; devices fill in Roboto, the test engine
// draws boxes, and AnimatedDefaultTextStyle does not inherit one.
SurgeTypography _withFamily(SurgeTypography t, String family) => t.copyWith(
  rootAppBarTitle: t.rootAppBarTitle.copyWith(fontFamily: family),
  dialogTitle: t.dialogTitle.copyWith(fontFamily: family),
  sectionTitle: t.sectionTitle.copyWith(fontFamily: family),
  mediaCheckTitle: t.mediaCheckTitle.copyWith(fontFamily: family),
  mediaControlMetricLabel: t.mediaControlMetricLabel.copyWith(
    fontFamily: family,
  ),
  mediaFilterTitle: t.mediaFilterTitle.copyWith(fontFamily: family),
  mediaObservationInterval: t.mediaObservationInterval.copyWith(
    fontFamily: family,
  ),
  mediaResultTitle: t.mediaResultTitle.copyWith(fontFamily: family),
  mediaRunButtonLabel: t.mediaRunButtonLabel.copyWith(fontFamily: family),
  selectedNavigationLabel: t.selectedNavigationLabel.copyWith(
    fontFamily: family,
  ),
  detailLabel: t.detailLabel.copyWith(fontFamily: family),
  compactRowTitle: t.compactRowTitle.copyWith(fontFamily: family),
  proxyGroupTitle: t.proxyGroupTitle.copyWith(fontFamily: family),
  proxySelectorLabel: t.proxySelectorLabel.copyWith(fontFamily: family),
  proxyCardSubtitle: t.proxyCardSubtitle.copyWith(fontFamily: family),
  featuredTitle: t.featuredTitle.copyWith(fontFamily: family),
  pillLabel: t.pillLabel.copyWith(fontFamily: family),
  itemLabel: t.itemLabel.copyWith(fontFamily: family),
  previewLabel: t.previewLabel.copyWith(fontFamily: family),
  sheetRowTitle: t.sheetRowTitle.copyWith(fontFamily: family),
  sheetLabel: t.sheetLabel.copyWith(fontFamily: family),
  sheetTitle: t.sheetTitle.copyWith(fontFamily: family),
  countLabel: t.countLabel.copyWith(fontFamily: family),
  badgeLabel: t.badgeLabel.copyWith(fontFamily: family),
  selectedRowTitle: t.selectedRowTitle.copyWith(fontFamily: family),
  selectorLabel: t.selectorLabel.copyWith(fontFamily: family),
  metric: t.metric.copyWith(fontFamily: family),
  compactMetric: t.compactMetric.copyWith(fontFamily: family),
  toolTileSubtitle: t.toolTileSubtitle.copyWith(fontFamily: family),
  toolTileTitle: t.toolTileTitle.copyWith(fontFamily: family),
  compactDescription: t.compactDescription.copyWith(fontFamily: family),
  modeTabLabel: t.modeTabLabel.copyWith(fontFamily: family),
  selectedModeTabLabel: t.selectedModeTabLabel.copyWith(fontFamily: family),
  dashboardMetric: t.dashboardMetric.copyWith(fontFamily: family),
  dashboardIpValue: t.dashboardIpValue.copyWith(fontFamily: family),
  dashboardLatencyValue: t.dashboardLatencyValue.copyWith(fontFamily: family),
  dashboardDetectionValue: t.dashboardDetectionValue.copyWith(
    fontFamily: family,
  ),
  techLabel: t.techLabel.copyWith(fontFamily: family),
);

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
    final roboto = [
      '$fonts/Roboto-Regular.ttf',
      '$fonts/Roboto-Medium.ttf',
      '$fonts/Roboto-Bold.ttf',
    ];
    await _loadFont('Roboto', roboto);
    await _loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
    await _loadFont('JetBrainsMono', [
      'assets/fonts/JetBrainsMono-Regular.ttf',
    ]);
    await _loadFont('Twemoji', ['assets/fonts/Twemoji.Mozilla.ttf']);
    Directory(out).createSync(recursive: true);
    // Normally read from the platform at startup (About shows the version).
    globalState.packageInfo = PackageInfo(
      appName: 'RoutaMi',
      packageName: 'icu.routaterm.routami',
      version: '0.1.0',
      buildNumber: '1',
    );
    globalState
      ..mihomoVersion = 'v1.19.31'
      ..mihomoCommit = 'ab405bad5bee'
      ..mihomoReleaseDate = '2026-09-14'
      ..coreSHA256 = ''
      ..coreBuildTime = '';
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
    'config_vless': () => const ConfigView(),
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
    'proxies_setting': () => const Scaffold(body: ProxiesSetting()),
    'resources_auto_update': () => const ResourcesView(),
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
    // Every canonical component of the design system on one sheet.
    'components': () => Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(SurgeSpace.l),
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
                  style: const TextStyle(fontFamily: 'JetBrainsMono'),
                ),
              ),
              Builder(builder: entry.builder),
            ],
          ],
        ),
      ),
    ),
  };

  for (final MapEntry(key: name, value: build) in views.entries) {
    testWidgets('shot $name', skip: skip != null, (tester) async {
      SharedPreferences.setMockInitialValues({});
      final height = name == 'components' ? 3240.0 : 853.0;
      await tester.binding.setSurfaceSize(Size(384, height));
      tester.view.devicePixelRatio = 2.5;
      final spec = StaticThemeSpec.resolve(
        StaticThemePreset.blueWhite,
        brightness,
      );
      // Devices fill a missing family with Roboto; the test engine draws
      // boxes instead, so name it explicitly.
      final textTheme = buildSlclashTextTheme().apply(fontFamily: 'Roboto');
      final key = GlobalKey();
      final container = ProviderContainer(
        overrides: [
          viewSizeProvider.overrideWithBuild((_, _) => Size(384, height)),
          if (name == 'config_vless')
            networkSettingProvider.overrideWithBuild(
              (_, _) =>
                  const NetworkProps(localVless: LocalVlessProps(enable: true)),
            ),
          if (name == 'hero_node_sheet') ...[
            groupsProvider.overrideWithBuild((_, _) => _heroGroups),
            currentGroupsStateProvider.overrideWithValue(
              const GroupsState(value: _heroGroups),
            ),
          ],
          if (name == 'proxies') ...[
            groupsProvider.overrideWithBuild((_, _) => _proxyGroups),
            currentGroupsStateProvider.overrideWithValue(
              const GroupsState(value: _proxyGroups),
            ),
            unfoldSetProvider.overrideWithValue(const {'Proxy'}),
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
      // Like the app: credentials exist as soon as settings load.
      keepLocalProxyCredentials(container);
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
                typography: _withFamily(
                  SurgeTypography.fromTextTheme(textTheme),
                  'Roboto',
                ),
              ),
              // Dialogs and sheets sit above any Material, so give the
              // whole navigator the family too.
              builder: (context, child) {
                // ThemeManager sets this in the app (proxy list layout).
                globalState.measure = Measure.of(context, 1);
                return DefaultTextStyle.merge(
                  style: const TextStyle(fontFamily: 'Roboto'),
                  child: child!,
                );
              },
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
      if (name == 'resources_auto_update') {
        await tester.tap(find.byIcon(SurgeIcons.moreVertical).first);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.byIcon(SurgeIcons.schedule).last);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      if (name == 'config_vless') {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
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
