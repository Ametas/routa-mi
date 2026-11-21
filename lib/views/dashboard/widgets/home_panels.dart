import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widgets/surge_dashboard_hero.dart';
import 'package:fl_clash/views/proxies/common.dart' as proxy_common;
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Panels of the design 3.1 home screen (the "RoutaMi AMOLED" artifact):
/// brand bar, network panel and the current group's nodes.
abstract final class HomePanelLayout {
  static const double brandMark = 28;
  static const double panelRadius = 22;
  static const double sparkHeight = 56;
  static const double nodeIcon = 30;

  /// Nodes the group panel lists before "All nodes".
  static const int maxNodes = 5;
}

BoxDecoration _panelDecoration(SurgeTheme surge) => BoxDecoration(
  color: surge.card,
  borderRadius: BorderRadius.circular(HomePanelLayout.panelRadius),
  border: Border.all(color: surge.separator, width: surge.spacing.hairline),
);

/// The brand and the profile chip above the route card.
class HomeBrandBar extends StatelessWidget {
  const HomeBrandBar({super.key, this.showBrand = true});

  /// The desktop side menu already shows the brand.
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Row(
      children: [
        if (showBrand) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(surge.radii.compact),
            child: Image.asset(
              'assets/images/icon.png',
              width: HomePanelLayout.brandMark,
              height: HomePanelLayout.brandMark,
              semanticLabel: appName,
            ),
          ),
          const SizedBox(width: SurgeSpace.m),
          Text(
            appName,
            style: context.typography.rootAppBarTitle.copyWith(
              color: surge.textPrimary,
            ),
          ),
        ],
        const SizedBox(width: SurgeSpace.m),
        const Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: DashboardProfileChip(),
          ),
        ),
      ],
    );
  }
}

/// Live speeds and a sparkline of the download rate in the accent colour.
class HomeNetworkPanel extends ConsumerWidget {
  const HomeNetworkPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final traffics = ref.watch(trafficsProvider).list;
    return Container(
      padding: const EdgeInsets.all(SurgeSpace.m + SurgeSpace.xxs),
      decoration: _panelDecoration(surge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                context.appLocalizations.network,
                style: context.typography.cardTitle.copyWith(
                  color: surge.textPrimary,
                ),
              ),
              const Spacer(),
              ValueListenableBuilder<Traffic>(
                valueListenable: currentSpeedNotifier,
                builder: (context, speed, _) => Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '↑ ${speed.up.traffic.show}/s   ',
                        style: TextStyle(color: surge.textSecondary),
                      ),
                      TextSpan(
                        text: '↓ ${speed.down.traffic.show}/s',
                        style: TextStyle(color: surge.textPrimary),
                      ),
                    ],
                  ),
                  style: context.typography.technical,
                ),
              ),
            ],
          ),
          const SizedBox(height: SurgeSpace.s),
          SizedBox(
            height: HomePanelLayout.sparkHeight,
            child: CustomPaint(
              painter: _SparklinePainter(
                values: [for (final traffic in traffics) traffic.down],
                color: surge.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  /// Points kept on screen; older ones scroll off.
  static const int window = 40;

  final List<num> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final points = values.length > window
        ? values.sublist(values.length - window)
        : values;
    final series = [for (var i = points.length; i < window; i++) 0, ...points];
    final peak = math.max<num>(1, series.reduce(math.max));
    final top = size.height * 0.08;
    Offset at(int index) => Offset(
      index / (window - 1) * size.width,
      size.height - (series[index] / peak) * (size.height - top),
    );
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < window; i++) {
      final previous = at(i - 1), current = at(i);
      final midX = (previous.dx + current.dx) / 2;
      line.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: SurgeAlpha.a38),
            color.withValues(alpha: SurgeAlpha.none),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color || !listEquals(old.values, values);
}

/// The current group with its first nodes: icon, name, protocol, delay.
/// Tapping a node selects it; the header switches the group.
class HomeGroupPanel extends ConsumerWidget {
  const HomeGroupPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final selected = ref.watch(selectedProxyNameProvider(group.name)) ?? '';
    final nodes = [
      ...group.all.where((proxy) => proxy.name == selected),
      ...group.all.where((proxy) => proxy.name != selected),
    ].take(HomePanelLayout.maxNodes).toList();
    final nameIcons = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.nameIcons),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(
        SurgeSpace.m + SurgeSpace.xxs,
        SurgeSpace.m,
        SurgeSpace.m + SurgeSpace.xxs,
        SurgeSpace.xs,
      ),
      decoration: _panelDecoration(surge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SurgePressable(
            onTap: () => showDashboardGroupSheet(context, groups, group.name),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: EmojiText(
                          nameIcons
                              ? splitProxyNameIcon(group.name).title
                              : group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.cardTitle.copyWith(
                            color: surge.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: SurgeSpace.xs),
                      Icon(
                        SurgeIcons.expand,
                        size: SurgeIconSize.compact,
                        color: surge.textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SurgeSpace.s),
                Text(
                  group.type.name.toUpperCase(),
                  style: context.typography.badgeLabel.copyWith(
                    color: surge.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SurgeSpace.xs),
          for (final (index, node) in nodes.indexed)
            _HomeNodeRow(
              group: group,
              proxy: node,
              selected: node.name == selected,
              showDivider: index > 0,
              nameIcons: nameIcons,
            ),
          if (group.all.length > nodes.length)
            SurgePressable(
              onTap: () =>
                  showDashboardNodeSheet(context, ref, group.name, selected),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: SurgeSpace.m),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: surge.separator,
                      width: surge.spacing.hairline,
                    ),
                  ),
                ),
                child: Text(
                  context.appLocalizations.allNodesCount(group.all.length),
                  textAlign: TextAlign.center,
                  style: context.typography.controlLabel.copyWith(
                    color: surge.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeNodeRow extends ConsumerWidget {
  const _HomeNodeRow({
    required this.group,
    required this.proxy,
    required this.selected,
    required this.showDivider,
    required this.nameIcons,
  });

  final Group group;
  final Proxy proxy;
  final bool selected;
  final bool showDivider;
  final bool nameIcons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final parts = nameIcons
        ? splitProxyNameIcon(proxy.name)
        : ProxyNameParts(null, proxy.name);
    final delay = ref.watch(
      delayProvider(proxyName: proxy.name, testUrl: group.testUrl),
    );
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
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(surge.radii.input),
                border: Border.all(
                  color: selected ? surge.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: ProxyNameIconTile(
                icon: parts.icon,
                size: HomePanelLayout.nodeIcon,
              ),
            ),
            const SizedBox(width: SurgeSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EmojiText(
                    parts.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (selected
                                ? context.typography.selectedRowTitle
                                : context.typography.compactRowTitle)
                            .copyWith(
                              color: selected
                                  ? surge.primary
                                  : surge.textPrimary,
                            ),
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
            Text(
              delay == null
                  ? '—'
                  : delay < 0
                  ? context.appLocalizations.timeout
                  : '$delay ms',
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
