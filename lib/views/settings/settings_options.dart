import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/enum/profile_core.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/theme/amoled_theme.dart';
import 'package:fl_clash/theme/app_color_source.dart';
import 'package:fl_clash/views/theme_amoled.dart';
import 'package:fl_clash/widgets/settings_unfold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The settings each section of the settings screen unfolds (design 3.1
/// "RoutaMi Settings Unfold"): the ones changed most often, then a link to
/// the section's full page. They write the same providers as those pages.

String? _mihomoOnly(BuildContext context, WidgetRef ref) {
  final xray = ref.watch(
    currentProfileProvider.select(
      (profile) => profile?.core == ProfileCore.xray,
    ),
  );
  return xray ? context.appLocalizations.mihomoOnlySetting : null;
}

/// Text sizes offered as chips; 0 follows the system.
const settingsTextScales = <double>[0, 0.9, 1, 1.1, 1.2];

List<UnfoldOption> themeOptions(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback openPage,
}) {
  final l10n = context.appLocalizations;
  final theme = ref.watch(themeSettingProvider);
  final notifier = ref.read(themeSettingProvider.notifier);
  final nameIcons = ref.watch(
    proxiesStyleSettingProvider.select((state) => state.nameIcons),
  );
  final accentShows =
      theme.pureBlack && theme.colorSource == AppColorSource.preset;
  return [
    UnfoldChoice<ThemeMode>(
      l10n.themeMode,
      values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
      value: theme.themeMode,
      labelOf: (mode) => switch (mode) {
        ThemeMode.system => l10n.auto,
        ThemeMode.light => l10n.light,
        ThemeMode.dark => l10n.dark,
      },
      onChanged: (mode) =>
          notifier.update((state) => state.copyWith(themeMode: mode)),
    ),
    UnfoldSwitch(
      l10n.amoledMode,
      value: theme.pureBlack,
      // AMOLED shows in dark mode only, so turning it on leaves light mode.
      onChanged: (value) => notifier.update(
        (state) => state.copyWith(
          pureBlack: value,
          themeMode: value && state.themeMode == ThemeMode.light
              ? ThemeMode.dark
              : state.themeMode,
        ),
      ),
    ),
    UnfoldSwatches(
      l10n.accent,
      colors: [
        for (final accent in AmoledAccent.values) AmoledTheme.accent(accent),
      ],
      names: [
        for (final accent in AmoledAccent.values)
          amoledAccentLabel(l10n, accent),
      ],
      index: theme.amoledAccent.index,
      onChanged: (index) => notifier.update(
        (state) => state.copyWith(amoledAccent: AmoledAccent.values[index]),
      ),
      disabledReason: accentShows ? null : l10n.accentAmoledOnly,
    ),
    UnfoldChoice<double>(
      l10n.textScale,
      values: settingsTextScales,
      value: theme.textScale.enable ? theme.textScale.scale : 0,
      labelOf: (scale) => scale == 0 ? l10n.auto : '${(scale * 100).round()}%',
      summaryOf: (scale) => scale == 0 ? null : '${(scale * 100).round()}%',
      onChanged: (scale) => notifier.update(
        (state) => state.copyWith(
          textScale: scale == 0
              ? state.textScale.copyWith(enable: false)
              : TextScale(enable: true, scale: scale),
        ),
      ),
    ),
    UnfoldSwitch(
      l10n.nameIcons,
      value: nameIcons,
      onChanged: (value) => ref
          .read(proxiesStyleSettingProvider.notifier)
          .update((state) => state.copyWith(nameIcons: value)),
    ),
    UnfoldLink(l10n.allSettings, onTap: openPage),
  ];
}

List<UnfoldOption> networkOptions(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback openPage,
}) {
  final l10n = context.appLocalizations;
  final mihomoOnly = _mihomoOnly(context, ref);
  final vpn = ref.watch(vpnSettingProvider);
  final vpnNotifier = ref.read(vpnSettingProvider.notifier);
  final tun = ref.watch(patchClashConfigProvider.select((state) => state.tun));
  final patch = ref.read(patchClashConfigProvider.notifier);
  return [
    if (system.isAndroid) ...[
      UnfoldSwitch(
        'VPN',
        value: vpn.enable,
        onChanged: (value) =>
            vpnNotifier.update((state) => state.copyWith(enable: value)),
      ),
      UnfoldSwitch(
        l10n.systemProxy,
        value: vpn.systemProxy,
        onChanged: (value) =>
            vpnNotifier.update((state) => state.copyWith(systemProxy: value)),
      ),
      UnfoldSwitch(
        'IPv6',
        value: vpn.ipv6,
        onChanged: (value) =>
            vpnNotifier.update((state) => state.copyWith(ipv6: value)),
      ),
    ],
    if (system.isDesktop) ...[
      UnfoldSwitch(
        l10n.systemProxy,
        value: ref.watch(
          networkSettingProvider.select((state) => state.systemProxy),
        ),
        onChanged: (value) => ref
            .read(networkSettingProvider.notifier)
            .update((state) => state.copyWith(systemProxy: value)),
      ),
      UnfoldSwitch(
        l10n.tun,
        value: tun.enable,
        onChanged: (value) =>
            patch.update((state) => state.copyWith.tun(enable: value)),
        disabledReason: mihomoOnly,
      ),
    ],
    UnfoldChoice<TunStack>(
      l10n.stackMode,
      values: TunStack.values,
      value: tun.stack,
      labelOf: (stack) => stack.name,
      onChanged: (stack) =>
          patch.update((state) => state.copyWith.tun(stack: stack)),
      disabledReason: mihomoOnly,
    ),
    UnfoldLink(l10n.allSettings, onTap: openPage),
  ];
}

