import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/text.dart';
import 'package:flutter/material.dart';

/// The icon tile of a node row: the flag or symbol its name starts with
/// (see [splitProxyNameIcon]), as large as the flags in other clients.
class ProxyNameIconTile extends StatelessWidget {
  const ProxyNameIconTile({super.key, required this.icon, this.size = rowSize});

  static const double rowSize = 36;
  static const double headerSize = 40;

  // The emoji fills a little over half of the tile.
  static const double _emojiScale = 0.56;

  final String? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final emoji = icon;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: surge.textSecondary.withValues(alpha: SurgeAlpha.a08),
        borderRadius: BorderRadius.circular(surge.radii.input),
      ),
      child: emoji == null
          ? Icon(
              SurgeIcons.target,
              size: SurgeIconSize.compact,
              color: surge.textSecondary,
            )
          : ProxyNameEmoji(emoji, size: size * _emojiScale),
    );
  }
}

/// One emoji fitted into a [size] square with the app's emoji font.
class ProxyNameEmoji extends StatelessWidget {
  const ProxyNameEmoji(this.emoji, {super.key, required this.size});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: FittedBox(
        child: EmojiText(
          emoji,
          maxLines: 1,
          style: context.typography.body.copyWith(
            color: SurgeTheme.of(context).textPrimary,
          ),
        ),
      ),
    );
  }
}
