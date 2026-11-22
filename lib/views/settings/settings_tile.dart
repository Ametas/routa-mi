import 'package:fl_clash/views/settings/settings_pane.dart';
import 'package:fl_clash/widgets/settings_unfold.dart';
import 'package:fl_clash/widgets/sheet.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shapes of the settings screen (design 3.1 "RoutaMi Settings Unfold").
abstract final class SettingsTileLayout {
  static const double tile = 36;
  static const double groupRadius = 22;
  static const double openRadius = 16;
  static const double ring = 1.5;
}

/// A row of the settings screen: icon tile, title over a summary and a
/// chevron. [open] (0 → 1) rings the tile and turns the chevron while the
/// row's options are unfolded.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.open,
    this.selected = false,
  });

  final Widget icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Animation<double>? open;

  /// The section a wide settings screen shows beside the list: tinted, its
  /// tile ringed.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final turn = this.open ?? kAlwaysDismissedAnimation;
    final open = selected ? kAlwaysCompleteAnimation : turn;
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SurgeSpace.m + SurgeSpace.xxs,
        vertical: SurgeSpace.m,
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: open,
            builder: (context, child) => Container(
              width: SettingsTileLayout.tile,
              height: SettingsTileLayout.tile,
              decoration: BoxDecoration(
                color: Color.lerp(
                  surge.fill,
                  surge.primary.withValues(alpha: SurgeAlpha.a16),
                  open.value,
                ),
                borderRadius: BorderRadius.circular(surge.radii.input),
                border: Border.all(
                  color: surge.primary.withValues(alpha: open.value),
                  width: SettingsTileLayout.ring,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
              child: child,
            ),
            child: IconTheme.merge(
              data: IconThemeData(
                size: SurgeIconSize.regular,
                color: surge.primary,
              ),
              child: icon,
            ),
          ),
          const SizedBox(width: SurgeSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.toolTileTitle.copyWith(
                    color: surge.textPrimary,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.toolTileSubtitle.copyWith(
                      color: surge.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: SurgeSpace.s),
          RotationTransition(
            turns: Tween<double>(begin: 0, end: 0.25).animate(turn),
            child: Icon(
              SurgeIcons.chevronRight,
              size: SurgeIconSize.regular,
              color: surge.textSecondary,
            ),
          ),
        ],
      ),
    );
    final tinted = AnimatedContainer(
      duration: SurgeMotion.state,
      color: selected
          ? surge.primary.withValues(alpha: SurgeAlpha.a08)
          : surge.primary.withValues(alpha: SurgeAlpha.none),
      child: row,
    );
    if (onTap == null) return tinted;
    return Semantics(
      button: true,
      selected: selected,
      child: SurgePressable(onTap: onTap, scaleFeedback: false, child: tinted),
    );
  }
}

/// A labelled card of settings rows with hairlines between them.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SurgeSpace.s,
            SurgeSpace.m,
            SurgeSpace.s,
            SurgeSpace.s,
          ),
          child: Text(
            label.toUpperCase(),
            style: context.typography.badgeLabel.copyWith(
              color: surge.textSecondary,
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: surge.card,
            borderRadius: BorderRadius.circular(SettingsTileLayout.groupRadius),
            border: Border.all(
              color: surge.separator,
              width: surge.spacing.hairline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0)
                  Divider(
                    height: surge.spacing.hairline,
                    thickness: surge.spacing.hairline,
                    color: surge.separator,
                  ),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A settings row that opens a page of its own.
class SettingsPageEntry extends StatelessWidget {
  const SettingsPageEntry({
    super.key,
    required this.icon,
    required this.title,
    required this.page,
    this.subtitle,
  });

  final Widget icon;
  final String title;
  final String? subtitle;
  final WidgetBuilder page;

  @override
  Widget build(BuildContext context) {
    final pane = SettingsPaneScope.maybeOf(context);
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      selected: pane?.selected == title,
      onTap: pane != null
          ? () => pane.onSelect(SettingsPaneSection(title: title, page: page))
          : () => showExtend(context, builder: page),
    );
  }
}

/// A settings row whose options unfold around it; its subtitle sums up
/// their current values.
class SettingsUnfoldEntry extends ConsumerWidget {
  const SettingsUnfoldEntry({
    super.key,
    required this.icon,
    required this.title,
    required this.options,
    this.fallbackSubtitle,
    this.page,
  });

  final Widget icon;
  final String title;
  final String? fallbackSubtitle;
  final UnfoldOptionsBuilder options;

  /// The section's full page; a wide settings screen shows it in its pane
  /// instead of unfolding the options.
  final WidgetBuilder? page;

  String _summary(BuildContext context, WidgetRef ref) {
    final summary = unfoldSummary(options(context, ref));
    return summary.isNotEmpty ? summary : fallbackSubtitle ?? '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = _summary(context, ref);
    final pane = SettingsPaneScope.maybeOf(context);
    final page = this.page;
    if (pane != null && page != null) {
      return SettingsTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        selected: pane.selected == title,
        onTap: () =>
            pane.onSelect(SettingsPaneSection(title: title, page: page)),
      );
    }
    return Builder(
      builder: (rowContext) => SettingsTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: () => showSettingsUnfold(
          rowContext,
          count: options(rowContext, ref).length,
          options: options,
          anchorBuilder: (context, open) => _OpenRow(
            open: open,
            child: Consumer(
              builder: (context, ref, _) => SettingsTile(
                icon: icon,
                title: title,
                subtitle: _summary(context, ref),
                open: open,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The unfolded row lifted above the dimmed screen: it rounds off and
/// gains an outline as it opens.
class _OpenRow extends StatelessWidget {
  const _OpenRow({required this.open, required this.child});

  final Animation<double> open;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return AnimatedBuilder(
      animation: open,
      builder: (context, child) {
        final radius = BorderRadius.circular(
          lerpDouble(0, SettingsTileLayout.openRadius, open.value),
        );
        return Material(
          type: MaterialType.transparency,
          // The outline is painted over the row, so it takes no room and
          // the row stays exactly where it is in the list.
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: surge.card, borderRadius: radius),
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: surge.separator.withValues(alpha: open.value),
                width: surge.spacing.hairline * 2,
              ),
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
