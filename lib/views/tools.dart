import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/about.dart';
import 'package:fl_clash/views/application_setting.dart';
import 'package:fl_clash/views/backup_and_restore.dart';
import 'package:fl_clash/views/config/config.dart';
import 'package:fl_clash/views/config/dns.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/views/hotkey.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'config/advanced.dart';
import 'developer.dart';
import 'theme.dart';
import 'package:fl_clash/providers/settings_apply.dart';
import 'package:fl_clash/services/settings/settings_contract.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/widgets/mihomo_only.dart';
import 'package:fl_clash/views/settings/settings_options.dart';
import 'package:fl_clash/views/settings/settings_pane.dart';
import 'package:fl_clash/views/settings/settings_tile.dart';
import 'package:fl_clash/views/desktop_layout.dart';

class ToolsView extends ConsumerStatefulWidget {
  const ToolsView({super.key});

  @override
  ConsumerState<ToolsView> createState() => _ToolViewState();
}

class _ToolViewState extends ConsumerState<ToolsView> {
  Widget _buildNavigationMenuItem(NavigationItem navigationItem) {
    final tile = SettingsPageEntry(
      icon: navigationItem.icon,
      title: Intl.message(navigationItem.label.name),
      subtitle: navigationItem.description != null
          ? Intl.message(navigationItem.description!)
          : null,
      page: navigationItem.builder,
    );
    // Xray has no connection tracker to list.
    return switch (navigationItem.label) {
      PageLabel.requests || PageLabel.connections => MihomoOnly(child: tile),
      _ => tile,
    };
  }

  void _open(WidgetBuilder page) => showExtend(context, builder: page);

  Widget _networkPage(BuildContext context) => CommonScaffold(
    title: context.appLocalizations.network,
    body: const NetworkListView(),
  );

  /// Settings grouped as in design 3.1: the most used ones unfold in place,
  /// the rest open their page.
  List<Widget> _settingGroups(bool enableDeveloperMode) {
    final l10n = context.appLocalizations;
    return [
      SettingsGroup(
        label: l10n.settingsInterface,
        children: [
          SettingsUnfoldEntry(
            icon: const Icon(SurgeIcons.style),
            title: l10n.theme,
            fallbackSubtitle: l10n.themeDesc,
            page: (_) => const ThemeView(),
            options: (context, ref) => themeOptions(
              context,
              ref,
              openPage: () => _open((_) => const ThemeView()),
            ),
          ),
          SettingsUnfoldEntry(
            icon: const Icon(SurgeIcons.settings),
            title: l10n.application,
            fallbackSubtitle: l10n.applicationDesc,
            page: (_) => const ApplicationSettingView(),
            options: (context, ref) => applicationOptions(
              context,
              ref,
              openPage: () => _open((_) => const ApplicationSettingView()),
            ),
          ),
          if (system.isDesktop) const _HotkeyItem(),
        ],
      ),
      SettingsGroup(
        label: l10n.settingsConnection,
        children: [
          SettingsUnfoldEntry(
            icon: const Icon(SurgeIcons.edit),
            title: l10n.basicConfig,
            fallbackSubtitle: l10n.basicConfigDesc,
            page: (_) => const ConfigView(),
            options: (context, ref) => basicConfigOptions(
              context,
              ref,
              openPage: () => _open((_) => const ConfigView()),
            ),
          ),
          SettingsUnfoldEntry(
            icon: const Icon(SurgeIcons.vpnKey),
            title: l10n.network,
            fallbackSubtitle: l10n.networkDesc,
            page: _networkPage,
            options: (context, ref) => networkOptions(
              context,
              ref,
              openPage: () => _open(_networkPage),
            ),
          ),
          const MihomoOnly(child: _DnsItem()),
          const _AdvancedConfigItem(),
        ],
      ),
      SettingsGroup(
        label: l10n.settingsData,
        children: [
          const _BackupItem(),
          if (enableDeveloperMode) const _DeveloperItem(),
          const _InfoItem(),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final vm2 = ref.watch(
      appSettingProvider.select(
        (state) => VM2(state.locale, state.developerMode),
      ),
    );
    final items = [
      Consumer(
        builder: (_, ref, _) {
          final state = ref.watch(moreToolsSelectorStateProvider);
          if (state.navigationItems.isEmpty) {
            return Container();
          }
          return SettingsGroup(
            label: context.appLocalizations.more,
            children: [
              for (final item in state.navigationItems)
                _buildNavigationMenuItem(item),
            ],
          );
        },
      ),
      ..._settingGroups(vm2.b),
    ];
    final surge = SurgeTheme.of(context);
    final bottom = SurgeBottomNavLayout.mainPageBottomPadding(context);
    return CommonScaffold(
      backgroundColor: surge.background,
      title: context.appLocalizations.tools,
      appBarActions: const [],
      titleVariant: SlAppBarTitleVariant.root,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final twoPane = DesktopLayout.twoPane(constraints.maxWidth);
          final list = ListView.builder(
            key: toolsStoreKey,
            itemCount: items.length,
            itemBuilder: (_, index) => items[index],
            padding: twoPane
                ? EdgeInsets.only(top: SurgeSpace.xs, bottom: bottom)
                : EdgeInsets.fromLTRB(
                    SurgeSpace.l,
                    SurgeSpace.xs,
                    SurgeSpace.l,
                    bottom,
                  ),
          );
          if (!twoPane) return list;
          // A wide window (design artifact "RoutaMi for Windows"): the
          // sections on the left, the selected one's page beside them.
          return SettingsTwoPane(
            initial: SettingsPaneSection(
              title: context.appLocalizations.theme,
              page: (_) => const ThemeView(),
            ),
            padding: EdgeInsets.fromLTRB(
              SurgeSpace.l,
              SurgeSpace.none,
              SurgeSpace.l,
              bottom + SurgeSpace.l,
            ),
            list: list,
          );
        },
      ),
    );
  }
}

class _BackupItem extends StatelessWidget {
  const _BackupItem();

