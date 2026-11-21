import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/icon.dart';
import 'package:fl_clash/widgets/proxy_name_icon.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/text.dart';
import 'package:flutter/material.dart';

/// Pieces shared by the home group panel and the proxies page (design 3.1):
/// icon tiles with a selection ring, the group type chip, the round open
/// arrow and the tappable delay.
abstract final class ProxyGroupBits {
  static const double tile = 30;
  static const double toggle = 30;
  static const double action = 34;
  static const double cardRadius = 22;
}

/// An accent ring and tint around a tile when it is the selected one.
class ProxySelectionRing extends StatelessWidget {
  const ProxySelectionRing({
    super.key,
    required this.selected,
    required this.child,
  });

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return AnimatedContainer(
      duration: SurgeMotion.state,
      decoration: BoxDecoration(
        color: selected
            ? surge.primary.withValues(alpha: SurgeAlpha.a16)
            : null,
        borderRadius: BorderRadius.circular(surge.radii.input),
        border: Border.all(
          color: selected ? surge.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}

/// A node's tile: the flag or symbol its name starts with.
class ProxyNodeTile extends StatelessWidget {
  const ProxyNodeTile({
    super.key,
    required this.name,
    required this.nameIcons,
    this.selected = false,
  });

  final String name;
  final bool nameIcons;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ProxySelectionRing(
      selected: selected,
      child: ProxyNameIconTile(
        icon: nameIcons ? splitProxyNameIcon(name).icon : null,
        size: ProxyGroupBits.tile,
      ),
    );
  }
}

/// A group's tile: its own icon from the profile, else the emoji its name
/// starts with.
class ProxyGroupIconTile extends StatelessWidget {
  const ProxyGroupIconTile({
    super.key,
    required this.group,
    required this.nameIcons,
    this.selected = false,
  });

  final Group group;
  final bool nameIcons;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (group.icon.isEmpty) {
      return ProxyNodeTile(
        name: group.name,
        nameIcons: nameIcons,
        selected: selected,
      );
    }
    final surge = SurgeTheme.of(context);
    return ProxySelectionRing(
      selected: selected,
      child: Container(
        width: ProxyGroupBits.tile,
        height: ProxyGroupBits.tile,
        padding: const EdgeInsets.all(SurgeSpace.xs + SurgeSpace.xxs),
        decoration: BoxDecoration(
          color: surge.textSecondary.withValues(alpha: SurgeAlpha.a08),
          borderRadius: BorderRadius.circular(surge.radii.input),
        ),
        child: IconTheme.merge(
          data: IconThemeData(
            size: SurgeIconSize.compact,
            color: surge.primary,
          ),
          child: CommonTargetIcon(src: group.icon),
        ),
      ),
    );
  }
}

/// The mihomo group type as a small outlined chip; automatic groups
/// (url-test, fallback, load-balance) in the accent.
class ProxyGroupTypeChip extends StatelessWidget {
  const ProxyGroupTypeChip(this.type, {super.key, this.automatic = false});

  final String type;
  final bool automatic;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final color = automatic ? surge.primary : surge.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SurgeSpace.xs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(surge.radii.compact),
        border: Border.all(
          color: automatic
              ? surge.primary.withValues(alpha: SurgeAlpha.a48)
              : surge.separator,
        ),
      ),
      child: Text(
        type.toUpperCase(),
        maxLines: 1,
        style: context.typography.chartLabel.copyWith(color: color),
      ),
    );
  }
}

/// The round arrow that says a header opens; it turns and fills when open.
class ProxyGroupOpenToggle extends StatelessWidget {
  const ProxyGroupOpenToggle({super.key, required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return AnimatedRotation(
      turns: open ? 0.5 : 0,
      duration: SurgeMotion.container,
      curve: SurgeMotion.stateCurve,
      child: AnimatedContainer(
        duration: SurgeMotion.container,
        width: ProxyGroupBits.toggle,
        height: ProxyGroupBits.toggle,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: open ? surge.primary : null,
          border: Border.all(color: open ? surge.primary : surge.separator),
        ),
        child: Icon(
          SurgeIcons.expand,
          size: SurgeIconSize.compact,
          color: open ? surge.onPrimary : surge.textSecondary,
        ),
      ),
    );
  }
}

/// A round outlined action beside a header, such as the delay test. [active]
/// fills it with the accent (an open search); [busy] spins while it runs.
class ProxyRoundAction extends StatelessWidget {
  const ProxyRoundAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.busy = false,
    this.accent = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final bool busy;

