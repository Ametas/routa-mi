import 'package:fl_clash/common/icons.dart';
import 'package:fl_clash/widgets/surge/surge_tokens.dart';
import 'package:flutter/material.dart';

import 'surge_motion.dart';
import 'surge_pressable.dart';
import 'surge_theme_extension.dart';

@immutable
class SurgeSegmentedItem<T> {
  const SurgeSegmentedItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// The one segmented switch: equal segments on a filled stadium track and
/// a raised indicator that slides to the selected one.
///
/// The selected label turns primary-text and semibold, its icon takes the
/// accent colour; the rest stay secondary.
class SurgeSegmentedControl<T> extends StatelessWidget {
  const SurgeSegmentedControl({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.height,
    this.padding = const EdgeInsets.all(SurgeSpace.xs),
  });

  final T value;
  final List<SurgeSegmentedItem<T>> items;
  final ValueChanged<T> onChanged;

  /// Outer height including [padding]; defaults to the segmented control
  /// token.
  final double? height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final radius = BorderRadius.circular(surge.radii.button);
    final selectedIndex = items
        .indexWhere((item) => item.value == value)
        .clamp(0, items.length - 1);
    return Container(
      height: height ?? surge.controls.segmentedHeight,
      padding: padding,
      decoration: BoxDecoration(color: surge.fill, borderRadius: radius),
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
                    borderRadius: radius,
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items)
                    Expanded(
                      child: _SurgeSegment<T>(
                        item: item,
                        selected: item.value == value,
                        onChanged: onChanged,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SurgeSegment<T> extends StatelessWidget {
  const _SurgeSegment({
    required this.item,
    required this.selected,
    required this.onChanged,
  });

  final SurgeSegmentedItem<T> item;
  final bool selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final typography = context.typography;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SurgePressable(
        onTap: () => onChanged(item.value),
        scaleFeedback: false,
        borderRadius: BorderRadius.circular(surge.radii.button),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SurgeSpace.s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: SurgeIconSize.compact,
                  color: selected ? surge.primary : surge.textSecondary,
                ),
                const SizedBox(width: SurgeSpace.s),
              ],
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: SurgeMotion.state,
                  curve: SurgeMotion.stateCurve,
                  style:
                      (selected
                              ? typography.selectedModeTabLabel
                              : typography.modeTabLabel)
                          .copyWith(
                            color: selected
                                ? surge.textPrimary
                                : surge.textSecondary,
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
