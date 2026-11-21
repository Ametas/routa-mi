import 'dart:math' as math;

import 'package:fl_clash/widgets/proxy_group_bits.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/widgets.dart';

/// Fixed extents of the proxies list (design 3.1 "RoutaMi Proxies"),
/// measured from the text styles at the current text scale so the
/// virtualized rows never clip their content.
class ProxyListMetrics {
  ProxyListMetrics._({
    required this.headerHeight,
    required this.rowHeight,
    required this.tileHeight,
    required this.noticeHeight,
  });

  factory ProxyListMetrics.of(BuildContext context) {
    final typography = context.typography;
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: 'Xg', style: style),
        textScaler: scaler,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final subtitle = line(typography.proxyCardSubtitle);
    final chip = line(typography.chartLabel) + 2 * chipBorder;
    final subline = math.max(subtitle, chip);
    final rowTitle = math.max(
      line(typography.selectedRowTitle),
      line(typography.compactRowTitle),
    );
    final delay = line(typography.technical) + 2 * SurgeSpace.xxs;
    const ringTile = ProxyGroupBits.tile + 2 * ringBorder;

    final headerContent = math.max(
      ProxyGroupBits.action,
      line(typography.cardTitle) + SurgeSpace.xxs + subline,
    );
    final rowContent = math.max(
      math.max(ringTile, delay),
      rowTitle + SurgeSpace.xxs + subline,
    );
    final tileContent = math.max(
      ringTile,
      rowTitle + SurgeSpace.xxs + math.max(subline, delay),
    );
    final notice = math.max(
      subtitle,
      line(typography.badgeLabel) + 2 * SurgeSpace.xs + 2 * chipBorder,
    );
    return ProxyListMetrics._(
      headerHeight: 2 * headerPadding + headerContent,
      rowHeight: 2 * rowPadding + rowContent + hairline,
      tileHeight: 2 * (rowPadding + tileBorder) + tileContent,
      noticeHeight: rowPadding + SurgeSpace.xs + notice,
    );
  }

  static const double headerPadding = SurgeSpace.m;
  static const double rowPadding = SurgeSpace.m - SurgeSpace.xxs;
  static const double cardStart = SurgeSpace.m + SurgeSpace.xxs;
  static const double cardEnd = SurgeSpace.m;
  static const double groupGap = SurgeSpace.m - SurgeSpace.xxs;
  static const double gridGap = SurgeSpace.s;
  static const double gridMinTile = 220;
  static const double chipBorder = 1;
  static const double ringBorder = 1.5;
  static const double tileBorder = 1;
  static const double hairline = 1;

  final double headerHeight;

  /// A node row of the phone list, its top divider included.
  final double rowHeight;

  /// A node card of the desktop grid, without the gap below it.
  final double tileHeight;
  final double noticeHeight;

  /// One grid row: a node card and the gap below it.
  double get gridRowHeight => tileHeight + gridGap;

  /// Node cards that fit side by side in a group card [width] wide.
  static int columnsFor(double width) {
    final inner = width - 2 * cardEnd;
    return math.max(1, ((inner + gridGap) / (gridMinTile + gridGap)).floor());
  }
}
