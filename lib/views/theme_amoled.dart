import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/theme/amoled_theme.dart';
import 'package:fl_clash/theme/app_color_source.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The AMOLED switch of the theme page and, for the curated palettes, its
/// accent. Turning it on in light mode moves the app to dark mode, where
/// AMOLED shows.
class ThemeAmoledItem extends ConsumerWidget {
  const ThemeAmoledItem({super.key});

  static const double _swatchSize = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    final theme = ref.watch(themeSettingProvider);
    final notifier = ref.read(themeSettingProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListItem.switchItem(
          title: Text(
            l10n.amoledMode,
            style: context.typography.body.copyWith(color: surge.textPrimary),
          ),
          subtitle: Text(
            l10n.amoledModeDesc,
            style: context.typography.supporting.copyWith(
              color: surge.textSecondary,
            ),
          ),
          delegate: SwitchDelegate(
            value: theme.pureBlack,
            onChanged: (value) => notifier.update(
              (state) => state.copyWith(
                pureBlack: value,
                themeMode: value && state.themeMode == ThemeMode.light
                    ? ThemeMode.dark
                    : state.themeMode,
              ),
            ),
          ),
        ),
        // Material You and own accents keep their colour on black.
        if (theme.pureBlack && theme.colorSource == AppColorSource.preset)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SurgeSpace.l,
              SurgeSpace.xs,
              SurgeSpace.l,
              SurgeSpace.m,
            ),
            child: Wrap(
              spacing: SurgeSpace.m,
              runSpacing: SurgeSpace.m,
              children: [
                for (final accent in AmoledAccent.values)
                  _AmoledSwatch(
                    color: AmoledTheme.accent(accent),
                    label: amoledAccentLabel(l10n, accent),
                    size: _swatchSize,
                    selected: theme.amoledAccent == accent,
                    onTap: () => notifier.update(
                      (state) => state.copyWith(amoledAccent: accent),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

String amoledAccentLabel(AppLocalizations l10n, AmoledAccent accent) =>
    switch (accent) {
      AmoledAccent.violet => l10n.amoledAccentViolet,
      AmoledAccent.cyan => l10n.amoledAccentCyan,
      AmoledAccent.lime => l10n.amoledAccentLime,
      AmoledAccent.rose => l10n.amoledAccentRose,
    };

class _AmoledSwatch extends StatelessWidget {
  const _AmoledSwatch({
    required this.color,
    required this.label,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SurgePressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        semanticLabel: label,
        child: AnimatedContainer(
          duration: SurgeMotion.state,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? surge.textPrimary : Colors.transparent,
              width: 2,
            ),
          ),
          child: selected
              ? const Icon(
                  SurgeIcons.confirm,
                  size: SurgeIconSize.regular,
                  color: AmoledTheme.black,
                )
              : null,
        ),
      ),
    );
  }
}
