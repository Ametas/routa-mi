import 'dart:math';

import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/surge/surge_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app dialog: centred title, content and a row of actions.
///
/// [actions] are `SurgeDialogActionButton`s (cancel first, the primary
/// action last); they share the width below the content and stay visible
/// while it scrolls.
class CommonDialog extends ConsumerWidget {
  final String title;
  final Widget? child;
  final List<Widget>? actions;
  final EdgeInsets? padding;
  final bool overrideScroll;
  final Color? backgroundColor;

  const CommonDialog({
    super.key,
    required this.title,
    this.actions,
    this.child,
    this.padding,
    this.overrideScroll = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, ref) {
    final size = ref.watch(viewSizeProvider);
    final body = overrideScroll
        ? child ?? const SizedBox.shrink()
        : SingleChildScrollView(child: child);
    final actions = this.actions;
    return AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      contentPadding: padding,
      backgroundColor: backgroundColor,
      content: Container(
        constraints: BoxConstraints(
          maxHeight: min(size.height - 40, 500),
          maxWidth: 300,
        ),
        width: size.width - 40,
        child: actions == null || actions.isEmpty
            ? body
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(child: body),
                  const SizedBox(height: SurgeSpace.xl),
                  Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: SurgeSpace.l),
                        actions[i],
                      ],
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
