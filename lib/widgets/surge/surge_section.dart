import 'package:fl_clash/widgets/surge/surge_tokens.dart';
import 'package:flutter/material.dart';

import 'surge_card.dart';
import 'surge_theme_extension.dart';

class SurgeSection extends StatelessWidget {
  const SurgeSection({
    super.key,
    required this.children,
    this.title,
    this.footer,
    this.actions = const [],
    this.padding,
    this.margin,
    this.showDividers = false,
  });

  final String? title;
  final String? footer;
  final List<Widget> actions;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool showDividers;

  List<Widget> _buildChildren(SurgeTheme surge) {
    if (!showDividers) return children;
    return [
      for (var i = 0; i < children.length; i++)
        if (i == 0)
          children[i]
        else
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: surge.separator,
                  width: surge.spacing.hairline,
                ),
              ),
            ),
            child: children[i],
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final sectionMargin =
        margin ??
        EdgeInsets.only(
          left: surge.spacing.pagePadding,
          right: surge.spacing.pagePadding,
          bottom: surge.spacing.sectionSpacing,
        );

    return Padding(
      padding: sectionMargin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || actions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: SurgeSpace.xs,
                bottom: SurgeSpace.s,
              ),
              child: Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.sectionTitle,
                      ),
                    )
                  else
                    const Spacer(),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: SurgeSpace.m),
                    Row(mainAxisSize: MainAxisSize.min, children: actions),
                  ],
                ],
              ),
            ),
          ],
          SurgeCard(
            borderRadius: surge.radii.list,
            padding: padding ?? EdgeInsets.zero,
            shadow: false,
            child: Column(children: _buildChildren(surge)),
          ),
          if (footer != null) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: SurgeSpace.xs,
                top: SurgeSpace.s,
                right: SurgeSpace.xs,
              ),
              child: Text(
                footer!,
                style: context.typography.supporting.copyWith(
                  color: surge.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A scrolling settings page made of [SurgeSection]s: each section is its
/// own card with its title above it.
class SurgeSectionList extends StatelessWidget {
  const SurgeSectionList({super.key, required this.sections});

  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return ColoredBox(
      color: surge.background,
      child: ListView(
        padding: EdgeInsets.only(
          top: SurgeSpace.m,
          bottom: SurgeSpace.xxxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: sections,
      ),
    );
  }
}
