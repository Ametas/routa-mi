import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/services/xray_config/xray_runtime_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Map<String, dynamic> element(String remarks, String address) => {
  'remarks': remarks,
  'dns': {
    'servers': ['1.1.1.1'],
  },
  'inbounds': [
    {'tag': 'socks', 'port': 10808, 'protocol': 'socks'},
  ],
  'outbounds': [
    {
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': address,
            'port': 443,
            'users': [
              {
                'id': '3b2f8a5e-6f0c-4d1e-9a7b-2c4d6e8f0a1b',
                'encryption': 'none',
              },
            ],
          },
        ],
      },
      'streamSettings': {
        'network': 'tcp',
        'security': 'tls',
        'sockopt': {'dialerProxy': 'fragment'},
      },
    },
    {
      'tag': 'fragment',
      'protocol': 'freedom',
      'settings': {
        'fragment': {
          'packets': 'tlshello',
          'length': '100-200',
          'interval': '10-20',
        },
      },
    },
    {'tag': 'direct', 'protocol': 'freedom'},
    {'tag': 'block', 'protocol': 'blackhole'},
  ],
  'routing': {
    'domainStrategy': 'IPIfNonMatch',
    'rules': [
      {
        // Geo rules need the device's geo files; the fixture runs without.
        'domain': ['domain:ads.example.com'],
        'outboundTag': 'block',
      },
      {
        'ip': ['10.0.0.0/8'],
        'outboundTag': 'direct',
      },
      {'network': 'tcp,udp', 'outboundTag': 'proxy'},
    ],
  },
};

final panel = jsonEncode([
  element('🇳🇱 Amsterdam', 'nl.example.com'),
  element('🇩🇪 Frankfurt', 'de.example.com'),
  element('🇩🇪 Frankfurt', 'de2.example.com'),
]);

Map<String, dynamic> build(XrayRuntimeOptions options, [String? source]) =>
    jsonDecode(buildXrayRuntimeConfig(source ?? panel, options).json)
        as Map<String, dynamic>;

