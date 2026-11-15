import 'package:fl_clash/common/icons.dart';
import 'package:flutter/material.dart';

import 'surge_motion.dart';
import 'surge_pressable.dart';
import 'surge_theme_extension.dart';
import 'surge_tokens.dart';

/// Desktop navigation of design system 3.0: a 72 dp rail for windows from
/// 600 to 1023 dp wide and a 240 dp side menu from 1024 dp. Narrower windows
/// use the floating [SurgeBottomNav] island, like the phone.
abstract final class SurgeSideNavLayout {
  static const double railWidth = 72;
  static const double railItemHeight = 56;
  static const double railIndicatorWidth = 56;
  static const double railIndicatorHeight = 32;
  static const double menuWidth = 240;
  static const double menuItemHeight = 40;
  static const double brandMark = 32;
}

@immutable
class SurgeSideNavItem {
  const SurgeSideNavItem({
    required this.icon,
    required this.iconOutlined,
    required this.label,
    this.group,
  });

  final IconData icon;
  final IconData iconOutlined;
  final String label;

  /// A heading shown above this item in the side menu (not on the rail).
  final String? group;
}

class SurgeNavRail extends StatelessWidget {
  const SurgeNavRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.leading,
  });

  final List<SurgeSideNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SizedBox(
      width: SurgeSideNavLayout.railWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surge.navBar,
          border: Border(
            right: BorderSide(
              color: surge.separator,
              width: surge.spacing.hairline,
            ),
          ),
        ),
        child: SafeArea(
          right: false,
          child: Column(
            children: [
              const SizedBox(height: SurgeSpace.l),
              ?leading,
              const SizedBox(height: SurgeSpace.m),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var index = 0; index < items.length; index++)
                        _RailItem(
                          item: items[index],
                          selected: index == currentIndex,
                          onTap: () => onTap(index),
                        ),
                    ],
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

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SurgeSideNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final color = selected ? surge.primary : surge.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: SurgePressable(
        onTap: onTap,
        child: SizedBox(
          height: SurgeSideNavLayout.railItemHeight + SurgeSpace.s,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: SurgeMotion.container,
                curve: SurgeMotion.stateCurve,
                width: SurgeSideNavLayout.railIndicatorWidth,
                height: SurgeSideNavLayout.railIndicatorHeight,
                decoration: BoxDecoration(
                  color: selected
                      ? surge.primary.withValues(alpha: SurgeAlpha.a16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(surge.radii.button),
                ),
                child: Icon(
                  selected ? item.icon : item.iconOutlined,
                  color: color,
                  size: SurgeIconSize.navigation,
                ),
              ),
              const SizedBox(height: SurgeSpace.xs),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (selected
                            ? context.typography.selectedNavigationLabel
                            : context.typography.navigationLabel)
                        .copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SurgeSideMenu extends StatelessWidget {
  const SurgeSideMenu({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.header,
    this.footer,
  });

  final List<SurgeSideNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SizedBox(
      width: SurgeSideNavLayout.menuWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surge.navBar,
          border: Border(
            right: BorderSide(
              color: surge.separator,
              width: surge.spacing.hairline,
            ),
          ),
        ),
        child: SafeArea(
          right: false,
          child: Padding(
            padding: const EdgeInsets.all(SurgeSpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?header,
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < items.length; index++) ...[
                          if (items[index].group case final group?)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                SurgeSpace.m,
                                SurgeSpace.m,
                                SurgeSpace.m,
                                SurgeSpace.xs,
                              ),
                              child: Text(
                                group,
                                style: context.typography.supporting.copyWith(
                                  color: surge.textSecondary,
                                ),
                              ),
                            ),
                          _MenuItem(
                            item: items[index],
                            selected: index == currentIndex,
                            onTap: () => onTap(index),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                ?footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SurgeSideNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final color = selected ? surge.primary : surge.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: SurgeSpace.xxs),
      child: Semantics(
        button: true,
        selected: selected,
        child: SurgePressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: SurgeMotion.state,
            curve: SurgeMotion.stateCurve,
            height: SurgeSideNavLayout.menuItemHeight,
            padding: const EdgeInsets.symmetric(horizontal: SurgeSpace.m),
            decoration: BoxDecoration(
              color: selected ? surge.selectedFill : Colors.transparent,
              borderRadius: BorderRadius.circular(surge.radii.menuRow),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? item.icon : item.iconOutlined,
                  color: color,
                  size: SurgeIconSize.regular,
                ),
                const SizedBox(width: SurgeSpace.m),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (selected
                                ? context.typography.selectedRowTitle
                                : context.typography.rowTitle)
                            .copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
