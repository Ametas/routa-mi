// ignore_for_file: deprecated_member_use

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/theme/app_color_source.dart';
import 'package:fl_clash/theme/static_theme.dart';
import 'package:fl_clash/views/theme_accent.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeModeItem {
  final ThemeMode themeMode;
  final IconData iconData;
  final String label;

  const ThemeModeItem({
    required this.themeMode,
    required this.iconData,
    required this.label,
  });
}

class _SegmentedItem<T> {
  final T value;
  final IconData iconData;
  final String label;

  const _SegmentedItem({
    required this.value,
    required this.iconData,
    required this.label,
  });
}

class FontFamilyItem {
  final FontFamily fontFamily;
  final String label;

  const FontFamilyItem({required this.fontFamily, required this.label});
}

class ThemeView extends StatelessWidget {
  const ThemeView({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    return CommonScaffold(
      title: appLocalizations.theme,
      body: ColoredBox(
        color: surge.background,
        child: ListView(
          padding: EdgeInsets.only(
            top: 12,
            bottom: 32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: const [
            SurgeSection(
              showDividers: true,
              children: [
                _ThemeModeItem(),
                _DynamicColorItem(),
                _TextScaleFactorItem(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeItem extends ConsumerWidget {
  const _ThemeModeItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    final themeMode = ref.watch(
      themeSettingProvider.select((state) => state.themeMode),
    );
    final List<ThemeModeItem> themeModeItems = [
      ThemeModeItem(
        iconData: SurgeIcons.loading,
        label: appLocalizations.auto,
        themeMode: ThemeMode.system,
      ),
      ThemeModeItem(
        iconData: SurgeIcons.themeLight,
        label: appLocalizations.light,
        themeMode: ThemeMode.light,
      ),
      ThemeModeItem(
        iconData: SurgeIcons.themeDark,
        label: appLocalizations.dark,
        themeMode: ThemeMode.dark,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SurgeSpace.l,
        SurgeSpace.m,
        SurgeSpace.l,
        SurgeSpace.m,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appLocalizations.themeMode,
            style: _themePageTitleStyle(context, surge),
          ),
          const SizedBox(height: SurgeSpace.m),
          _SurgeThemeModeControl(
            value: themeMode,
            items: themeModeItems,
            onChanged: (value) {
              ref
                  .read(themeSettingProvider.notifier)
                  .update((state) => state.copyWith(themeMode: value));
            },
          ),
        ],
      ),
    );
  }
}

class _SurgeThemeModeControl extends StatelessWidget {
  const _SurgeThemeModeControl({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final ThemeMode value;
  final List<ThemeModeItem> items;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SurgeSegmentedControl<ThemeMode>(
      value: value,
      items: [
        for (final item in items)
          _SegmentedItem(
            value: item.themeMode,
            iconData: item.iconData,
            label: item.label,
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _SurgeSegmentedControl<T> extends StatelessWidget {
  const _SurgeSegmentedControl({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<_SegmentedItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final selectedIndex = items
        .indexWhere((item) => item.value == value)
        .clamp(0, items.length - 1);
    return Container(
      padding: const EdgeInsets.all(SurgeSpace.xs),
      decoration: BoxDecoration(
        color: surge.fill,
        borderRadius: BorderRadius.circular(surge.radii.list),
      ),
      child: SizedBox(
        height: 40,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / items.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: SurgeMotion.container,
                  curve: SurgeMotion.stateCurve,
                  left: itemWidth * selectedIndex,
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: surge.elevatedCard,
                      borderRadius: BorderRadius.circular(
                        surge.radii.segmentedIndicator,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final item in items)
                      Expanded(
                        child: _SurgeSegmentedButton<T>(
                          item: item,
                          selected: value == item.value,
                          onTap: () => onChanged(item.value),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SurgeSegmentedButton<T> extends StatelessWidget {
  const _SurgeSegmentedButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _SegmentedItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(surge.radii.segmentedIndicator),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: SurgeSpace.s),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.iconData,
                size: SurgeIconSize.compact,
                color: selected ? surge.primary : surge.textSecondary,
              ),
              const SizedBox(width: SurgeSpace.s),
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: SurgeMotion.state,
                  curve: SurgeMotion.stateCurve,
                  style: context.typography.controlLabel.copyWith(
                    color: selected ? surge.textPrimary : surge.textSecondary,
                  ),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Choice shown when Material You is off: a curated preset or own accent.
enum _StaticChoice { blueWhite, grayBlack, accent }

class _DynamicColorItem extends ConsumerWidget {
  const _DynamicColorItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final theme = ref.watch(themeSettingProvider);
    final dynamicColor = theme.dynamicColor;
    final colorSource = theme.colorSource;
    final staticChoice = colorSource == AppColorSource.accent
        ? _StaticChoice.accent
        : theme.staticPreset == StaticThemePreset.grayBlack
        ? _StaticChoice.grayBlack
        : _StaticChoice.blueWhite;
    final schemeVariant = normalizeDynamicSchemeVariant(theme.schemeVariant);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListItem.switchItem(
          title: Text(
            context.appLocalizations.dynamicColor,
            style: _themePageTitleStyle(context, surge),
          ),
          subtitle: Text(
            dynamicColor
                ? context.appLocalizations.followMaterialYou(
                    _schemeVariantLabel(context, schemeVariant),
                  )
                : switch (staticChoice) {
                    _StaticChoice.grayBlack =>
                      context.appLocalizations.darkMonochromeStyle,
                    _StaticChoice.blueWhite =>
                      context.appLocalizations.blueWhiteMonochromeStyle,
                    _StaticChoice.accent => context.appLocalizations.custom,
                  },
            style: context.typography.supporting.copyWith(
              color: surge.textSecondary,
            ),
          ),
          delegate: SwitchDelegate(
            value: dynamicColor,
            onChanged: (value) {
              ref
                  .read(themeSettingProvider.notifier)
                  .update(
                    (state) => state.copyWith(
                      dynamicColor: value,
                      primaryColor:
                          value && state.primaryColor == defaultPrimaryColor
                          ? null
                          : state.primaryColor,
                      schemeVariant: value
                          ? normalizeDynamicSchemeVariant(state.schemeVariant)
                          : state.schemeVariant,
                    ),
                  );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SurgeSpace.l,
            vertical: SurgeSpace.s,
          ),
          child: dynamicColor
              ? _SurgeSegmentedControl<DynamicSchemeVariant>(
                  value: schemeVariant,
                  items: [
                    _SegmentedItem(
                      value: DynamicSchemeVariant.monochrome,
                      iconData: SurgeIcons.contrast,
                      label: context.appLocalizations.monochrome,
                    ),
                    _SegmentedItem(
                      value: DynamicSchemeVariant.tonalSpot,
                      iconData: SurgeIcons.blur,
                      label: context.appLocalizations.tonal,
                    ),
                    _SegmentedItem(
                      value: DynamicSchemeVariant.content,
                      iconData: SurgeIcons.appearance,
                      label: context.appLocalizations.contentColor,
                    ),
                  ],
                  onChanged: (value) {
                    ref
                        .read(themeSettingProvider.notifier)
                        .update(
                          (state) => state.copyWith(
                            dynamicColor: true,
                            schemeVariant: value,
                          ),
                        );
                  },
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SurgeSegmentedControl<_StaticChoice>(
                      value: staticChoice,
                      items: [
                        _SegmentedItem(
                          value: _StaticChoice.blueWhite,
                          iconData: SurgeIcons.water,
                          label: context.appLocalizations.blueWhiteMonochrome,
                        ),
                        _SegmentedItem(
                          value: _StaticChoice.grayBlack,
                          iconData: SurgeIcons.contrast,
                          label: context.appLocalizations.darkMonochrome,
                        ),
                        _SegmentedItem(
                          value: _StaticChoice.accent,
                          iconData: SurgeIcons.colorize,
                          label: context.appLocalizations.custom,
                        ),
                      ],
                      onChanged: (value) {
                        ref
                            .read(themeSettingProvider.notifier)
                            .update(
                              (state) => switch (value) {
                                _StaticChoice.blueWhite => state.copyWith(
                                  dynamicColor: false,
                                  primaryColor: null,
                                ),
                                _StaticChoice.grayBlack => state.copyWith(
                                  dynamicColor: false,
                                  primaryColor: legacyGraySeedColor,
                                ),
                                _StaticChoice.accent => state.copyWith(
                                  dynamicColor: false,
                                  primaryColor:
                                      state.colorSource == AppColorSource.accent
                                      ? state.primaryColor
                                      : state.accentPalette.first,
                                ),
                              },
                            );
                      },
                    ),
                    if (staticChoice == _StaticChoice.accent) ...[
                      const SizedBox(height: SurgeSpace.l),
                      const ThemeAccentPicker(),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

String _schemeVariantLabel(
  BuildContext context,
  DynamicSchemeVariant schemeVariant,
) {
  return switch (schemeVariant) {
    DynamicSchemeVariant.monochrome => context.appLocalizations.monochrome,
    DynamicSchemeVariant.tonalSpot => context.appLocalizations.tonal,
    DynamicSchemeVariant.content => context.appLocalizations.contentColor,
    _ => context.appLocalizations.monochrome,
  };
}

class _TextScaleFactorItem extends ConsumerWidget {
  const _TextScaleFactorItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    final textScale = ref.watch(
      themeSettingProvider.select((state) => state.textScale),
    );
    final String process = '${(textScale.scale * 100).round()}%';
    return Column(
      children: [
        ListItem.switchItem(
          title: Text(
            appLocalizations.textScale,
            style: _themePageTitleStyle(context, surge),
          ),
          delegate: SwitchDelegate(
            value: textScale.enable,
            onChanged: (value) {
              ref
                  .read(themeSettingProvider.notifier)
                  .update((state) => state.copyWith.textScale(enable: value));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SurgeSpace.l,
            SurgeSpace.m,
            SurgeSpace.l,
            SurgeSpace.m,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            spacing: 32,
            children: [
              Expanded(
                child: DisabledMask(
                  status: !textScale.enable,
                  child: ActivateBox(
                    active: textScale.enable,
                    child: SliderTheme(
                      data: _SliderDefaultsM3(context),
                      child: Slider(
                        padding: EdgeInsets.zero,
                        min: minTextScale,
                        max: maxTextScale,
                        value: textScale.scale,
                        onChanged: (value) {
                          ref
                              .read(themeSettingProvider.notifier)
                              .update(
                                (state) =>
                                    state.copyWith.textScale(scale: value),
                              );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: SurgeSpace.xs),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 56),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SurgeSpace.m,
                    vertical: SurgeSpace.s,
                  ),
                  decoration: BoxDecoration(
                    color: surge.textSecondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(surge.radii.button),
                  ),
                  child: Text(
                    process,
                    style: context.typography.controlLabel.copyWith(
                      color: surge.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

TextStyle? _themePageTitleStyle(BuildContext context, SurgeTheme surge) {
  return context.typography.body.copyWith(color: surge.textPrimary);
}

class _SliderDefaultsM3 extends SliderThemeData {
  _SliderDefaultsM3(this.context) : super(trackHeight: 16.0);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color? get activeTrackColor => _colors.primary;

  @override
  Color? get inactiveTrackColor => _colors.secondaryContainer;

  @override
  Color? get secondaryActiveTrackColor => _colors.primary.withOpacity(0.54);

  @override
  Color? get disabledActiveTrackColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get disabledInactiveTrackColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get disabledSecondaryActiveTrackColor =>
      _colors.onSurface.withOpacity(0.38);

  @override
  Color? get activeTickMarkColor => _colors.onPrimary.withOpacity(1.0);

  @override
  Color? get inactiveTickMarkColor =>
      _colors.onSecondaryContainer.withOpacity(1.0);

  @override
  Color? get disabledActiveTickMarkColor => _colors.onInverseSurface;

  @override
  Color? get disabledInactiveTickMarkColor => _colors.onSurface;

  @override
  Color? get thumbColor => _colors.primary;

  @override
  Color? get disabledThumbColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get overlayColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.dragged)) {
          return _colors.primary.withOpacity(0.1);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.primary.withOpacity(0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.primary.withOpacity(0.1);
        }

        return Colors.transparent;
      });

  @override
  TextStyle? get valueIndicatorTextStyle => Theme.of(
    context,
  ).textTheme.labelLarge!.copyWith(color: _colors.onInverseSurface);

  @override
  Color? get valueIndicatorColor => _colors.inverseSurface;

  @override
  SliderComponentShape? get valueIndicatorShape =>
      const RoundedRectSliderValueIndicatorShape();

  @override
  SliderComponentShape? get thumbShape => const HandleThumbShape();

  @override
  SliderTrackShape? get trackShape => const GappedSliderTrackShape();

  @override
  SliderComponentShape? get overlayShape => const RoundSliderOverlayShape();

  @override
  SliderTickMarkShape? get tickMarkShape =>
      const RoundSliderTickMarkShape(tickMarkRadius: 4.0 / 2);

  @override
  WidgetStateProperty<Size?>? get thumbSize {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return const Size(4.0, 44.0);
      }
      if (states.contains(WidgetState.hovered)) {
        return const Size(4.0, 44.0);
      }
      if (states.contains(WidgetState.focused)) {
        return const Size(2.0, 44.0);
      }
      if (states.contains(WidgetState.pressed)) {
        return const Size(2.0, 44.0);
      }
      return const Size(4.0, 44.0);
    });
  }

  @override
  double? get trackGap => 6.0;
}
