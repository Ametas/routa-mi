import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widgets/home_groups_popover.dart';
import 'package:fl_clash/views/dashboard/widgets/home_panels.dart';
import 'package:fl_clash/views/dashboard/widgets/surge_dashboard_hero.dart';
import 'package:fl_clash/views/proxies/common.dart' as proxy_common;
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The home screen's group panel (design artifact "RoutaMi Group Picker"):
/// the shown group's members in profile order, the selected one in view;
/// the header opens every group of the profile full screen.
class HomeGroupPanel extends ConsumerStatefulWidget {
  const HomeGroupPanel({super.key, this.expand = false});

  /// Fills the height it is given (the desktop home's right column); the
  /// members scroll inside. Otherwise the list stops at [membersMaxHeight].
  final bool expand;

  /// The member list scrolls inside the panel beyond this height.
  static const double membersMaxHeight = 300;

  @override
  ConsumerState<HomeGroupPanel> createState() => _HomeGroupPanelState();
}

class _HomeGroupPanelState extends ConsumerState<HomeGroupPanel> {
  final _scroll = ScrollController();
  final _selectedKey = GlobalKey();
  final _headerKey = GlobalKey();
  bool _sheetOpen = false;
  String? _revealedGroup;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Brings the selected member to the middle once a group is shown.
  void _revealSelected(String groupName) {
    if (_revealedGroup == groupName) return;
    _revealedGroup = groupName;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selected = _selectedKey.currentContext;
      if (!mounted || selected == null || !_scroll.hasClients) return;
      Scrollable.ensureVisible(selected, alignment: 0.5);
    });
  }

  /// The panel's width and the header's height, in [navigator]'s
  /// coordinates: where the desktop list of groups drops from.
  Rect? _anchor(NavigatorState navigator) {
    final panel = context.findRenderObject();
    final header = _headerKey.currentContext?.findRenderObject();
    final overlay = navigator.context.findRenderObject();
    if (panel is! RenderBox || header is! RenderBox || overlay == null) {
      return null;
    }
    final left = panel.localToGlobal(Offset.zero, ancestor: overlay);
    final top = header.localToGlobal(Offset.zero, ancestor: overlay);
    return Rect.fromLTWH(left.dx, top.dy, panel.size.width, header.size.height);
  }

  Future<void> _openGroups(List<Group> groups, String shown) async {
    setState(() => _sheetOpen = true);
    final navigator = Navigator.of(context, rootNavigator: true);
    // The desktop panel drops its groups from the header (design artifact
    // "RoutaMi for Windows"); a phone opens them full screen.
    final anchor = widget.expand ? _anchor(navigator) : null;
    final picked = await navigator.push(
      anchor != null
          ? HomeGroupsPopoverRoute(
              anchor: anchor,
              groups: groups,
              shown: shown,
              rowBuilder:
                  (
                    context,
                    group, {
                    required picked,
                    required showDivider,
                    required onTap,
                  }) => _GroupRow(
                    group: group,
                    picked: picked,
                    showDivider: showDivider,
                    nameIcons: ref.read(
                      proxiesStyleSettingProvider.select(
                        (state) => state.nameIcons,
                      ),
                    ),
                    onTap: onTap,
                    chevron: false,
                  ),
            )
          : HomeGroupsRoute(groups: groups, shown: shown),
    );
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (picked != null && picked != shown) {
      proxy_common.updateCurrentGroupName(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final groups = ref.watch(currentGroupsStateProvider).value;
    final groupName = dashboardGroupName(
      groups,
      ref.watch(
        currentProfileProvider.select((state) => state?.currentGroupName ?? ''),
      ),
    );
    final group = groups.where((group) => group.name == groupName).firstOrNull;
    if (group == null) return const SizedBox.shrink();
    final nameIcons = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.nameIcons),
    );
    final byName = {for (final group in groups) group.name: group};
    final selected = ref.watch(selectedProxyNameProvider(group.name)) ?? '';
    _revealSelected(group.name);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: surge.card,
        borderRadius: BorderRadius.circular(HomePanelLayout.panelRadius),
        border: Border.all(
          color: surge.separator,
          width: surge.spacing.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: context.appLocalizations.profileGroups,
            child: SurgePressable(
              onTap: () => _openGroups(groups, group.name),
              scaleFeedback: false,
              child: Padding(
                key: _headerKey,
                padding: const EdgeInsets.all(SurgeSpace.m + SurgeSpace.xxs),
                child: Row(
                  children: [
                    ProxyGroupIconTile(group: group, nameIcons: nameIcons),
                    const SizedBox(width: SurgeSpace.m),
                    Expanded(
                      child: ProxyNameAndChoice(
                        title: proxyTitle(group.name, nameIcons),
                        type: group.type.name,
                        automatic: proxyGroupIsAutomatic(group),
                        pinned: proxyGroupPinned(group) != null,
                        choice: proxyTitle(selected, nameIcons),
                        titleStyle: context.typography.cardTitle,
                      ),
                    ),
                    const SizedBox(width: SurgeSpace.s),
                    ProxyGroupOpenToggle(open: _sheetOpen),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: surge.spacing.hairline, color: surge.separator),
          _membersBox(
            expand: widget.expand,
            child: ListView(
              controller: _scroll,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(
                horizontal: SurgeSpace.m + SurgeSpace.xxs,
              ),
              children: [
                // Profile order, as in a selector: the choice stays in place.
                for (final (index, proxy) in group.all.indexed)
                  _MemberRow(
                    key: proxy.name == selected ? _selectedKey : null,
                    group: group,
                    proxy: proxy,
                    memberGroup: byName[proxy.name],
                    selected: proxy.name == selected,
                    showDivider: index > 0,
                    nameIcons: nameIcons,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _membersBox({required bool expand, required Widget child}) {
    if (expand) return Expanded(child: child);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: HomeGroupPanel.membersMaxHeight,
      ),
      child: child,
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({
    super.key,
    required this.group,
    required this.proxy,
    required this.memberGroup,
    required this.selected,
    required this.showDivider,
    required this.nameIcons,
  });

  final Group group;
  final Proxy proxy;

  /// Set when the member is itself a group: it shows what that group chose.
  final Group? memberGroup;
  final bool selected;
  final bool showDivider;
  final bool nameIcons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final inner = memberGroup;
    final innerChoice = inner == null
        ? ''
        : ref.watch(selectedProxyNameProvider(inner.name)) ?? '';
    final delay = inner == null
        ? ref.watch(
            delayProvider(proxyName: proxy.name, testUrl: group.testUrl),
          )
        : null;
    final titleColor = selected ? surge.primary : surge.textPrimary;
    return SurgePressable(
      onTap: () => proxy_common.applyProxyGroupMemberTap(
        group: group,
        tappedName: proxy.name,
      ),
      scaleFeedback: false,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: SurgeSpace.m - SurgeSpace.xxs,
        ),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  top: BorderSide(
                    color: surge.separator,
                    width: surge.spacing.hairline,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            if (inner != null)
              ProxyGroupIconTile(
                group: inner,
                nameIcons: nameIcons,
                selected: selected,
              )
            else
              ProxyNodeTile(
                name: proxy.name,
                nameIcons: nameIcons,
                selected: selected,
              ),
            const SizedBox(width: SurgeSpace.m),
            Expanded(
              child: inner != null
                  ? ProxyNameAndChoice(
                      title: proxyTitle(proxy.name, nameIcons),
                      type: inner.type.name,
                      automatic: proxyGroupIsAutomatic(inner),
                      pinned: proxyGroupPinned(inner) != null,
                      choice: proxyTitle(innerChoice, nameIcons),
                      titleStyle: selected
                          ? context.typography.selectedRowTitle
                          : context.typography.compactRowTitle,
                      titleColor: titleColor,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EmojiText(
                          proxyTitle(proxy.name, nameIcons),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              (selected
                                      ? context.typography.selectedRowTitle
                                      : context.typography.compactRowTitle)
                                  .copyWith(color: titleColor),
                        ),
                        Text(
                          proxy.type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.proxyCardSubtitle.copyWith(
                            color: surge.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: SurgeSpace.s),
            if (selected)
              Icon(
                SurgeIcons.confirm,
                size: SurgeIconSize.regular,
                color: surge.primary,
              )
            else if (inner == null)
              ProxyDelayText(
                delay: delay,
                onTap: () => proxy_common.proxyDelayTest(proxy, group.testUrl),
              ),
          ],
        ),
      ),
    );
  }
}

/// Every group of the profile, full screen: it slides up over the app and
/// back down; picking a group returns its name.
class HomeGroupsRoute extends PageRoute<String> {
  HomeGroupsRoute({required this.groups, required this.shown});

  final List<Group> groups;
  final String shown;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Close';

  @override
  Color? get barrierColor =>
      SurgePalette.scrim.withValues(alpha: SurgeAlpha.a62);

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => SurgeMotion.sheetEnter;

  @override
  Duration get reverseTransitionDuration => SurgeMotion.sheetExit;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _HomeGroupsSheet(groups: groups, shown: shown, animation: animation);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: animation,
          curve: SurgeMotion.enterCurve,
          reverseCurve: SurgeMotion.exitCurve,
        ),
      ),
      child: child,
    );
  }
}

class _HomeGroupsSheet extends ConsumerStatefulWidget {
  const _HomeGroupsSheet({
    required this.groups,
    required this.shown,
    required this.animation,
  });

  final List<Group> groups;
  final String shown;
  final Animation<double> animation;

  @override
  ConsumerState<_HomeGroupsSheet> createState() => _HomeGroupsSheetState();
}

class _HomeGroupsSheetState extends ConsumerState<_HomeGroupsSheet> {
  late String _picked = widget.shown;

  void _pick(String name) {
    setState(() => _picked = name);
    // Let the check land before the sheet slides away.
    Timer(SurgeMotion.press, () {
      if (mounted) Navigator.of(context).pop(name);
    });
  }

  /// Rows rise in one after another while the sheet slides up.
  Animation<double> _rowAnimation(int index) {
    final start = math.min(0.25 + index * 0.05, 0.7);
    return CurvedAnimation(
      parent: widget.animation,
      curve: Interval(start, 1, curve: SurgeMotion.enterCurve),
      reverseCurve: const Threshold(0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    final nameIcons = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.nameIcons),
    );
    return Material(
      color: surge.background,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(surge.radii.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SurgeSpace.l,
            SurgeSpace.s,
            SurgeSpace.l,
            SurgeSpace.l,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: SurgeSpace.xxxl + SurgeSpace.s,
                  height: SurgeSpace.xs,
                  decoration: BoxDecoration(
                    color: surge.separator,
                    borderRadius: BorderRadius.circular(SurgeSpace.xxs),
                  ),
                ),
              ),
              const SizedBox(height: SurgeSpace.l),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.profileGroups,
                          style: context.typography.screenTitle.copyWith(
                            color: surge.textPrimary,
                          ),
                        ),
                        Text(
                          l10n.profileGroupsHint(widget.groups.length),
                          style: context.typography.supporting.copyWith(
                            color: surge.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n.close,
                    child: SurgePressable(
                      onTap: () => Navigator.of(context).pop(),
                      child: const ProxyGroupOpenToggle(open: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SurgeSpace.l),
              // As tall as its groups, scrolling once they fill the screen.
              Flexible(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: surge.card,
                    borderRadius: BorderRadius.circular(
                      HomePanelLayout.panelRadius,
                    ),
                    border: Border.all(
                      color: surge.separator,
                      width: surge.spacing.hairline,
                    ),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: SurgeSpace.m + SurgeSpace.xxs,
                    ),
                    itemCount: widget.groups.length,
                    itemBuilder: (context, index) {
                      final group = widget.groups[index];
                      final rowAnimation = _rowAnimation(index);
                      return FadeTransition(
                        opacity: rowAnimation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.4),
                            end: Offset.zero,
                          ).animate(rowAnimation),
                          child: _GroupRow(
                            group: group,
                            picked: group.name == _picked,
                            showDivider: index > 0,
                            nameIcons: nameIcons,
                            onTap: () => _pick(group.name),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupRow extends ConsumerWidget {
  const _GroupRow({
    required this.group,
    required this.picked,
    required this.showDivider,
    required this.nameIcons,
    required this.onTap,
    this.chevron = true,
  });

  final Group group;
  final bool picked;
  final bool showDivider;
  final bool nameIcons;
  final VoidCallback onTap;

  /// Other groups point on with a chevron; a dropdown leaves them bare.
  final bool chevron;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final choice = ref.watch(selectedProxyNameProvider(group.name)) ?? '';
    return Semantics(
      button: true,
      selected: picked,
      child: SurgePressable(
        onTap: onTap,
        scaleFeedback: false,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: SurgeSpace.m - SurgeSpace.xxs,
          ),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(
                    top: BorderSide(
                      color: surge.separator,
                      width: surge.spacing.hairline,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              ProxyGroupIconTile(
                group: group,
                nameIcons: nameIcons,
                selected: picked,
              ),
              const SizedBox(width: SurgeSpace.m),
              Expanded(
                child: ProxyNameAndChoice(
                  title: proxyTitle(group.name, nameIcons),
                  type: group.type.name,
                  automatic: proxyGroupIsAutomatic(group),
                  pinned: proxyGroupPinned(group) != null,
                  choice: proxyTitle(choice, nameIcons),
                  titleStyle: picked
                      ? context.typography.selectedRowTitle
                      : context.typography.compactRowTitle,
                  titleColor: picked ? surge.primary : null,
                ),
              ),
              const SizedBox(width: SurgeSpace.s),
              AnimatedOpacity(
                duration: SurgeMotion.state,
                opacity: picked || chevron ? 1 : 0,
                child: Icon(
                  picked || !chevron
                      ? SurgeIcons.confirm
                      : SurgeIcons.chevronRight,
                  size: SurgeIconSize.compact,
                  color: picked ? surge.primary : surge.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
