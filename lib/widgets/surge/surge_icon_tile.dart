import 'package:fl_clash/common/icons.dart';
import 'package:flutter/material.dart';

import 'surge_theme_extension.dart';
import 'surge_tokens.dart';

enum SurgeIconTileShape { rounded, circle }

/// An icon on a tinted tile, used as the leading mark of rows and cards.
class SurgeIconTile extends StatelessWidget {
  const SurgeIconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 30,
    this.iconSize = SurgeIconSize.inline,
    this.shape = SurgeIconTileShape.rounded,
    this.backgroundAlpha = SurgeAlpha.a08,
    this.foregroundAlpha = SurgeAlpha.a92,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final SurgeIconTileShape shape;
  final double backgroundAlpha;
  final double foregroundAlpha;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final radius = switch (shape) {
      SurgeIconTileShape.rounded => surge.radii.input,
      SurgeIconTileShape.circle => size / 2,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: color.withValues(alpha: foregroundAlpha),
      ),
    );
  }
}
