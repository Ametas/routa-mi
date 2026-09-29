import 'package:collection/collection.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'input.dart';
import 'open_container.dart';
import 'scaffold.dart';
import 'sheet.dart';

class Delegate {
  const Delegate();
}

class RadioDelegate<T> extends Delegate {
  final T value;
  final void Function()? onTab;

  const RadioDelegate({required this.value, this.onTab});
}

class SwitchDelegate<T> extends Delegate {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SwitchDelegate({required this.value, this.onChanged});
}

class CheckboxDelegate<T> extends Delegate {
  final bool value;
  final ValueChanged<bool?>? onChanged;

  const CheckboxDelegate({this.value = false, this.onChanged});
}

class OpenDelegate<T> extends Delegate {
  final Widget widget;
  final double? maxWidth;
  final bool blur;
  final bool forceFull;
  final ValueChanged<T?>? onChanged;

  const OpenDelegate({
    required this.widget,
    this.maxWidth,
    this.blur = true,
    this.forceFull = true,
    this.onChanged,
  });
}

class OptionsDelegate<T> extends Delegate {
  final List<T> options;
  final String title;
  final T value;
  final String Function(T value) textBuilder;
  final Function(T? value) onChanged;

  const OptionsDelegate({
    required this.title,
    required this.options,
    required this.textBuilder,
    required this.value,
    required this.onChanged,
  });
}

class InputDelegate extends Delegate {
  final String title;
  final String value;
  final String? suffixText;
  final Function(String? value) onChanged;
  final FormFieldValidator<String>? validator;

  final String? resetValue;

  const InputDelegate({
    required this.title,
    required this.value,
    this.suffixText,
    required this.onChanged,
    this.resetValue,
    this.validator,
  });
}