  /// Outlines the page's main action (add) in the accent colour.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final color = active
        ? surge.onPrimary
        : accent
        ? surge.primary
        : surge.textSecondary;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: active ? true : null,
        label: tooltip,
        excludeSemantics: true,
        child: SurgePressable(
          onTap: busy ? null : onPressed,
          borderRadius: BorderRadius.circular(ProxyGroupBits.action / 2),
          child: AnimatedContainer(
            duration: SurgeMotion.state,
            width: ProxyGroupBits.action,
            height: ProxyGroupBits.action,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? surge.primary : null,
              border: Border.all(
                color: active || accent ? surge.primary : surge.separator,
              ),
            ),
            child: busy
                ? SizedBox.square(
                    dimension: SurgeIconSize.compact,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: surge.primary,
                    ),
                  )
                : Icon(icon, size: SurgeIconSize.compact, color: color),
          ),
        ),
      ),
    );
  }
}

/// A small accent pin: the choice of an automatic group is fixed by hand.
class ProxyPinMark extends StatelessWidget {
  const ProxyPinMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(
      SurgeIcons.pin,
      size: SurgeIconSize.micro,
      color: SurgeTheme.of(context).primary,
      semanticLabel: context.appLocalizations.pinnedManually,
    );
  }
}

/// A group's (or node's) name over its type chip and what it has chosen.
class ProxyNameAndChoice extends StatelessWidget {
  const ProxyNameAndChoice({
    super.key,
    required this.title,
    required this.type,
    required this.choice,
    required this.titleStyle,
    this.titleColor,
    this.automatic = false,
    this.pinned = false,
    this.choiceWidget,
  });

  final String title;
  final String type;
  final bool automatic;
  final bool pinned;
  final String choice;
  final TextStyle titleStyle;
  final Color? titleColor;

  /// Replaces the plain choice text, e.g. with a scrolling label.
  final Widget? choiceWidget;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        EmojiText(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle.copyWith(color: titleColor ?? surge.textPrimary),
        ),
        const SizedBox(height: SurgeSpace.xxs),
        Row(
          children: [
            ProxyGroupTypeChip(type, automatic: automatic),
            if (pinned) ...[
              const SizedBox(width: SurgeSpace.xs),
              const ProxyPinMark(),
            ],
            const SizedBox(width: SurgeSpace.xs + SurgeSpace.xxs),
            Flexible(
              child:
                  choiceWidget ??
                  EmojiText(
                    choice,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.proxyCardSubtitle.copyWith(
                      color: surge.textSecondary,
                    ),
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A name without the flag or symbol its tile already shows.
String proxyTitle(String name, bool nameIcons) =>
    nameIcons ? splitProxyNameIcon(name).title : name;

/// The fixed choice of an automatic group, or null when it follows the test.
String? proxyGroupPinned(Group group) {
  final fixed = group.fixed;
  return group.type.supportsFixedSelection && fixed != null && fixed.isNotEmpty
      ? fixed
      : null;
}

/// A node's delay as coloured text; tap to test it again. Untested shows a
/// test icon, a running test a spinner (delay 0).
class ProxyDelayText extends StatelessWidget {
  const ProxyDelayText({super.key, required this.delay, this.onTap});

  final int? delay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    final value = delay;
    final Widget child;
    if (value == 0) {
      child = SizedBox.square(
        dimension: SurgeIconSize.compact,
        child: CircularProgressIndicator(strokeWidth: 2, color: surge.primary),
      );
    } else if (value == null) {
      child = Icon(
        SurgeIcons.networkPing,
        size: SurgeIconSize.compact,
        color: surge.textSecondary,
      );
    } else {
      child = Text(
        value < 0 ? l10n.timeout : '$value ms',
        style: context.typography.technical.copyWith(
          color: surge.latencyColor(value) ?? surge.textSecondary,
        ),
      );
    }
    return Semantics(
      button: onTap != null,
      label: l10n.testLatency,
      child: SurgePressable(
        onTap: value == 0 ? null : onTap,
        scaleFeedback: false,
        borderRadius: BorderRadius.circular(surge.radii.compact),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SurgeSpace.xs,
            vertical: SurgeSpace.xxs,
          ),
          child: child,
        ),
      ),
    );
  }
}

bool proxyGroupIsAutomatic(Group group) => switch (group.type) {
  GroupType.URLTest || GroupType.Fallback || GroupType.LoadBalance => true,
  _ => false,
};
