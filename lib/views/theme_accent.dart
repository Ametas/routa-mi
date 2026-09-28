import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/theme/app_color_source.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Accent swatches for [AppColorSource.accent]: tap to select, "+" to add a
/// colour from the palette, long press on an added colour to remove it.
class ThemeAccentPicker extends ConsumerWidget {
  const ThemeAccentPicker({super.key});

  static const double _swatchSize = 40;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final color = await globalState.showCommonDialog<int>(
      child: const _AccentPaletteDialog(),
    );
    if (color == null) {
      return;
    }
    ref
        .read(themeSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            dynamicColor: false,
            primaryColor: color,
            primaryColors: state.primaryColors.contains(color)
                ? state.primaryColors
                : [...state.primaryColors, color],
          ),
        );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, int color) async {
    final appLocalizations = context.appLocalizations;
    final confirmed = await globalState.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.colorSchemes),
      ),
    );
    if (confirmed != true) {
      return;
    }
    ref.read(themeSettingProvider.notifier).update((state) {
      final remaining = [...state.primaryColors]..remove(color);
      return state.copyWith(
        primaryColors: remaining,
        primaryColor: state.primaryColor == color
            ? defaultAccentColor
            : state.primaryColor,
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final theme = ref.watch(themeSettingProvider);
    final selected = theme.primaryColor;
    final palette = theme.accentPalette;
    final removable = defaultPrimaryColors.toSet()..add(defaultAccentColor);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final color in palette)
          _AccentSwatch(
            color: Color(color),
            size: _swatchSize,
            selected: color == selected,
            onTap: () => ref
                .read(themeSettingProvider.notifier)
                .update(
                  (state) =>
                      state.copyWith(dynamicColor: false, primaryColor: color),
                ),
            onLongPress: removable.contains(color)
                ? null
                : () => _remove(context, ref, color),
          ),
        SurgePressable(
          onTap: () => _add(context, ref),
          borderRadius: BorderRadius.circular(_swatchSize / 2),
          semanticLabel: context.appLocalizations.palette,
          child: Container(
            width: _swatchSize,
            height: _swatchSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: surge.separator, width: 1.5),
            ),
            child: Icon(
              SurgeIcons.add,
              size: SurgeIconSize.regular,
              color: surge.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.size,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final Color color;
  final double size;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final onColor = SurgePalette.contentOn(color);
    return SurgePressable(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(size / 2),
      semanticLabel: color.hex,
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
            ? Icon(
                SurgeIcons.confirm,
                size: SurgeIconSize.regular,
                color: onColor,
              )
            : null,
      ),
    );
  }
}

class _AccentPaletteDialog extends StatefulWidget {
  const _AccentPaletteDialog();

  @override
  State<_AccentPaletteDialog> createState() => _AccentPaletteDialogState();
}

class _AccentPaletteDialogState extends State<_AccentPaletteDialog> {
  final _controller = ValueNotifier<ui.Color>(const Color(defaultAccentColor));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.palette,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: SurgeSpace.s),
          SizedBox(
            width: 250,
            height: 250,
            child: Palette(controller: _controller),
          ),
          const SizedBox(height: SurgeSpace.l),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (_, color, _) => Text(
              color.hex,
              style: context.typography.technical.copyWith(
                color: SurgeTheme.of(context).textPrimary,
              ),
            ),
          ),
          const SizedBox(height: SurgeSpace.xl),
          SurgeDialogActionRow(
            cancelLabel: appLocalizations.cancel,
            submitLabel: appLocalizations.confirm,
            onCancel: () => Navigator.of(context).pop(),
            onSubmit: () =>
                Navigator.of(context).pop(_controller.value.toARGB32()),
          ),
        ],
      ),
    );
  }
}
