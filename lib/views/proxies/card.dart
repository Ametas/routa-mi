import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/proxies/common.dart';
import 'package:fl_clash/views/proxies/list_metrics.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which part of a group card a list row draws (design 3.1 "RoutaMi
/// Proxies"): the virtualized list builds every card from slices.
enum ProxyCardSlice { whole, top, middle, bottom }

/// The card background, outline and rounded corners of one slice.
class ProxyGroupCardSlice extends StatelessWidget {
  const ProxyGroupCardSlice({
    super.key,
    required this.slice,
    required this.child,
  });

  final ProxyCardSlice slice;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final side = BorderSide(
      color: surge.separator,
      width: surge.spacing.hairline,
    );
    const radius = Radius.circular(ProxyGroupBits.cardRadius);
    final top = slice == ProxyCardSlice.whole || slice == ProxyCardSlice.top;
    final bottom =
        slice == ProxyCardSlice.whole || slice == ProxyCardSlice.bottom;
    final borderRadius = BorderRadius.vertical(
      top: top ? radius : Radius.zero,
      bottom: bottom ? radius : Radius.zero,
    );
    // A decoration, not a Container: the outline must not take room from
    // the fixed row extents.
    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surge.card,
          borderRadius: borderRadius,
        ),
        position: DecorationPosition.background,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border(
              left: side,
              right: side,
              top: top ? side : BorderSide.none,
              bottom: bottom ? side : BorderSide.none,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// What a member row shows, shared by the phone row and the desktop card.
class _Member {
  const _Member({
    required this.title,
    required this.subline,
    required this.tile,
    required this.delay,
    required this.selected,
    required this.pinned,
    required this.fullName,
  });

  final Widget title;
  final Widget subline;
  final Widget tile;
  final Widget delay;
  final bool selected;
  final bool pinned;
  final String fullName;

  factory _Member.watch(
    BuildContext context,
    WidgetRef ref, {
    required Group group,
    required Proxy proxy,
  }) {
    final surge = SurgeTheme.of(context);
    final nameIcons = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.nameIcons),
    );
    final selected =
        ref.watch(selectedProxyNameProvider(group.name)) == proxy.name;
    // A member that is itself a group shows what that group chose.
    final inner = ref.watch(
      groupsProvider.select((groups) => groups.getGroup(proxy.name)),
    );
    final subtitleStyle = context.typography.proxyCardSubtitle.copyWith(
      color: surge.textSecondary,
    );
    final Widget subline;
    if (inner == null) {
      subline = Text(
        proxy.type,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: subtitleStyle,
      );
    } else {
      final choice = ref.watch(selectedProxyNameProvider(inner.name)) ?? '';
      subline = Row(
        children: [
          ProxyGroupTypeChip(
            inner.type.name,
            automatic: proxyGroupIsAutomatic(inner),
          ),
          if (proxyGroupPinned(inner) != null) ...[
            const SizedBox(width: SurgeSpace.xs),
            const ProxyPinMark(),
          ],
          const SizedBox(width: SurgeSpace.xs + SurgeSpace.xxs),
          Flexible(
            child: EmojiText(
              proxyTitle(choice, nameIcons),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: subtitleStyle,
            ),
          ),
        ],
      );
    }
    return _Member(
      title: EmojiText(
        proxyTitle(proxy.name, nameIcons),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            (selected
                    ? context.typography.selectedRowTitle
                    : context.typography.compactRowTitle)
                .copyWith(color: selected ? surge.primary : surge.textPrimary),
      ),
      subline: subline,
      tile: inner != null
          ? ProxyGroupIconTile(
              group: inner,
              nameIcons: nameIcons,
              selected: selected,
            )
          : ProxyNodeTile(
              name: proxy.name,
              nameIcons: nameIcons,
              selected: selected,
            ),
      delay: ProxyDelayText(
        delay: ref.watch(
          delayProvider(proxyName: proxy.name, testUrl: group.testUrl),
        ),
        onTap: () => proxyDelayTest(proxy, group.testUrl),
      ),
      selected: selected,
      pinned: proxyGroupPinned(group) == proxy.name,
      fullName: proxyFullDisplayName(
        visibleName: proxy.name,
        resolved: ref.watch(realSelectedProxyStateProvider(proxy.name)),
      ),
    );
  }
}

