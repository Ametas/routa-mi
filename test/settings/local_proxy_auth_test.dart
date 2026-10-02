import 'dart:math';

import 'package:fl_clash/common/local_proxy_auth.dart';
import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/services/settings/settings_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

void main() {
  group('credentials', () {
    test('generated credentials are long, URL-safe and random', () {
      final a = LocalProxyAuth.generate();
      final b = LocalProxyAuth.generate();
      expect(a.username, hasLength(LocalProxyAuth.usernameLength));
      expect(a.password, hasLength(LocalProxyAuth.passwordLength));
      expect(LocalProxyAuth.usernameLength, greaterThanOrEqualTo(16));
      expect(LocalProxyAuth.passwordLength, greaterThanOrEqualTo(32));
      for (final value in [a.username, a.password]) {
        expect(LocalProxyAuth.allowedPattern.hasMatch(value), isTrue);
      }
      expect(a.password, isNot(b.password));
    });

    test('authentication is on by default and filled in on first use', () {
      expect(const NetworkProps().authentication.enable, isTrue);
      expect(const NetworkProps().authentication.credentials, isEmpty);
      final ensured = ensureLocalProxyCredentials(
        const NetworkProps(),
        random: Random(1),
      );
      final auth = ensured.authentication;
      expect(auth.isComplete, isTrue);
      expect(auth.credentials, ['${auth.username}:${auth.password}']);
      expect(
        auth.proxyDirective('127.0.0.1', 7890),
        'PROXY ${auth.username}:${auth.password}@127.0.0.1:7890',
      );
    });

    test('existing or disabled credentials are left alone', () {
      const own = NetworkProps(
        authentication: AuthenticationProps(username: 'me', password: 'pw'),
      );
      expect(identical(ensureLocalProxyCredentials(own), own), isTrue);
      const off = NetworkProps(
        authentication: AuthenticationProps(enable: false),
      );
      expect(identical(ensureLocalProxyCredentials(off), off), isTrue);
      expect(off.authentication.credentials, isEmpty);
      expect(
        off.authentication.proxyDirective('localhost', 1),
        'PROXY localhost:1',
      );
    });

    test('settings written without credentials get them back', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      keepLocalProxyCredentials(container);
      expect(
        container.read(networkSettingProvider).authentication.isComplete,
        isTrue,
      );
      // A reset or an old backup writes empty credentials.
      container.read(networkSettingProvider.notifier).value =
          defaultNetworkProps;
      expect(
        container.read(networkSettingProvider).authentication.isComplete,
        isTrue,
      );
    });

    test('older stored settings without the field enable authentication', () {
      final props = NetworkProps.fromJson({'systemProxy': true});
      expect(props.authentication.enable, isTrue);
      expect(
        ensureLocalProxyCredentials(props).authentication.isComplete,
        isTrue,
      );
    });
  });

  group('runtime profile', () {
    Future<Map> materialize(
      Map<String, dynamic> raw,
      List<String> authentication,
    ) async {
      final output = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: p.join('runtime', 'profiles'),
          profileId: 7,
          rawConfig: raw,
          realPatchConfig: const PatchClashConfig(),
          overrideDns: false,
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'test-UA',
          authentication: authentication,
        ),
      );
      return loadYaml(output.a) as Map;
    }

    test('app credentials replace the profile and nothing is exempt', () async {
      final output = await materialize(
        {
          'authentication': ['profile:owned'],
          'skip-auth-prefixes': ['127.0.0.1/32', '0.0.0.0/0'],
        },
        ['app:secret'],
      );
      expect(output['authentication'], ['app:secret']);
      expect(output['skip-auth-prefixes'], isEmpty);
    });

    test('turning authentication off clears the profile list too', () async {
      final output = await materialize({
        'authentication': ['profile:owned'],
      }, const []);
      expect(output['authentication'], isEmpty);
    });
  });

  group('settings contract', () {
    const base = Config(themeProps: defaultThemeProps);
    final authenticated = base.copyWith.networkProps(
      authentication: const AuthenticationProps(username: 'u', password: 'p'),
    );

    test('the VPN system proxy is off while credentials are required', () {
      final withProxy = authenticated.copyWith.vpnProps(systemProxy: true);
      expect(settingsVpnOptions(withProxy).systemProxy, isFalse);
      final off = withProxy.copyWith.networkProps.authentication(enable: false);
      expect(settingsVpnOptions(off).systemProxy, isTrue);
    });

    test('changing credentials reloads the core config', () {
      final changed = authenticated.copyWith.networkProps.authentication(
        password: 'other',
      );
      expect(
        settingsApplyKind(authenticated, changed),
        isNot(SettingsApplyKind.none),
      );
      expect(
        settingsApplyKind(authenticated, changed),
        isNot(SettingsApplyKind.hot),
      );
    });

    test('a failed apply rolls the credentials back', () {
      final attempted = authenticated.copyWith.networkProps.authentication(
        password: 'attempt',
      );
      final rolledBack = rollbackSettings(authenticated, attempted, attempted);
      expect(rolledBack.networkProps.authentication.password, 'p');
    });
  });
}
