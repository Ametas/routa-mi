import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

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
    return Semantics(
      selected: selected,
      child: SurgeListTile(
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
      ),
    );
  }
}
