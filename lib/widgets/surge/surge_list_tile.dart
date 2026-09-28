import 'package:fl_clash/common/icons.dart';
import 'package:fl_clash/widgets/surge/surge_tokens.dart';
import 'package:flutter/material.dart';

import 'surge_pressable.dart';
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
    final minHeight = dense ? 52.0 : 64.0;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return SurgePressable(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      scaleFeedback: false,
      overlayInsets: EdgeInsets.symmetric(vertical: surge.spacing.hairline),
      overlayBaseColor: surge.card,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: SurgeSpace.l),
              child: Row(
                children: [
                  if (leading != null) ...[
                    IconTheme.merge(
                      data: IconThemeData(
                        color: destructive ? surge.red : surge.primary,
                        size: 21,
                      ),
                      child: leading!,
                    ),
                    const SizedBox(width: SurgeSpace.m),
                  ],
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: SurgeSpace.l),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: hasSubtitle ? SurgeSpace.s : 0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        (titleTextStyle ??
                                                context.typography.rowTitle)
                                            .copyWith(color: titleColor),
                                  ),
                                  if (hasSubtitle) ...[
                                    const SizedBox(height: SurgeSpace.xs),
                                    Text(
                                      subtitle!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          (subtitleTextStyle ??
                                          context.typography.supporting),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(width: SurgeSpace.m),
                            trailing!,
                          ],
                          if (showChevron) ...[
                            const SizedBox(width: SurgeSpace.s),
                            Icon(
                              SurgeIcons.chevronRight,
                              color: surge.textSecondary.withValues(
                                alpha: SurgeAlpha.a72,
                              ),
                              size: SurgeIconSize.navigation,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showDivider)
              Positioned(
                left: leading == null ? 16 : 49,
                right: 0,
                bottom: 0,
                child: Divider(
                  height: 0,
                  thickness: surge.spacing.hairline,
                  color: surge.separator,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
