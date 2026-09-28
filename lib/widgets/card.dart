import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

import 'text.dart';

class Info {
  final String label;
  final IconData? iconData;

  const Info({required this.label, this.iconData});
}

class InfoHeader extends StatelessWidget {
  final Info info;
  final List<Widget> actions;
  final EdgeInsets? padding;

  const InfoHeader({
    super.key,
    required this.info,
    this.padding,
    List<Widget>? actions,
  }) : actions = actions ?? const [];

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final nextPadding = padding ?? baseInfoEdgeInsets;
    return Padding(
      padding: nextPadding,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (info.iconData != null) ...[
                  Icon(
                    info.iconData,
                    color: surge.textSecondary,
                    size: SurgeIconSize.compact,
                  ),
                  const SizedBox(width: SurgeSpace.s),
                ],
                Expanded(
                  child: TooltipText(
                    text: Text(
                      info.label,
                      maxLines: 2,
                      style: context.typography.sectionTitle.copyWith(
                        color: surge.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: SurgeSpace.m),
            IconTheme.merge(
              data: IconThemeData(color: surge.primary, size: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [...actions],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
