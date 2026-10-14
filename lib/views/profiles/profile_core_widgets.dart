import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/profile_core.dart';
import 'package:fl_clash/theme/typography/type_scale.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

/// Badge of the core a profile runs on.
class ProfileCoreTag extends StatelessWidget {
  const ProfileCoreTag({super.key, required this.core});

  final ProfileCore core;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeTag(
      label: core.label,
      color: core == ProfileCore.xray ? surge.purple : null,
      minWidth: 48,
      maxWidth: 72,
    );
  }
}

/// Inline core mark next to the subscription type in profile rows.
class ProfileCoreMark extends StatelessWidget {
  const ProfileCoreMark({super.key, required this.core});

  final ProfileCore core;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final color = core == ProfileCore.xray ? surge.purple : surge.textSecondary;
    // The row aligns on the baseline, so no nudge like the type label's.
    return Text(
      core.label.toUpperCase(),
      maxLines: 1,
      textScaler: TextScaler.noScaling,
      style: SlclashTypeScale.profileTypeLabel.copyWith(
        color: color.withValues(alpha: SurgeAlpha.a92),
      ),
    );
  }
}

/// mihomo / Xray switch of the add-profile sheet. The server picks the
/// subscription format by it; JSON content switches to Xray regardless.
class ProfileCoreField extends StatelessWidget {
  const ProfileCoreField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ProfileCore value;
  final ValueChanged<ProfileCore> onChanged;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SurgeField(
      label: appLocalizations.core,
      helperText: appLocalizations.profileCoreDesc,
      child: SurgeSegmentedControl<ProfileCore>(
        value: value,
        onChanged: onChanged,
        items: [
          for (final core in ProfileCore.values)
            SurgeSegmentedItem(value: core, label: core.label),
        ],
      ),
    );
  }
}