class ListItem<T> extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final EdgeInsets padding;
  final ListTileTitleAlignment tileTitleAlignment;
  final bool? dense;
  final Widget? trailing;
  final Delegate delegate;
  final double? horizontalTitleGap;
  final TextStyle? titleTextStyle;
  final TextStyle? subtitleTextStyle;
  final double minVerticalPadding;
  final Color? color;
  final double? minTileHeight;
  final VisualDensity? visualDensity;
  final void Function()? onTap;

  const ListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: SurgeSpace.l),
    this.trailing,
    this.horizontalTitleGap,
    this.dense,
    this.onTap,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.color,
    this.minTileHeight,
    this.visualDensity,
    this.minVerticalPadding = 12,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : delegate = const Delegate();

  const ListItem.open({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: SurgeSpace.l),
    this.trailing,
    required OpenDelegate this.delegate,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.color,
    this.minTileHeight,
    this.visualDensity,
    this.minVerticalPadding = 12,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : onTap = null;

  const ListItem.options({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: SurgeSpace.l),
    this.trailing,
    required OptionsDelegate<T> this.delegate,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.color,
    this.minTileHeight,
    this.visualDensity,
    this.minVerticalPadding = 12,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : onTap = null;

  const ListItem.input({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: SurgeSpace.l),
    this.trailing,
    required InputDelegate this.delegate,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.color,
    this.minTileHeight,
    this.visualDensity,
    this.minVerticalPadding = 12,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : onTap = null;

  const ListItem.checkbox({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.only(
      left: SurgeSpace.l,
      right: SurgeSpace.s,
    ),
    required CheckboxDelegate<T> this.delegate,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.color,
    this.minTileHeight,
    this.visualDensity,
    this.minVerticalPadding = 12,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : trailing = null,
       onTap = null;

  const ListItem.switchItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.only(
      left: SurgeSpace.l,
      right: SurgeSpace.s,
    ),
    required SwitchDelegate<T> this.delegate,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.color,
    this.minTileHeight,
    this.visualDensity,
    this.minVerticalPadding = 12,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : trailing = null,
       onTap = null;

  const ListItem.radio({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(
      left: SurgeSpace.m,
      right: SurgeSpace.l,
    ),
    required RadioDelegate<T> this.delegate,
    this.horizontalTitleGap = 8,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.color,
    this.minTileHeight,
    this.visualDensity,
    this.minVerticalPadding = 12,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : leading = null,
       onTap = null;

  Widget _buildListTile({
    void Function()? onTap,
    Widget? trailing,
    Widget? leading,
  }) {
    return SurgeRow(
      key: key,
      dense: dense,
      visualDensity: visualDensity,
      backgroundColor: color,
      titleTextStyle: titleTextStyle,
      subtitleTextStyle: subtitleTextStyle,
      leading: leading ?? this.leading,
      horizontalTitleGap: horizontalTitleGap,
      title: title,
      minTileHeight: minTileHeight,
      minVerticalPadding: minVerticalPadding,
      subtitle: subtitle,
      titleAlignment: tileTitleAlignment,
      onTap: onTap,
      trailing: trailing ?? this.trailing,
      contentPadding: padding,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (delegate is OpenDelegate) {
      final openDelegate = delegate as OpenDelegate;
      final child = openDelegate.widget;
      final onChanged = openDelegate.onChanged;
      return OpenContainer<T>(
        // closedColor: context.colorScheme.surface,
        // openColor: context.colorScheme.surface,
        // closedElevation: 0,
        // openElevation: 0,
        closedBuilder: (context, action) {
          Future<void> openAction() async {
            final isMobile = globalState.container.read(isMobileViewProvider);
            if (!isMobile || kDebugMode) {
              final res = await showExtend(
                context,
                props: ExtendProps(
                  blur: openDelegate.blur,
                  maxWidth: openDelegate.maxWidth,
                  forceFull: openDelegate.forceFull,
                ),
                builder: (_) {
                  return child;
                },
              );
              if (onChanged != null) {
                onChanged(res);
              }
              return;
            }
            action();
          }

          return _buildListTile(onTap: openAction);
        },
        onClosed: onChanged,
        openBuilder: (_, action) {
          return child;
        },
      );
    }
    if (delegate is OptionsDelegate) {
      final optionsDelegate = delegate as OptionsDelegate<T>;
      return _buildListTile(
        onTap: () async {
          final value = await globalState.showCommonDialog<T>(
            child: OptionsDialog<T>(
              title: optionsDelegate.title,
              options: optionsDelegate.options,
              textBuilder: optionsDelegate.textBuilder,
              value: optionsDelegate.value,
            ),
          );
          optionsDelegate.onChanged(value);
        },
      );
    }
    if (delegate is InputDelegate) {
      final inputDelegate = delegate as InputDelegate;
      return _buildListTile(
        onTap: () async {
          final value = await globalState.showCommonDialog<String>(
            child: InputDialog(
              title: inputDelegate.title,
              value: inputDelegate.value,
              suffixText: inputDelegate.suffixText,
              resetValue: inputDelegate.resetValue,
              validator: inputDelegate.validator,
            ),
          );
          inputDelegate.onChanged(value);
        },
      );
    }
    if (delegate is CheckboxDelegate) {
      final checkboxDelegate = delegate as CheckboxDelegate;
      return _buildListTile(
        onTap: () {
          if (checkboxDelegate.onChanged != null) {
            checkboxDelegate.onChanged!(!checkboxDelegate.value);
          }
        },
        trailing: CommonCheckBox(
          value: checkboxDelegate.value,
          onChanged: checkboxDelegate.onChanged,
        ),
      );
    }
    if (delegate is SwitchDelegate) {
      final switchDelegate = delegate as SwitchDelegate;
      return _buildListTile(
        onTap: () {
          if (switchDelegate.onChanged != null) {
            switchDelegate.onChanged!(!switchDelegate.value);
          }
        },
        trailing: SurgeSwitch(
          value: switchDelegate.value,
          onChanged: switchDelegate.onChanged,
        ),
      );
    }
    if (delegate is RadioDelegate) {
      final radioDelegate = delegate as RadioDelegate<T>;
      return _buildListTile(
        onTap: radioDelegate.onTab,
        leading: Radio<T>(
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          value: radioDelegate.value,
          toggleable: true,
        ),
        trailing: trailing,
      );
    }

    return _buildListTile(onTap: onTap);
  }
}

class SurgeSwitch extends StatelessWidget {
  const SurgeSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final enabled = onChanged != null;
    final knobColor = !enabled
        ? surge.textSecondary.withValues(alpha: SurgeAlpha.a48)
        : value
        ? surge.semantic.state.onToggleActive
        : surge.elevatedCard;
    final trackColor = !enabled
        ? surge.textSecondary.withValues(alpha: SurgeAlpha.a12)
        : value
        ? surge.semantic.state.toggleActive
        : surge.fill;
    final knobAlign = value ? Alignment.centerRight : Alignment.centerLeft;

    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: SurgeMotion.reveal,
          curve: SurgeMotion.stateCurve,
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(SurgeSpace.xs),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: value
                  ? Colors.transparent
                  : surge.separator.withValues(alpha: SurgeAlpha.a82),
              width: 0.5,
            ),
          ),
          child: AnimatedAlign(
            duration: SurgeMotion.reveal,
            curve: SurgeMotion.stateCurve,
            alignment: knobAlign,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: knobColor,
                shape: BoxShape.circle,
                boxShadow: SurgeShadows.knob(surge),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ListHeader extends StatelessWidget {
  final String title;
  final String? subTitle;
  final List<Widget> actions;
  final EdgeInsets? padding;
  final double? space;

  const ListHeader({
    super.key,
    required this.title,
    this.subTitle,
    this.padding,
    List<Widget>? actions,
    this.space,
  }) : actions = actions ?? const [];

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final effectivePadding =
        padding ??
        const EdgeInsets.fromLTRB(
          SurgeSpace.xl,
          SurgeSpace.l,
          SurgeSpace.l,
          SurgeSpace.s,
        );
    return Padding(
      padding: effectivePadding,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  style: context.typography.sectionTitle.copyWith(
                    color: surge.textSecondary,
                  ),
                ),
                if (subTitle != null) ...[
                  const SizedBox(height: SurgeSpace.xxs),
                  Text(
                    subTitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.supporting.copyWith(
                      color: surge.textSecondary.withValues(
                        alpha: SurgeAlpha.a82,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: SurgeSpace.m),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [...genActions(actions, space: space)],
            ),
          ],
        ],
      ),
    );
  }
}

Widget generateSectionV3({
  String? title,
  required Iterable<Widget> items,
  List<Widget>? actions,
}) {
  final genItems = items.mapIndexed<Widget>((index, item) {
    final position = ItemPosition.get(index, items.length);
    if (position != ItemPosition.middle) {
      return ItemPositionProvider(position: position, child: item);
    }
    return item;
  });
  return Column(
    children: [
      if (items.isNotEmpty && title != null)
        ListHeader(title: title, actions: actions),
      Column(children: [...genItems]),
    ],
  );
}

Widget generateListView(List<Widget> items) {
  return Builder(
    builder: (context) {
      final surge = SurgeTheme.of(context);
      return ColoredBox(
        color: surge.background,
        child: ListView(
          padding: EdgeInsets.only(
            top: 12,
            bottom: 32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [SurgeSection(showDividers: true, children: items)],
        ),
      );
    },
  );
}

class DecorationListItem extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool? isSelected;
  final double? horizontalTitleGap;
  final EdgeInsetsGeometry? contentPadding;
  final VoidCallback? onPressed;
  final double? minVerticalPadding;
  final bool invalid;

  const DecorationListItem({
    super.key,
    this.contentPadding,
    required this.title,
    this.leading,
    this.trailing,
    this.subtitle,
    this.isSelected,
    this.onPressed,
    this.horizontalTitleGap,
    this.minVerticalPadding,
    this.invalid = false,
  });

  @override
  Widget build(BuildContext context) {
    final proxyDecorator =
        ProxyDecoratorProvider.of(context)?.isProxyDecorator ?? false;
    final position = ItemPositionProvider.of(context)?.position;
    final isStart = [
      ItemPosition.start,
      ItemPosition.startAndEnd,
    ].contains(position);
    final isEnd = [
      ItemPosition.end,
      ItemPosition.startAndEnd,
    ].contains(position);
    final borderRadius = BorderRadius.vertical(
      top: isStart ? const Radius.circular(24) : Radius.zero,
      bottom: isEnd ? const Radius.circular(24) : Radius.zero,
    );
    return _SurgeSelectableListTile(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      isSelected: isSelected,
      invalid: invalid,
      horizontalTitleGap: horizontalTitleGap,
      contentPadding:
          contentPadding ??
          const EdgeInsets.only(right: SurgeSpace.l, left: SurgeSpace.l),
      minVerticalPadding: minVerticalPadding ?? 6,
      minTileHeight: 54,
      borderRadius: borderRadius,
      showDivider: !invalid && proxyDecorator != true && !isEnd,
      onPressed: proxyDecorator ? null : onPressed,
    );
  }
}

class _SurgeSelectableListTile extends StatelessWidget {
  const _SurgeSelectableListTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.isSelected,
    this.invalid = false,
    this.horizontalTitleGap,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: SurgeSpace.l),
    this.minVerticalPadding = 6,
    this.minTileHeight = 54,
    this.borderRadius = BorderRadius.zero,
    this.showDivider = false,
    this.onPressed,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool? isSelected;
  final bool invalid;
  final double? horizontalTitleGap;
  final EdgeInsetsGeometry contentPadding;
  final double minVerticalPadding;
  final double minTileHeight;
  final BorderRadius borderRadius;
  final bool showDivider;
  final VoidCallback? onPressed;

  Color _backgroundColor(SurgeTheme surge) {
    if (invalid) {
      return surge.red.withValues(alpha: SurgeAlpha.a12);
    }
    if (isSelected == true) {
      return surge.selectedFill;
    }
    return surge.card;
  }

  BorderSide _borderSide(SurgeTheme surge) {
    if (invalid) {
      return BorderSide(
        color: surge.red.withValues(alpha: SurgeAlpha.a62),
        width: 0.7,
      );
    }
    if (isSelected == true) {
      return BorderSide(
        color: surge.primary.withValues(alpha: SurgeAlpha.a38),
        width: 0.7,
      );
    }
    return BorderSide.none;
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgePressable(
      onTap: onPressed,
      borderRadius: borderRadius,
      scaleFeedback: false,
      overlayInsets: EdgeInsets.symmetric(vertical: surge.spacing.hairline),
      overlayBaseColor: _backgroundColor(surge),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            color: _backgroundColor(surge),
            borderRadius: borderRadius,
            border: _borderSide(surge) == BorderSide.none
                ? null
                : Border.fromBorderSide(_borderSide(surge)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SurgeRow(
                title: title,
                subtitle: subtitle,
                leading: leading,
                trailing: trailing,
                horizontalTitleGap: horizontalTitleGap,
                contentPadding: contentPadding.resolve(
                  Directionality.of(context),
                ),
                minVerticalPadding: minVerticalPadding,
                minTileHeight: minTileHeight,
                titleAlignment: ListTileTitleAlignment.center,
              ),
              if (showDivider)
                const Divider(height: 0, indent: 14, endIndent: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class SelectedDecorationListItem extends StatelessWidget {
  final bool isSelected;
  final bool isEditing;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback onSelected;
  final VoidCallback onPressed;
  final double? horizontalTitleGap;
  final Widget? leading;
  final bool invalid;
  final double? minVerticalPadding;

  const SelectedDecorationListItem({
    super.key,
    required this.isSelected,
    required this.onSelected,
    this.horizontalTitleGap,
    this.isEditing = false,
    this.invalid = false,
    required this.title,
    required this.onPressed,
    this.minVerticalPadding,
    this.subtitle,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return DecorationListItem(
      title: title,
      minVerticalPadding: minVerticalPadding,
      contentPadding: const EdgeInsets.only(left: SurgeSpace.l, right: 0),
      isSelected: isSelected,
      invalid: invalid,
      leading: leading,
      horizontalTitleGap: horizontalTitleGap,
      onPressed: () {
        if (isEditing) {
          onSelected();
          return;
        }
        onPressed();
      },
      subtitle: subtitle,
      trailing: CommonCheckBox(
        value: isSelected,
        isCircle: true,
        onChanged: (_) {
          onSelected();
        },
      ),
    );
  }
}
