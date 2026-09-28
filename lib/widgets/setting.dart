import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

class SurgeSettingSection extends StatelessWidget {
  const SurgeSettingSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.margin,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Padding(
      padding:
          margin ??
          EdgeInsets.fromLTRB(
            surge.spacing.pagePadding,
            0,
            surge.spacing.pagePadding,
            14,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SurgeSpace.xs,
              0,
              SurgeSpace.xs,
              SurgeSpace.s,
            ),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 2,
                    style: context.typography.rowTitle.copyWith(
                      color: surge.textPrimary,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: SurgeSpace.s),
                  Flexible(
                    child: Text(
                      subtitle!,
                      maxLines: 2,
                      style: context.typography.supporting.copyWith(
                        color: surge.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SurgeCard(
            padding: EdgeInsets.zero,
            borderRadius: surge.radii.list,
            shadow: false,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class SurgeSettingOption extends StatelessWidget {
  const SurgeSettingOption({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected = false,
    this.showDivider = true,
    this.enabled = true,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final bool showDivider;
  final bool enabled;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurgeListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      onTap: onTap,
      showDivider: showDivider,
      dense: dense,
      trailing:
          trailing ??
          SurgeSelectIndicator(
            selected: selected,
            size: 20,
            iconSize: SurgeIconSize.micro,
            showCheck: false,
          ),
    );
  }
}
