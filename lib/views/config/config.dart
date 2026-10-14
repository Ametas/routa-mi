import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:fl_clash/views/config/local_proxy_auth_items.dart';
import 'package:fl_clash/views/config/local_vless_items.dart';
import 'package:fl_clash/widgets/mihomo_only.dart';
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
              MihomoOnly(child: ExternalControllerItem()),
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
              if (system.isDesktop)
                const MihomoOnly(child: KeepAliveIntervalItem()),
              const TestUrlItem(),
              // Xray takes these from the profile or has no such option.
              const MihomoOnly(child: HostsItem()),
              const MihomoOnly(child: Ipv6Item()),
              const MihomoOnly(child: UnifiedDelayItem()),
              const MihomoOnly(child: AppendSystemDNSItem()),
              const MihomoOnly(child: FindProcessItem()),
              const MihomoOnly(child: TcpConcurrentItem()),
              const MihomoOnly(child: GeodataLoaderItem()),
            ],
          ),
        ],
      ),
    );
  }
}
