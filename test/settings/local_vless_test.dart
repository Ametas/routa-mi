import 'dart:io';
import 'dart:math';

import 'package:fl_clash/common/local_proxy_auth.dart';
import 'package:fl_clash/common/local_vless.dart';
import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/services/settings/settings_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const _uuid = '3b2f8a5e-6f0c-4d1e-9a7b-2c4d6e8f0a1b';

void main() {
  group('uuid', () {
    test('generated UUIDs are random version 4 UUIDs', () {
      final a = LocalVless.generateUuid();
      final b = LocalVless.generateUuid();
      expect(LocalVless.uuidPattern.hasMatch(a), isTrue);
      expect(a[14], '4');
      expect(a, isNot(b));
      expect(
        LocalVless.generateUuid(random: Random(3)),
        LocalVless.generateUuid(random: Random(3)),
      );
    });

    test('the inbound is off by default and gets a UUID when turned on', () {
      expect(const NetworkProps().localVless.enable, isFalse);
      expect(const NetworkProps().localVless.port, defaultLocalVlessPort);
      expect(NetworkProps.fromJson({}).localVless.enable, isFalse);
      const off = NetworkProps(
        authentication: AuthenticationProps(username: 'u', password: 'p'),
      );
      expect(identical(ensureLocalProxyCredentials(off), off), isTrue);

      final on = off.copyWith(localVless: const LocalVlessProps(enable: true));
      final ensured = ensureLocalProxyCredentials(on);
      expect(LocalVless.uuidPattern.hasMatch(ensured.localVless.uuid), isTrue);
      expect(identical(ensureLocalProxyCredentials(ensured), ensured), isTrue);
    });

    test('settings written without a UUID get one back', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      keepLocalProxyCredentials(container);
      container.read(networkSettingProvider.notifier).value =
          const NetworkProps(localVless: LocalVlessProps(enable: true));
      expect(
        container.read(networkSettingProvider).localVless.isComplete,
        isTrue,
      );
    });
  });

  group('listener', () {
    const props = LocalVlessProps(enable: true, port: 7894, uuid: _uuid);

    test('listens on loopback, or on all interfaces with allow-lan', () {
      expect(props.listener(allowLan: false), {
        'name': LocalVless.listenerName,
        'type': 'vless',
        'listen': '127.0.0.1',
        'port': 7894,
        'allow-insecure': true,
        'users': [
          {'username': LocalVless.username, 'uuid': _uuid},
        ],
      });
      expect(props.listener(allowLan: true)!['listen'], '0.0.0.0');
    });

    test('no listener while off or without a UUID', () {
      expect(props.copyWith(enable: false).listener(allowLan: false), isNull);
      expect(props.copyWith(uuid: '').listener(allowLan: false), isNull);
    });

    test('share link is a plain VLESS link', () {
      expect(
        props.shareLink(),
        'vless://$_uuid@127.0.0.1:7894'
        '?encryption=none&security=none&type=tcp#RoutaMi',
      );
    });

    test('port must be in range and free', () {
      const patch = PatchClashConfig(mixedPort: 7890, socksPort: 7891);
      expect(LocalVless.portError(7894, patch), isNull);
      expect(LocalVless.portError(null, patch), isNotNull);
      expect(LocalVless.portError(80, patch), isNotNull);
      expect(LocalVless.portError(65000, patch), isNotNull);
      expect(LocalVless.portError(7890, patch), isNotNull);
      expect(LocalVless.portError(7891, patch), isNotNull);
    });
  });

  group('runtime profile', () {
    Future<Map> materialize(
      Map<String, dynamic> raw,
      Map<String, dynamic>? listener, {
      String? writeTo,
    }) async {
      final output = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: p.join('runtime', 'profiles'),
          profileId: 7,
          rawConfig: raw,
          // No GeoSite policies: the core parses the fixture offline.
          realPatchConfig: const PatchClashConfig(
            dns: Dns(
              nameserverPolicy: {},
              fallbackFilter: FallbackFilter(geoip: false, geosite: []),
            ),
          ),
          overrideDns: false,
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'test-UA',
          localVlessListener: listener,
        ),
      );
      if (writeTo != null) {
        final file = File(writeTo);
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(output.a);
      }
      return loadYaml(output.a) as Map;
    }

    final listener = const LocalVlessProps(
      enable: true,
      uuid: _uuid,
    ).listener(allowLan: false);

    test('the app listener is added next to the profile listeners', () async {
      final output = await materialize(
        {
          'listeners': [
            {'name': 'profile-socks', 'type': 'socks', 'port': 7999},
            {'name': LocalVless.listenerName, 'type': 'vless', 'port': 1},
          ],
        },
        listener,
        // Parsed by the bundled core in core/local_vless_test.go.
        writeTo: p.join('build', 'mihomo-runtime-fixtures', 'local_vless.yaml'),
      );
      final listeners = output['listeners'] as List;
      expect(listeners.map((item) => item['name']), [
        'profile-socks',
        LocalVless.listenerName,
      ]);
      expect(listeners.last['port'], defaultLocalVlessPort);
      expect(listeners.last['users'][0]['uuid'], _uuid);
    });

    test('turning it off removes only the app listener', () async {
      final output = await materialize({
        'listeners': [
          {'name': 'profile-socks', 'type': 'socks', 'port': 7999},
          {'name': LocalVless.listenerName, 'type': 'vless', 'port': 1},
        ],
      }, null);
      expect((output['listeners'] as List).map((item) => item['name']), [
        'profile-socks',
      ]);
      expect((await materialize({}, null)).containsKey('listeners'), isFalse);
    });
  });

  group('settings contract', () {
    final base = const Config(themeProps: defaultThemeProps).copyWith
        .networkProps(
          localVless: const LocalVlessProps(enable: true, uuid: _uuid),
        );

    test('changing the inbound reloads the core config', () {
      for (final changed in [
        base.copyWith.networkProps.localVless(enable: false),
        base.copyWith.networkProps.localVless(port: 7999),
        base.copyWith.networkProps.localVless(uuid: LocalVless.generateUuid()),
        // The listen address follows allow-lan, which is otherwise hot.
        base.copyWith.patchClashConfig(allowLan: true),
      ]) {
        expect(settingsApplyKind(base, changed), SettingsApplyKind.reload);
      }
      final off = base.copyWith.networkProps.localVless(enable: false);
      expect(
        settingsApplyKind(off, off.copyWith.patchClashConfig(allowLan: true)),
        SettingsApplyKind.hot,
      );
    });

    test('a failed apply rolls the inbound back', () {
      final attempted = base.copyWith.networkProps.localVless(port: 7999);
      final rolledBack = rollbackSettings(base, attempted, attempted);
      expect(rolledBack.networkProps.localVless, base.networkProps.localVless);
    });
  });
}
