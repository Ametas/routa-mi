import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:fl_clash/views/config/local_proxy_auth_items.dart';
import 'package:fl_clash/views/config/local_vless_items.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Basic settings in FlClash's grouping: inbound (port, LAN, controller,
/// authentication, local VLESS), their sections when on, then the rest of
/// the core settings.
class ConfigView extends ConsumerWidget {
  const ConfigView({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final authentication = ref.watch(
      networkSettingProvider.select((state) => state.authentication.enable),
    );
    final localVless = ref.watch(
      networkSettingProvider.select((state) => state.localVless.enable),
    );
    return CommonScaffold(
      title: appLocalizations.basicConfig,
      body: SurgeSectionList(
        sections: [
          SurgeSection(
            title: appLocalizations.inbound,
            showDividers: true,
            children: const [
              PortItem(),
              AllowLanItem(),
              ExternalControllerItem(),
              AuthenticationItem(),
              LocalVlessItem(),
            ],
          ),
          if (authentication)
            SurgeSection(
              title: appLocalizations.authentication,
              showDividers: true,
              children: const [
                AuthenticationAccountItem(),
                AuthenticationPasswordItem(),
                AuthenticationRegenerateItem(),
              ],
            ),
          if (localVless)
            const SurgeSection(
              title: 'VLESS',
              showDividers: true,
              children: [
                LocalVlessPortItem(),
                LocalVlessUuidItem(),
                LocalVlessLinkItem(),
                LocalVlessRegenerateItem(),
              ],
            ),
          SurgeSection(
            title: appLocalizations.other,
            showDividers: true,
            children: [
              const LogLevelItem(),
              const UaItem(),
              if (system.isDesktop) const KeepAliveIntervalItem(),
              const TestUrlItem(),
              const HostsItem(),
              const Ipv6Item(),
              const UnifiedDelayItem(),
              const AppendSystemDNSItem(),
              const FindProcessItem(),
              const TcpConcurrentItem(),
              const GeodataLoaderItem(),
            ],
          ),
        ],
      ),
    );
  }
}
