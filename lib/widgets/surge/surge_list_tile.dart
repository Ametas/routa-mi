import 'package:fl_clash/common/icons.dart';
import 'package:fl_clash/widgets/surge/surge_tokens.dart';
import 'package:flutter/material.dart';

import 'surge_row.dart';
import 'surge_theme_extension.dart';

class SurgeListTile extends StatelessWidget {
  const SurgeListTile({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.showChevron = false,
    this.onTap,
    this.dense = false,
    this.showDivider = true,
    this.destructive = false,
    this.enabled = true,
    this.titleTextStyle,
    this.subtitleTextStyle,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;
  final bool dense;
  final bool showDivider;
  final bool destructive;
  final bool enabled;
  final TextStyle? titleTextStyle;
  final TextStyle? subtitleTextStyle;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final titleColor = !enabled
        ? surge.textSecondary.withValues(alpha: SurgeAlpha.a48)
        : destructive
        ? surge.red
        : surge.textPrimary;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    final chevron = Icon(
      SurgeIcons.chevronRight,
      color: surge.textSecondary.withValues(alpha: SurgeAlpha.a72),
      size: SurgeIconSize.navigation,
    );

    return Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        SurgeRow(
          onTap: onTap,
          enabled: enabled,
          minTileHeight: dense ? 52 : 64,
          contentPadding: const EdgeInsets.symmetric(horizontal: SurgeSpace.l),
          minVerticalPadding: hasSubtitle ? SurgeSpace.s : 0,
          titleAlignment: ListTileTitleAlignment.center,
          leading: leading,
          leadingColor: destructive ? surge.red : null,
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (titleTextStyle ?? context.typography.rowTitle).copyWith(
              color: titleColor,
            ),
          ),
          subtitle: hasSubtitle
              ? Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: subtitleTextStyle ?? context.typography.supporting,
                )
              : null,
          trailing: switch ((trailing, showChevron)) {
            (null, false) => null,
            (final Widget trailing, false) => trailing,
            (null, true) => chevron,
            (final Widget trailing, true) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                trailing,
                const SizedBox(width: SurgeSpace.s),
                chevron,
              ],
            ),
          },
        ),
        if (showDivider)
          Positioned(
            left: leading == null ? 16 : 49,
            right: 0,
            bottom: 0,
            child: Divider(height: 0, thickness: surge.spacing.hairline),
          ),
      ],
    );
  }
}