/// The mixed port's checks from the port dialog: the range and no clash
/// with the other inbounds.
String? validateMixedPort(
  String value, {
  required AppLocalizations l10n,
  required List<int> otherPorts,
}) {
  if (value.isEmpty) return l10n.emptyTip(l10n.mixedPort);
  final port = int.tryParse(value);
  if (port == null) return l10n.numberTip(l10n.mixedPort);
  if (port < 1024 || port > 49151) return l10n.portTip(l10n.mixedPort);
  if (otherPorts.contains(port)) return l10n.portConflictTip;
  return null;
}

List<UnfoldOption> basicConfigOptions(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback openPage,
}) {
  final l10n = context.appLocalizations;
  final config = ref.watch(patchClashConfigProvider);
  final patch = ref.read(patchClashConfigProvider.notifier);
  final vless = ref.watch(networkSettingProvider.select((s) => s.localVless));
  final testUrl = ref.watch(appSettingProvider.select((s) => s.testUrl));
  return [
    UnfoldField(
      l10n.mixedPort,
      value: '${config.mixedPort}',
      keyboardType: TextInputType.number,
      validator: (value) => validateMixedPort(
        value,
        l10n: l10n,
        otherPorts: [
          for (final port in [
            config.port,
            config.socksPort,
            config.redirPort,
            config.tproxyPort,
          ])
            if (port != 0) port,
          if (vless.enable) vless.port,
        ],
      ),
      onSubmitted: (value) =>
          patch.update((state) => state.copyWith(mixedPort: int.parse(value))),
    ),
    UnfoldSwitch(
      l10n.allowLan,
      value: config.allowLan,
      onChanged: (value) =>
          patch.update((state) => state.copyWith(allowLan: value)),
    ),
    UnfoldChoice<LogLevel>(
      l10n.logLevel,
      values: LogLevel.values,
      value: config.logLevel,
      labelOf: (level) => level.name,
      onChanged: (level) =>
          patch.update((state) => state.copyWith(logLevel: level)),
    ),
    UnfoldField(
      l10n.testUrl,
      value: testUrl,
      keyboardType: TextInputType.url,
      validator: (value) {
        if (value.isEmpty) return l10n.emptyTip(l10n.testUrl);
        if (!value.isUrl) return l10n.urlTip(l10n.testUrl);
        return null;
      },
      onSubmitted: (value) => ref
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(testUrl: value)),
    ),
    UnfoldLink(l10n.allSettings, onTap: openPage),
  ];
}

List<UnfoldOption> applicationOptions(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback openPage,
}) {
  final l10n = context.appLocalizations;
  final app = ref.watch(appSettingProvider);
  final notifier = ref.read(appSettingProvider.notifier);
  UnfoldSwitch toggle(
    String label,
    bool value,
    AppSettingProps Function(AppSettingProps state, bool value) apply,
  ) => UnfoldSwitch(
    label,
    value: value,
    onChanged: (value) => notifier.update((state) => apply(state, value)),
  );
  return [
    if (system.isDesktop) ...[
      toggle(
        l10n.autoLaunch,
        app.autoLaunch,
        (state, value) => state.copyWith(autoLaunch: value),
      ),
      toggle(
        l10n.silentLaunch,
        app.silentLaunch,
        (state, value) => state.copyWith(silentLaunch: value),
      ),
    ],
    toggle(
      l10n.autoRun,
      app.autoRun,
      (state, value) => state.copyWith(autoRun: value),
    ),
    if (system.isAndroid)
      toggle(
        l10n.exclude,
        app.hidden,
        (state, value) => state.copyWith(hidden: value),
      ),
    toggle(
      l10n.minimizeOnExit,
      app.minimizeOnExit,
      (state, value) => state.copyWith(minimizeOnExit: value),
    ),
    toggle(
      l10n.autoCheckUpdate,
      app.autoCheckUpdate,
      (state, value) => state.copyWith(autoCheckUpdate: value),
    ),
    UnfoldLink(l10n.allSettings, onTap: openPage),
  ];
}
