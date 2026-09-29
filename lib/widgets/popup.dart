import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/widgets/surge/surge_tokens.dart';
import 'package:flutter/material.dart';

import 'animated_cross_slide.dart';
import 'surge/surge_card.dart';
import 'surge/surge_icon_tile.dart';
import 'surge/surge_motion.dart';
import 'surge/surge_theme_extension.dart';

class CommonPopupRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  ValueNotifier<Offset> offsetNotifier;
  final bool belowTarget;

  CommonPopupRoute({
    required this.barrierLabel,
    required this.builder,
    required this.offsetNotifier,
    this.belowTarget = false,
  });

  @override
  String? barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final align = belowTarget ? Alignment.topLeft : Alignment.topRight;
    final curveAnimation = CurvedAnimation(
      parent: animation,
      curve: SurgeMotion.enterCurve,
      reverseCurve: SurgeMotion.exitCurve,
    );
    final positioned = ValueListenableBuilder(
      valueListenable: offsetNotifier,
      builder: (_, value, child) {
        return Align(
          alignment: align,
          child: CustomSingleChildLayout(
            delegate: OverflowAwareLayoutDelegate(
              offset: belowTarget ? value : value.translate(48, -8),
              alignToLeft: belowTarget,
            ),
            child: child,
          ),
        );
      },
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, child) {
          return FadeTransition(
            opacity: curveAnimation,
            child: ScaleTransition(
              alignment: align,
              scale: curveAnimation.drive(Tween(begin: 0.88, end: 1.0)),
              child: SlideTransition(
                position: curveAnimation.drive(
                  Tween(begin: const Offset(0, -0.035), end: Offset.zero),
                ),
                child: child,
              ),
            ),
          );
        },
        child: builder(context),
      ),
    );
    return belowTarget ? positioned : SafeArea(child: positioned);
  }

  @override
  Duration get transitionDuration => SurgeMotion.container;

  @override
  Duration get reverseTransitionDuration => SurgeMotion.state;
}

typedef PopupOpen = Function({Offset offset});

class CommonPopupBox extends StatefulWidget {
  final Widget Function(PopupOpen open) targetBuilder;
  final Widget popup;
  final bool belowTarget;

  const CommonPopupBox({
    super.key,
    required this.targetBuilder,
    required this.popup,
    this.belowTarget = false,
  });

  @override
  State<CommonPopupBox> createState() => _CommonPopupBoxState();
}

class _CommonPopupBoxState extends State<CommonPopupBox> {
  bool _isOpen = false;
  final _targetOffsetValueNotifier = ValueNotifier<Offset>(Offset.zero);
  Offset _offset = Offset.zero;

  void _open({Offset offset = Offset.zero}) {
    _offset = offset;
    _updateOffset();
    _isOpen = true;
    Navigator.of(context)
        .push(
          CommonPopupRoute(
            barrierLabel: utils.id,
            builder: (BuildContext context) {
              return widget.popup;
            },
            offsetNotifier: _targetOffsetValueNotifier,
            belowTarget: widget.belowTarget,
          ),
        )
        .then((_) {
          _isOpen = false;
        });
  }

  void _updateOffset() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final viewPadding = MediaQuery.viewPaddingOf(context);
    if (widget.belowTarget) {
      final bottomLeft = renderBox.localToGlobal(
        Offset(0, renderBox.size.height),
      );
      _targetOffsetValueNotifier.value = Offset(
        bottomLeft.dx + _offset.dx,
        bottomLeft.dy + _offset.dy,
      );
    } else {
      _targetOffsetValueNotifier.value = renderBox
          .localToGlobal(
            Offset.zero.translate(viewPadding.right, viewPadding.top),
          )
          .translate(_offset.dx, _offset.dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isOpen) {
            _updateOffset();
          }
        });
        return widget.targetBuilder(_open);
      },
    );
  }
}

class OverflowAwareLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset offset;
  final bool alignToLeft;

  OverflowAwareLayoutDelegate({required this.offset, this.alignToLeft = false});

  @override
  Size getSize(BoxConstraints constraints) {
    return Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const safeOffset = Offset(16, 16);
    final double x = (alignToLeft ? offset.dx : offset.dx - childSize.width)
        .clamp(0, size.width - safeOffset.dx - childSize.width);
    final double y = (offset.dy).clamp(
      0,
      size.height - safeOffset.dy - childSize.height,
    );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant OverflowAwareLayoutDelegate oldDelegate) {
    return oldDelegate.offset != offset ||
        oldDelegate.alignToLeft != alignToLeft;
  }
}

class CommonPopupMenu extends StatelessWidget {
  final List<PopupMenuItemData> items;
  final double minWidth;
  final double minItemVerticalPadding;