void main() {
  test('every node goes under one balancer, chains keep working', () {
    final runtime = buildXrayRuntimeConfig(
      panel,
      const XrayRuntimeOptions(tun: true, mixedPort: 7890),
    );
    expect(runtime.nodes.map((n) => n.name), [
      '🇳🇱 Amsterdam',
      '🇩🇪 Frankfurt',
      '🇩🇪 Frankfurt (2)',
    ]);
    expect(runtime.nodes.map((n) => n.tag), [
      'n000-proxy',
      'n001-proxy',
      'n002-proxy',
    ]);
    expect(runtime.selectedTag, 'n000-proxy');

    final config = jsonDecode(runtime.json) as Map<String, dynamic>;
    final outbounds = (config['outbounds'] as List).cast<Map>();
    final node1 = outbounds.firstWhere((o) => o['tag'] == 'n001-proxy');
    expect(node1['streamSettings']['sockopt']['dialerProxy'], 'n001-fragment');
    final balancer = (config['routing']['balancers'] as List).single;
    expect(balancer['tag'], XrayRuntimeConfig.balancerTag);
    expect(balancer['selector'], ['n000-proxy', 'n001-proxy', 'n002-proxy']);
  });

  test('rules of the source route to the balancer and renamed tags', () {
    final rules =
        (build(
                  const XrayRuntimeOptions(tun: true, mixedPort: 7890),
                )['routing']['rules']
                as List)
            .cast<Map>();
    expect(rules.first['outboundTag'], XrayRuntimeConfig.dnsTag);
    expect(rules[1]['outboundTag'], 'n000-block');
    expect(rules[2]['outboundTag'], 'n000-direct');
    expect(rules[3]['balancerTag'], XrayRuntimeConfig.balancerTag);
    expect(rules.last['balancerTag'], XrayRuntimeConfig.balancerTag);
  });

  test('the app owns the inbounds: TUN, mixed port with auth, VLESS', () {
    final config = build(
      const XrayRuntimeOptions(
        tun: true,
        mixedPort: 7890,
        allowLan: true,
        credentials: ['user:p:ss'],
        localVless: (port: 7894, uuid: 'uuid-1'),
        logLevel: LogLevel.warning,
      ),
    );
    final inbounds = (config['inbounds'] as List).cast<Map>();
    expect(inbounds.map((i) => i['tag']), [
      XrayRuntimeConfig.tunTag,
      XrayRuntimeConfig.mixedTag,
      XrayRuntimeConfig.vlessTag,
    ]);
    expect(inbounds[1]['listen'], '0.0.0.0');
    expect(inbounds[1]['settings']['accounts'], [
      {'user': 'user', 'pass': 'p:ss'},
    ]);
    expect(inbounds[2]['settings']['clients'][0]['id'], 'uuid-1');
    expect(config['log'], {'loglevel': 'warning'});
    expect(config['policy']['system']['statsOutboundUplink'], isTrue);
  });

  test('without VPN there is no TUN inbound and no DNS hijack', () {
    final config = build(const XrayRuntimeOptions(tun: false, mixedPort: 7890));
    expect((config['inbounds'] as List).map((i) => i['protocol']), ['socks']);
    expect(
      (config['outbounds'] as List).any((o) => o['protocol'] == 'dns'),
      isFalse,
    );
  });

  test('global and direct modes ignore the source rules', () {
    final global =
        (build(
              const XrayRuntimeOptions(
                tun: false,
                mixedPort: 1,
                mode: Mode.global,
              ),
            )['routing']['rules']
            as List);
    expect(global.single['balancerTag'], XrayRuntimeConfig.balancerTag);
    final direct =
        (build(
              const XrayRuntimeOptions(
                tun: false,
                mixedPort: 1,
                mode: Mode.direct,
              ),
            )['routing']['rules']
            as List);
    expect(direct.single['outboundTag'], XrayRuntimeConfig.directTag);
  });

  test('the saved node is selected; a single config is one node', () {
    final runtime = buildXrayRuntimeConfig(
      panel,
      const XrayRuntimeOptions(
        tun: false,
        mixedPort: 1,
        selectedNode: '🇩🇪 Frankfurt (2)',
      ),
    );
    expect(runtime.selectedTag, 'n002-proxy');

    final single = buildXrayRuntimeConfig(
      jsonEncode(element('', 'one.example.com')..remove('remarks')),
      const XrayRuntimeOptions(tun: false, mixedPort: 1),
    );
    expect(single.nodes.single.name, 'Node 1');
  });

  test('a profile without outbounds is rejected', () {
    expect(
      () => buildXrayRuntimeConfig(
        '[{"inbounds": []}]',
        const XrayRuntimeOptions(tun: false, mixedPort: 1),
      ),
      throwsFormatException,
    );
  });

  test('fixture for the core (core/configfixture/xray_runtime_test.go)', () {
    final dir = Directory(p.join('build', 'mihomo-runtime-fixtures'))
      ..createSync(recursive: true);
    // No TUN: the Go test starts it on the host. Port 0 is replaced there.
    File(p.join(dir.path, 'xray_runtime.json')).writeAsStringSync(
      buildXrayRuntimeConfig(
        panel,
        const XrayRuntimeOptions(
          tun: false,
          mixedPort: 7890,
          credentials: ['user:pass'],
          localVless: (
            port: 7894,
            uuid: '3b2f8a5e-6f0c-4d1e-9a7b-2c4d6e8f0a1b',
          ),
        ),
      ).json,
    );
    File(p.join(dir.path, 'xray_runtime_tun.json')).writeAsStringSync(
      buildXrayRuntimeConfig(
        panel,
        const XrayRuntimeOptions(tun: true, mixedPort: 7890),
      ).json,
    );
  });
}