  @override
  Widget build(BuildContext context) {
    return SettingsPageEntry(
      icon: const Icon(SurgeIcons.cloudSync),
      title: context.appLocalizations.backupAndRestore,
      subtitle: context.appLocalizations.backupAndRestoreDesc,
      page: (_) => const BackupAndRestore(),
    );
  }
}

class _HotkeyItem extends StatelessWidget {
  const _HotkeyItem();

  @override
  Widget build(BuildContext context) {
    return SettingsPageEntry(
      icon: const Icon(SurgeIcons.keyboard),
      title: context.appLocalizations.hotkeyManagement,
      subtitle: context.appLocalizations.hotkeyManagementDesc,
      page: (_) => const HotKeyView(),
    );
  }
}

class _DnsItem extends StatelessWidget {
  const _DnsItem();

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SettingsPageEntry(
      icon: const Icon(SurgeIcons.dns),
      title: 'DNS',
      subtitle: appLocalizations.dnsDesc,
      page: (_) => CommonScaffold(
        title: 'DNS',
        appBarActions: [
          SlAppBarIconAction(
            icon: SurgeIcons.replay,
            tooltip: appLocalizations.reset,
            onPressed: () async {
              final container = ProviderScope.containerOf(context);
              final source = container
                  .read(dnsSettingsSourceProvider)
                  .asData
                  ?.value;
              if (source == null || source == DnsSettingsSource.subscription) {
                globalState.showNotifier(
                  'APP DNS is not active; resolve the source or enable override first.',
                );
                return;
              }
              final res = await globalState.showMessage(
                title: appLocalizations.reset,
                message: TextSpan(text: appLocalizations.resetTip),
              );
              if (res != true) return;
              container
                  .read(patchClashConfigProvider.notifier)
                  .update((state) => state.copyWith(dns: defaultDns));
            },
          ),
        ],
        body: const DnsListView(),
      ),
    );
  }
}

class _AdvancedConfigItem extends StatelessWidget {
  const _AdvancedConfigItem();

  @override
  Widget build(BuildContext context) {
    return SettingsPageEntry(
      icon: const Icon(SurgeIcons.build),
      title: context.appLocalizations.advancedConfig,
      subtitle: context.appLocalizations.advancedConfigDesc,
      page: (_) => const AdvancedConfigView(),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem();

  @override
  Widget build(BuildContext context) {
    return SettingsPageEntry(
      icon: const Icon(SurgeIcons.info),
      title: context.appLocalizations.about,
      subtitle: context.appLocalizations.versionAndProjectLinks,
      page: (_) => const AboutView(),
    );
  }
}

class _DeveloperItem extends StatelessWidget {
  const _DeveloperItem();

  @override
  Widget build(BuildContext context) {
    return SettingsPageEntry(
      icon: const Icon(SurgeIcons.developer),
      title: context.appLocalizations.developerMode,
      page: (_) => const DeveloperView(),
    );
  }
}
