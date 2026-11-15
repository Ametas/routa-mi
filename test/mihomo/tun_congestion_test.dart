import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/mihomo_config/runtime_config_patch.dart';
import 'package:fl_clash/services/mihomo_config/tun_congestion.dart';
import 'package:fl_clash/services/settings/settings_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mips stack is offered and round-trips by name', () {
    expect(TunStack.values.map((e) => e.name), contains('mips'));
    const tun = Tun(stack: TunStack.mips, congestionController: 'bbr');
    final decoded = Tun.fromJson(tun.toJson());
    expect(decoded.stack, TunStack.mips);
    expect(decoded.congestionController, 'bbr');
    expect(tun.toJson()['congestion-controller'], 'bbr');
  });

  test('congestion control is patched only for a picked value on mips', () {
    expect(tunCongestionPatch(const Tun(stack: TunStack.mips)), isEmpty);
    expect(
      tunCongestionPatch(
        const Tun(stack: TunStack.gvisor, congestionController: 'bbr'),
      ),
      isEmpty,
    );
    expect(
      tunCongestionPatch(
        const Tun(stack: TunStack.mips, congestionController: 'bbr3'),
      ),
      {'congestion-controller': 'bbr3'},
    );
  });

  test("an unpicked value keeps the profile's congestion control", () {
    final config = <String, dynamic>{
      'tun': {'stack': 'mips', 'congestion-controller': 'reno'},
    };
    applyOwnedTunPatch(config, {
      'stack': 'mips',
      ...tunCongestionPatch(const Tun(stack: TunStack.mips)),
    });
    expect(config['tun']['congestion-controller'], 'reno');
    applyOwnedTunPatch(config, {
      ...tunCongestionPatch(
        const Tun(stack: TunStack.mips, congestionController: 'bbr'),
      ),
    });
    expect(config['tun']['congestion-controller'], 'bbr');
  });

  test('a new congestion control restarts the Android VPN', () {
    final base = const Config(themeProps: defaultThemeProps)
        .copyWith(vpnProps: const VpnProps(enable: true))
        .copyWith
        .patchClashConfig
        .tun(stack: TunStack.mips);
    final changed = base.copyWith.patchClashConfig.tun(
      congestionController: 'bbr',
    );
    expect(settingsApplyKind(base, changed), SettingsApplyKind.vpn);
  });
}
