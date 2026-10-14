import 'dart:convert';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/xray_runtime.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/xray_config/xray_runtime_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

String node(String remarks) => jsonEncode({
  'remarks': remarks,
  'outbounds': [
    {'tag': 'proxy', 'protocol': 'vless'},
    {'tag': 'direct', 'protocol': 'freedom'},
  ],
});

void main() {
  late MockCoreHandlerInterface mock;
  late CoreController controller;

  setUpAll(() {
    registerFallbackValue(
      const ChangeProxyParams(groupName: 'G', proxyName: 'P'),
    );
    registerFallbackValue(
      const UpdateParams(
        tun: Tun(),
        mixedPort: 7890,
        allowLan: false,
        findProcessMode: FindProcessMode.off,
        mode: Mode.rule,
        logLevel: LogLevel.info,
        ipv6: false,
        tcpConcurrent: false,
        externalController: ExternalControllerStatus.close,
        unifiedDelay: false,
      ),
    );
  });

  setUp(() {
    mock = MockCoreHandlerInterface();
    CoreController.resetInstance();
    controller = CoreController.test(mock);
    xrayRuntime
      ..pending = null
      ..active = buildXrayRuntimeConfig(
        '[${node('NL')}, ${node('DE')}]',
        const XrayRuntimeOptions(tun: false, mixedPort: 7890),
      );
  });

  tearDown(() {
    xrayRuntime
      ..pending = null
      ..active = null;
    CoreController.resetInstance();
  });

  test(
    'Xray nodes are one selector group, selection is the balancer',
    () async {
      final groups = await controller.getProxiesGroups(
        sortType: ProxiesSortType.none,
        delayMap: const {},
        selectedMap: const {},
        defaultTestUrl: 'https://x',
      );
      expect(groups.single.name, XrayRuntimeConfig.groupName);
      expect(groups.single.type, GroupType.Selector);
      expect(groups.single.all.map((p) => p.name), ['NL', 'DE']);
      expect(groups.single.all.first.type, 'Vless');
      expect(groups.single.now, 'NL');
      verifyNever(() => mock.getProxies());

      when(() => mock.xraySelect(any(), any())).thenAnswer((_) async => '');
      final message = await controller.changeProxy(
        const ChangeProxyParams(groupName: 'Proxy', proxyName: 'DE'),
      );
      expect(message, isEmpty);
      verify(
        () => mock.xraySelect(XrayRuntimeConfig.balancerTag, 'n001-proxy'),
      ).called(1);
      expect(xrayRuntime.groups().single.now, 'DE');
    },
  );

  test('an unknown node never reaches the core', () async {
    final message = await controller.changeProxy(
      const ChangeProxyParams(groupName: 'Proxy', proxyName: 'nope'),
    );
    expect(message, isNotEmpty);
    verifyNever(() => mock.xraySelect(any(), any()));
    verifyNever(() => mock.changeProxy(any()));
  });

  test('mihomo hot updates are not sent while Xray runs', () async {
    final message = await controller.updateConfig(
      const UpdateParams(
        tun: Tun(),
        mixedPort: 7891,
        allowLan: false,
        findProcessMode: FindProcessMode.off,
        mode: Mode.rule,
        logLevel: LogLevel.info,
        ipv6: false,
        tcpConcurrent: false,
        externalController: ExternalControllerStatus.close,
        unifiedDelay: false,
      ),
    );
    expect(message, isEmpty);
    verifyNever(() => mock.updateConfig(any()));
  });
}