/// A node row of a group card on the phone: tile, name over protocol, the
/// delay (tap to test again) and a check on the chosen one.
class ProxyCard extends ConsumerWidget {
  const ProxyCard({
    super.key,
    required this.group,
    required this.proxy,
    this.showDivider = false,
  });

  final Group group;
  final Proxy proxy;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ProxyTrace.noteHotspotBuild('proxy_card');
    final surge = SurgeTheme.of(context);
    final member = _Member.watch(context, ref, group: group, proxy: proxy);
    return LongPressFullText(
      message: member.fullName,
      child: Semantics(
        selected: member.selected,
        button: true,
        child: SurgePressable(
          onTap: () =>
              applyProxyGroupMemberTap(group: group, tappedName: proxy.name),
          scaleFeedback: false,
          child: Padding(
            padding: const EdgeInsets.only(
              left: ProxyListMetrics.cardStart,
              right: ProxyListMetrics.cardEnd,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: showDivider ? surge.separator : Colors.transparent,
                    width: ProxyListMetrics.hairline,
                  ),
                ),
              ),
              child: Row(
                children: [
                  member.tile,
                  const SizedBox(width: SurgeSpace.m),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        member.title,
                        const SizedBox(height: SurgeSpace.xxs),
                        member.subline,
                      ],
                    ),
                  ),
                  const SizedBox(width: SurgeSpace.s),
                  if (member.pinned) ...[
                    const ProxyPinMark(),
                    const SizedBox(width: SurgeSpace.xs),
                  ],
                  member.delay,
                  if (member.selected) ...[
                    const SizedBox(width: SurgeSpace.xs),
                    Icon(
                      SurgeIcons.confirm,
                      size: SurgeIconSize.compact,
                      color: surge.primary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A node card of the desktop grid; the chosen one carries the accent.
class ProxyTileCard extends ConsumerWidget {
  const ProxyTileCard({super.key, required this.group, required this.proxy});

  final Group group;
  final Proxy proxy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ProxyTrace.noteHotspotBuild('proxy_card');
    final surge = SurgeTheme.of(context);
    final member = _Member.watch(context, ref, group: group, proxy: proxy);
    final radius = BorderRadius.circular(surge.radii.list);
    return LongPressFullText(
      message: member.fullName,
      child: Semantics(
        selected: member.selected,
        button: true,
        child: SurgePressable(
          onTap: () =>
              applyProxyGroupMemberTap(group: group, tappedName: proxy.name),
          scaleFeedback: false,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: SurgeMotion.state,
            padding: const EdgeInsets.all(ProxyListMetrics.rowPadding),
            decoration: BoxDecoration(
              color: member.selected
                  ? surge.primary.withValues(alpha: SurgeAlpha.a12)
                  : null,
              borderRadius: radius,
              border: Border.all(
                color: member.selected ? surge.primary : surge.separator,
                width: ProxyListMetrics.tileBorder,
              ),
            ),
            child: Row(
              children: [
                member.tile,
                const SizedBox(width: SurgeSpace.s + SurgeSpace.xxs),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      member.title,
                      const SizedBox(height: SurgeSpace.xxs),
                      Row(
                        children: [
                          Expanded(child: member.subline),
                          if (member.pinned) ...[
                            const SizedBox(width: SurgeSpace.xs),
                            const ProxyPinMark(),
                          ],
                          member.delay,
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown in an automatic group whose choice was fixed by hand: one tap
/// hands the choice back to the latency test.
class ProxyAutoNotice extends StatelessWidget {
  const ProxyAutoNotice({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    final fixed = proxyGroupPinned(group);
    final radius = BorderRadius.circular(surge.radii.button);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProxyListMetrics.cardStart,
        ProxyListMetrics.rowPadding,
        ProxyListMetrics.cardEnd,
        SurgeSpace.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.pinnedManually,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.proxyCardSubtitle.copyWith(
                color: surge.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: SurgeSpace.s),
          Semantics(
            button: true,
            child: SurgePressable(
              onTap: fixed == null
                  ? null
                  : () => applyProxyGroupMemberTap(
                      group: group,
                      tappedName: fixed,
                    ),
              borderRadius: radius,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SurgeSpace.s + SurgeSpace.xxs,
                  vertical: SurgeSpace.xs,
                ),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: surge.primary.withValues(alpha: SurgeAlpha.a48),
                    width: ProxyListMetrics.chipBorder,
                  ),
                ),
                child: Text(
                  l10n.returnToAuto,
                  style: context.typography.badgeLabel.copyWith(
                    color: surge.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