  const CommonPopupMenu({
    super.key,
    required this.items,
    this.minWidth = 0,
    this.minItemVerticalPadding = SurgeSpace.s,
  });

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeCard(
      shadow: true,
      padding: const EdgeInsets.symmetric(vertical: SurgeSpace.s),
      borderRadius: surge.radii.smallCard,
      border: Border.all(
        color: surge.separator.withValues(alpha: SurgeAlpha.a72),
        width: 0.5,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: IntrinsicWidth(
          child: _CommonPopupMenuItems(
            items: items,
            minWidth: minWidth,
            minItemVerticalPadding: minItemVerticalPadding,
          ),
        ),
      ),
    );
  }
}

class _CommonPopupMenuItems extends StatefulWidget {
  final List<PopupMenuItemData> items;
  final double minWidth;
  final double minItemVerticalPadding;

  const _CommonPopupMenuItems({
    required this.items,
    required this.minWidth,
    required this.minItemVerticalPadding,
  });

  @override
  State<_CommonPopupMenuItems> createState() => _CommonPopupMenuItemsState();
}

class _CommonPopupMenuItemsState extends State<_CommonPopupMenuItems> {
  List<PopupMenuItemData> _nextItems = [];
  String? _subTitle;
  bool _status = false;

  Widget _popupMenuItem(
    BuildContext context, {
    required PopupMenuItemData item,
    required int index,
  }) {
    final onPressed = item.subItems.isNotEmpty
        ? () {
            _nextItems = item.subItems;
            _subTitle = item.label;
            setState(() {
              _status = true;
            });
          }
        : item.onPressed;
    final disabled = onPressed == null;
    final surge = SurgeTheme.of(context);
    final color = item.danger ? surge.red : surge.textPrimary;
    final labelColor = disabled
        ? color.withValues(alpha: SurgeAlpha.a24)
        : item.danger
        ? color.withValues(alpha: SurgeAlpha.a92)
        : color;
    final iconAlpha = disabled
        ? SurgeAlpha.a24
        : item.danger
        ? SurgeAlpha.a92
        : SurgeAlpha.a72;
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: LinearBorder.none,
        foregroundColor: labelColor,
        overlayColor: labelColor.withValues(alpha: SurgeAlpha.a08),
      ),
      onPressed: onPressed != null
          ? () {
              if (item.subItems.isEmpty) {
                Navigator.of(context).pop();
              }
              onPressed();
            }
          : null,
      child: Container(
        constraints: BoxConstraints(minWidth: widget.minWidth),
        padding: EdgeInsets.symmetric(
          horizontal: SurgeSpace.m,
          vertical: widget.minItemVerticalPadding,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            if (item.icon != null) ...[
              SurgeIconTile(
                icon: item.icon!,
                color: color,
                shape: SurgeIconTileShape.circle,
                backgroundAlpha: item.danger ? SurgeAlpha.a08 : SurgeAlpha.a04,
                foregroundAlpha: iconAlpha,
              ),
              const SizedBox(width: SurgeSpace.m),
            ],
            Flexible(
              child: Text(
                item.label,
                style: context.typography.controlLabel.copyWith(
                  color: labelColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItems(List<PopupMenuItemData> items) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items.asMap().entries)
          _popupMenuItem(context, item: item.value, index: item.key),
      ],
    );
  }

  Widget _buildSubMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: SurgeSpace.s,
            top: SurgeSpace.s,
            bottom: SurgeSpace.xxs,
          ),
          child: Row(
            spacing: 4,
            children: [
              IconButton(
                icon: Icon(
                  SurgeIcons.back,
                  color: context.colorScheme.onSurfaceVariant.withValues(
                    alpha: SurgeAlpha.a82,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _status = false;
                  });
                },
                iconSize: SurgeIconSize.compact,
                style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: WidgetStatePropertyAll(Size.zero),
                  padding: WidgetStatePropertyAll(EdgeInsets.all(SurgeSpace.s)),
                ),
              ),
              if (_subTitle != null)
                Text(
                  _subTitle!,
                  style: context.typography.supporting.copyWith(
                    color: context.colorScheme.onSurfaceVariant.withValues(
                      alpha: SurgeAlpha.a82,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _CommonPopupMenuItems(
          items: _nextItems,
          minWidth: widget.minWidth,
          minItemVerticalPadding: widget.minItemVerticalPadding,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossSlide(
      secondCurve: Curves.easeOut,
      firstChild: _buildItems(widget.items),
      secondChild: _nextItems.isEmpty ? Container() : _buildSubMenu(),
      crossSlideState: _status
          ? CrossSlideState.showSecond
          : CrossSlideState.showFirst,
      duration: SurgeMotion.menu,
    );
  }
}
