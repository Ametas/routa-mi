import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widgets/surge_dashboard_hero.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Panels of the design 3.1 home screen (the "RoutaMi AMOLED" artifact):
/// brand bar, network panel and the current group's nodes.
abstract final class HomePanelLayout {
  static const double brandMark = 28;
  static const double panelRadius = 22;
  static const double sparkHeight = 56;
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
