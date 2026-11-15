import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/surge/surge_side_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The side navigation for windows wider than a phone (design system 3.0):
/// the 72 dp rail up to 1023 dp, the 240 dp menu from 1024 dp.
class AppSideNav extends ConsumerWidget {
  const AppSideNav({super.key});

  static List<SurgeSideNavItem> itemsFor(
    List<NavigationItem> navigationItems, {
    required String activityGroup,
  }) {
    var grouped = false;
    return [
      for (final item in navigationItems)
        () {
          final (icon, iconOutlined) = switch (item.label) {
            PageLabel.dashboard ||
            PageLabel.proxies ||
            PageLabel.profiles ||
            PageLabel.tools => SurgeIcons.bottomNavigationPair(item.label),
            _ => (
              item.icon.icon ?? SurgeIcons.fallback,
              item.icon.icon ?? SurgeIcons.fallback,
            ),
          };
          final opensGroup =
              !grouped && item.modes.contains(NavigationItemMode.more);
          grouped = grouped || opensGroup;
          return SurgeSideNavItem(
            icon: icon,
            iconOutlined: iconOutlined,
            label: Intl.message(item.label.name),
            group: opensGroup ? activityGroup : null,
          );
        }(),
    ];
  }

  void _toPage(PageLabel pageLabel) {
    globalState.container
        .read(currentPageLabelProvider.notifier)
        .toPage(pageLabel);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(navigationStateProvider);
    final navigationItems = state.navigationItems;
    final items = itemsFor(
      navigationItems,
      activityGroup: context.appLocalizations.navActivity,
    );
    void onTap(int index) => _toPage(navigationItems[index].label);
    if (state.viewMode == ViewMode.laptop) {
      return SurgeNavRail(
        items: items,
        currentIndex: state.currentIndex,
        onTap: onTap,
        leading: const _BrandMark(),
      );
    }
    return SurgeSideMenu(
      items: items,
      currentIndex: state.currentIndex,
      onTap: onTap,
      header: const _MenuHeader(),
      footer: const _StatusCard(),
    );
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SurgeSpace.s,
        SurgeSpace.xs,
        SurgeSpace.s,
        SurgeSpace.l,
      ),
      child: Row(
        children: [
          const _BrandMark(),
          const SizedBox(width: SurgeSpace.m),
          Text(appName, style: context.typography.rootAppBarTitle),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(surge.radii.compact),
      child: Image.asset(
        'assets/images/icon.png',
        width: SurgeSideNavLayout.brandMark,
        height: SurgeSideNavLayout.brandMark,
        semanticLabel: appName,
      ),
    );
  }
}

/// Whether the proxy runs, with TUN, and on which port.
class _StatusCard extends ConsumerWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    final running = ref.watch(runTimeProvider.select((value) => value != null));
    final tun = ref.watch(realTunEnableProvider);
    final port = ref.watch(
      patchClashConfigProvider.select((state) => state.mixedPort),
    );
    final color = running ? surge.green : surge.textSecondary;
    final status = running ? l10n.connected : l10n.disconnected;
    return SurgeCard(
      borderRadius: surge.radii.smallCard,
      padding: const EdgeInsets.all(SurgeSpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            running && tun ? '$status · TUN' : status,
            style: context.typography.compactRowTitle.copyWith(color: color),
          ),
          const SizedBox(height: SurgeSpace.xs),
          Text(
            '127.0.0.1:$port',
            style: context.typography.technical.copyWith(
              color: surge.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
