import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

/// Every group of the profile as a list dropping from the group panel's
/// header (design artifact "RoutaMi for Windows"); picking a group returns
/// its name. A tap beside it or Escape closes it.
class HomeGroupsPopoverRoute extends PopupRoute<String> {
  HomeGroupsPopoverRoute({
    required this.anchor,
    required this.groups,
    required this.shown,
    required this.rowBuilder,
  });

  /// The panel header in the navigator's coordinates; the list hangs below
  /// it, as wide as the panel.
  final Rect anchor;
  final List<Group> groups;
  final String shown;

  /// One group's row; [picked] marks the shown one, [onTap] picks it.
  final Widget Function(
    BuildContext context,
    Group group, {
    required bool picked,
    required bool showDivider,
    required VoidCallback onTap,
  })
  rowBuilder;

  /// Taller lists scroll inside.
  static const double maxHeight = 380;
  static const double radius = 18;

  /// How far the list drops in from, under the header.
  static const double drop = 6;
  static const double startScale = 0.98;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Close';

  @override
  Color? get barrierColor => null;

  @override
  Duration get transitionDuration => SurgeMotion.menu;

  @override
  Duration get reverseTransitionDuration => SurgeMotion.fade;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final screen = MediaQuery.sizeOf(context);
    final top = anchor.bottom + SurgeSpace.xs;
    final room = screen.height - top - SurgeSpace.l;
    return CustomSingleChildLayout(
      delegate: _BelowAnchor(
        anchor: anchor,
        top: top,
        maxHeight: math.max(0, math.min(maxHeight, room)),
      ),
      child: _GroupsList(route: this),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: SurgeMotion.enterCurve,
      reverseCurve: SurgeMotion.exitCurve,
    );
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -drop * (1 - curved.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}

class _BelowAnchor extends SingleChildLayoutDelegate {
  _BelowAnchor({
    required this.anchor,
    required this.top,
    required this.maxHeight,
  });

  final Rect anchor;
  final double top;
  final double maxHeight;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: anchor.width,
        maxWidth: anchor.width,
        maxHeight: maxHeight,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset(anchor.left, top);

  @override
  bool shouldRelayout(_BelowAnchor old) =>
      old.anchor != anchor || old.top != top || old.maxHeight != maxHeight;
}

class _GroupsList extends StatefulWidget {
  const _GroupsList({required this.route});

  final HomeGroupsPopoverRoute route;

  @override
  State<_GroupsList> createState() => _GroupsListState();
}

class _GroupsListState extends State<_GroupsList> {
  late String _picked = widget.route.shown;

  void _pick(String name) {
    setState(() => _picked = name);
    // Let the check land before the list closes.
    Timer(SurgeMotion.press, () {
      if (mounted) Navigator.of(context).pop(name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final groups = widget.route.groups;
    return ScaleTransition(
      scale: Tween(
        begin: HomeGroupsPopoverRoute.startScale,
        end: 1.0,
      ).animate(widget.route.animation!),
      alignment: Alignment.topCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HomeGroupsPopoverRoute.radius),
          boxShadow: SurgeShadows.raised(surge),
        ),
        child: Material(
          color: surge.elevatedCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HomeGroupsPopoverRoute.radius),
            side: BorderSide(
              color: surge.separator,
              width: surge.spacing.hairline,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(
              horizontal: SurgeSpace.m,
              vertical: SurgeSpace.xs,
            ),
            itemCount: groups.length,
            itemBuilder: (context, index) => widget.route.rowBuilder(
              context,
              groups[index],
              picked: groups[index].name == _picked,
              showDivider: index > 0,
              onTap: () => _pick(groups[index].name),
            ),
          ),
        ),
      ),
    );
  }
}
