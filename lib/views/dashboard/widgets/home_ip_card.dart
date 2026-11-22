import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widgets/home_panels.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The flag emoji of a two-letter country code; other codes as they are.
String countryFlag(String countryCode) {
  final code = countryCode.toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) return countryCode;
  return String.fromCharCodes([
    for (final unit in code.codeUnits) unit - 0x41 + 0x1F1E6,
  ]);
}

/// What the IP card says: the address traffic leaves from, a check in
/// progress, a failed check or none yet.
enum HomeIpStatus { shown, checking, failed, idle }

HomeIpStatus homeIpStatus(NetworkDetectionState state) {
  if (state.ipInfo != null) return HomeIpStatus.shown;
  if (state.isLoading) return HomeIpStatus.checking;
  if (state.hasChecked) return HomeIpStatus.failed;
  return HomeIpStatus.idle;
}

/// The external IP under the network panel (design artifact "RoutaMi for
/// Windows"): the country and address traffic leaves from, checked again
/// on start, stop, mode and node changes, or by hand.
class HomeIpCard extends ConsumerWidget {
  const HomeIpCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    final state = ref.watch(networkDetectionProvider);
    final status = homeIpStatus(state);
    final ipInfo = state.ipInfo;
    final valueStyle = context.typography.supporting.copyWith(
      color: surge.textSecondary,
    );
    final Widget value = switch (status) {
      HomeIpStatus.shown => Row(
        key: ValueKey('ip-${ipInfo!.ip}'),
        children: [
          Text(
            countryFlag(ipInfo.countryCode),
            style: valueStyle.copyWith(fontFamily: FontFamily.twEmoji.value),
          ),
          const SizedBox(width: SurgeSpace.s),
          Text(ipInfo.countryCode.toUpperCase(), style: valueStyle),
          const SizedBox(width: SurgeSpace.s),
          Flexible(
            child: Text(
              ipInfo.ip,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.technical.copyWith(
                color: surge.textPrimary,
              ),
            ),
          ),
        ],
      ),
      HomeIpStatus.checking => Text(
        key: const ValueKey('ip-checking'),
        l10n.loading,
        style: valueStyle,
      ),
      HomeIpStatus.failed => Text(
        key: const ValueKey('ip-failed'),
        l10n.timeout,
        style: valueStyle.copyWith(color: surge.red),
      ),
      HomeIpStatus.idle => Text(
        key: const ValueKey('ip-idle'),
        l10n.externalIpNotChecked,
        style: valueStyle,
      ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(
        SurgeSpace.m + SurgeSpace.xxs,
        SurgeSpace.m,
        SurgeSpace.m,
        SurgeSpace.m,
      ),
      decoration: BoxDecoration(
        color: surge.card,
        borderRadius: BorderRadius.circular(HomePanelLayout.panelRadius),
        border: Border.all(
          color: surge.separator,
          width: surge.spacing.hairline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: ProxyGroupBits.tile,
            height: ProxyGroupBits.tile,
            decoration: BoxDecoration(
              color: surge.textSecondary.withValues(alpha: SurgeAlpha.a08),
              borderRadius: BorderRadius.circular(surge.radii.input),
            ),
            child: Icon(
              SurgeIcons.externalIp,
              size: SurgeIconSize.compact,
              color: surge.primary,
            ),
          ),
          const SizedBox(width: SurgeSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.externalIp,
                  style: context.typography.cardTitle.copyWith(
                    color: surge.textPrimary,
                  ),
                ),
                const SizedBox(height: SurgeSpace.xxs),
                AnimatedSwitcher(
                  duration: SurgeMotion.state,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  child: value,
                ),
              ],
            ),
          ),
          const SizedBox(width: SurgeSpace.s),
          ProxyRoundAction(
            icon: SurgeIcons.sync,
            tooltip: l10n.externalIpRecheck,
            busy: status == HomeIpStatus.checking,
            onPressed: status == HomeIpStatus.checking
                ? null
                : () => ref.read(checkIpNumProvider.notifier).add(),
          ),
        ],
      ),
    );
  }
}
