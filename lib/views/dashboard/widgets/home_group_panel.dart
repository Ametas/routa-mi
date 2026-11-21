import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
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
  const HomeGroupPanel({super.key});

  /// The member list scrolls inside the panel beyond this height.
  static const double membersMaxHeight = 300;
  static const double toggleSize = 30;

  @override
  ConsumerState<HomeGroupPanel> createState() => _HomeGroupPanelState();
}

class _HomeGroupPanelState extends ConsumerState<HomeGroupPanel> {
  final _scroll = ScrollController();
  final _selectedKey = GlobalKey();
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

  Future<void> _openGroups(List<Group> groups, String shown) async {
    setState(() => _sheetOpen = true);
    final picked = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(HomeGroupsRoute(groups: groups, shown: shown));
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
                padding: const EdgeInsets.all(SurgeSpace.m + SurgeSpace.xxs),
                child: Row(
                  children: [
                    _GroupTile(group: group, nameIcons: nameIcons),
                    const SizedBox(width: SurgeSpace.m),
                    Expanded(
                      child: _NameAndChoice(
                        title: _title(group.name, nameIcons),
                        type: group.type.name,
                        choice: _title(selected, nameIcons),
                        titleStyle: context.typography.cardTitle,
                      ),
                    ),
                    const SizedBox(width: SurgeSpace.s),
                    _OpenToggle(open: _sheetOpen),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: surge.spacing.hairline, color: surge.separator),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: HomeGroupPanel.membersMaxHeight,
            ),
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
}

String _title(String name, bool nameIcons) =>
    nameIcons ? splitProxyNameIcon(name).title : name;

/// The group's own icon from the profile, else the emoji its name starts
/// with.
class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.nameIcons,
    this.selected = false,
  });

  final Group group;
  final bool nameIcons;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final Widget tile = group.icon.isNotEmpty
        ? Container(
            width: HomePanelLayout.nodeIcon,
            height: HomePanelLayout.nodeIcon,
            padding: const EdgeInsets.all(SurgeSpace.xs + SurgeSpace.xxs),
            decoration: BoxDecoration(
              color: surge.textSecondary.withValues(alpha: SurgeAlpha.a08),
              borderRadius: BorderRadius.circular(surge.radii.input),
            ),
            child: IconTheme.merge(
              data: IconThemeData(
                size: SurgeIconSize.compact,
                color: surge.primary,
              ),
              child: CommonTargetIcon(src: group.icon),
            ),
          )
        : ProxyNameIconTile(
            icon: nameIcons ? splitProxyNameIcon(group.name).icon : null,
            size: HomePanelLayout.nodeIcon,
          );
    return _SelectionRing(selected: selected, child: tile);
  }
}

class _SelectionRing extends StatelessWidget {
  const _SelectionRing({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return AnimatedContainer(
      duration: SurgeMotion.state,
      decoration: BoxDecoration(
        color: selected
            ? surge.primary.withValues(alpha: SurgeAlpha.a16)
            : null,
        borderRadius: BorderRadius.circular(surge.radii.input),
        border: Border.all(
          color: selected ? surge.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}

/// A group's name over its type and what it has chosen.
class _NameAndChoice extends StatelessWidget {
  const _NameAndChoice({
    required this.title,
    required this.type,
    required this.choice,
    required this.titleStyle,
    this.titleColor,
  });

  final String title;
  final String type;
  final String choice;
  final TextStyle titleStyle;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        EmojiText(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle.copyWith(color: titleColor ?? surge.textPrimary),
        ),
        const SizedBox(height: SurgeSpace.xxs),
        Row(
          children: [
            _TypeChip(type),
            const SizedBox(width: SurgeSpace.xs + SurgeSpace.xxs),
            Flexible(
              child: EmojiText(
                choice,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.proxyCardSubtitle.copyWith(
                  color: surge.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(this.type);

  final String type;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SurgeSpace.xs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(surge.radii.compact),
        border: Border.all(color: surge.separator),
      ),
      child: Text(
        type.toUpperCase(),
        maxLines: 1,
        style: context.typography.chartLabel.copyWith(
          color: surge.textSecondary,
        ),
      ),
    );
  }
}

/// The round arrow that says the header opens; filled while it is open.
class _OpenToggle extends StatelessWidget {
  const _OpenToggle({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return AnimatedRotation(
      turns: open ? 0.5 : 0,
      duration: SurgeMotion.container,
      curve: SurgeMotion.stateCurve,
      child: AnimatedContainer(
        duration: SurgeMotion.container,
        width: HomeGroupPanel.toggleSize,
        height: HomeGroupPanel.toggleSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: open ? surge.primary : null,
          border: Border.all(color: open ? surge.primary : surge.separator),
        ),
        child: Icon(
          SurgeIcons.expand,
          size: SurgeIconSize.compact,
          color: open ? surge.onPrimary : surge.textSecondary,
        ),
      ),
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
              _GroupTile(group: inner, nameIcons: nameIcons, selected: selected)
            else
              _SelectionRing(
                selected: selected,
                child: ProxyNameIconTile(
                  icon: nameIcons ? splitProxyNameIcon(proxy.name).icon : null,
                  size: HomePanelLayout.nodeIcon,
                ),
              ),
            const SizedBox(width: SurgeSpace.m),
            Expanded(
              child: inner != null
                  ? _NameAndChoice(
                      title: _title(proxy.name, nameIcons),
                      type: inner.type.name,
                      choice: _title(innerChoice, nameIcons),
                      titleStyle: selected
                          ? context.typography.selectedRowTitle
                          : context.typography.compactRowTitle,
                      titleColor: titleColor,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EmojiText(
                          _title(proxy.name, nameIcons),
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
            else if (delay != null)
              Text(
                delay < 0 ? context.appLocalizations.timeout : '$delay ms',
                style: context.typography.technical.copyWith(
                  color: surge.latencyColor(delay) ?? surge.textSecondary,
                ),
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
                      child: const _OpenToggle(open: true),
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
  });

  final Group group;
  final bool picked;
  final bool showDivider;
  final bool nameIcons;
  final VoidCallback onTap;

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
              _GroupTile(group: group, nameIcons: nameIcons, selected: picked),
              const SizedBox(width: SurgeSpace.m),
              Expanded(
                child: _NameAndChoice(
                  title: _title(group.name, nameIcons),
                  type: group.type.name,
                  choice: _title(choice, nameIcons),
                  titleStyle: picked
                      ? context.typography.selectedRowTitle
                      : context.typography.compactRowTitle,
                  titleColor: picked ? surge.primary : null,
                ),
              ),
              const SizedBox(width: SurgeSpace.s),
              Icon(
                picked ? SurgeIcons.confirm : SurgeIcons.chevronRight,
                size: SurgeIconSize.compact,
                color: picked ? surge.primary : surge.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
