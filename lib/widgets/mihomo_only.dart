import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/profile_core.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A setting or screen only mihomo has. While the current profile runs on
/// Xray it stays visible but dimmed, and a tap says why it does nothing.
class MihomoOnly extends ConsumerWidget {
  const MihomoOnly({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xray = ref.watch(
      currentProfileProvider.select(
        (profile) => profile?.core == ProfileCore.xray,
      ),
    );
    if (!xray) return child;
    return Semantics(
      hint: context.appLocalizations.mihomoOnlySetting,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            context.showNotifier(context.appLocalizations.mihomoOnlySetting),
        child: AbsorbPointer(
          child: Opacity(opacity: SurgeAlpha.a38, child: child),
        ),
      ),
    );
  }
}
