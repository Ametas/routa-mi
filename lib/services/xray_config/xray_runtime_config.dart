import 'dart:convert';

import 'package:fl_clash/enum/enum.dart';

/// One server of an Xray profile: an element of a panel's JSON array (or
/// the single config), shown as a node in the proxy list.
class XrayNode {
  const XrayNode({
    required this.name,
    required this.tag,
    required this.protocol,
  });

  final String name;

  /// Outbound tag in the runtime config, the balancer target.
  final String tag;
  final String protocol;
}

/// Settings of the app that reach an Xray profile.
class XrayRuntimeOptions {
  const XrayRuntimeOptions({
    required this.tun,
    required this.mixedPort,
    this.allowLan = false,
    this.credentials = const [],
    this.localVless,
    this.logLevel = LogLevel.error,
    this.mode = Mode.rule,
    this.selectedNode,
  });

  /// VPN mode: a `tun` inbound for the VpnService descriptor.
  final bool tun;
  final int mixedPort;
  final bool allowLan;

  /// `user:pass` entries for the mixed (SOCKS + HTTP) port.
  final List<String> credentials;

  /// `(port, uuid)` of the local VLESS inbound, if on.
  final ({int port, String uuid})? localVless;
  final LogLevel logLevel;
  final Mode mode;

  /// Name of the node to route through; the first node otherwise.
  final String? selectedNode;
}

/// The config Xray runs, built from a profile source and app settings.
class XrayRuntimeConfig {
  const XrayRuntimeConfig({
    required this.json,
    required this.nodes,
    required this.selectedTag,
  });

  static const balancerTag = 'routami-select';
  static const groupName = 'Proxy';
  static const tunTag = 'routami-tun';
  static const mixedTag = 'routami-mixed';
  static const vlessTag = 'routami-vless';
  static const directTag = 'routami-direct';
  static const dnsTag = 'routami-dns';

  final String json;
  final List<XrayNode> nodes;
  final String selectedTag;

  XrayNode? get selectedNode {
    for (final node in nodes) {
      if (node.tag == selectedTag) return node;
    }
    return null;
  }
}

/// Builds the runtime config: every node's outbounds under one balancer so
/// the node switches without a restart, the routing and DNS of the source,
/// and the app's own inbounds instead of the source's.
XrayRuntimeConfig buildXrayRuntimeConfig(
  String source,
  XrayRuntimeOptions options,
) {
  final decoded = jsonDecode(source);
  final elements = [
    for (final item in decoded is List ? decoded : [decoded])
      if (item is Map) Map<String, dynamic>.from(item),
  ];
  if (elements.isEmpty) {
    throw const FormatException('No Xray config in the profile');
  }

  final outbounds = <Map<String, dynamic>>[];
  final nodes = <XrayNode>[];
  final usedNames = <String>{};
  Map<String, String> firstTags = const {};
  String? firstMainTag;
  for (var index = 0; index < elements.length; index++) {
    final element = elements[index];
    final prefix = 'n${index.toString().padLeft(3, '0')}-';
    final source = _maps(element['outbounds']);
    if (source.isEmpty) continue;
    final tags = <String, String>{};
    for (var i = 0; i < source.length; i++) {
      final tag = source[i]['tag'] as String? ?? 'out$i';
      tags[tag] = '$prefix$tag';
    }
    final main = source.firstWhere(
      (outbound) => outbound['tag'] == 'proxy',
      orElse: () => source.firstWhere(
        (outbound) => !_utilityProtocols.contains(outbound['protocol']),
        orElse: () => source.first,
      ),
    );
    for (var i = 0; i < source.length; i++) {
      final outbound = _retag(source[i], tags, 'out$i');
      outbounds.add(outbound);
    }
    final mainTag =
        tags[main['tag'] as String? ?? 'out${source.indexOf(main)}']!;
    nodes.add(
      XrayNode(
        name: _uniqueName(
          (element['remarks'] as String?)?.trim().isNotEmpty == true
              ? (element['remarks'] as String).trim()
              : 'Node ${nodes.length + 1}',
          usedNames,
        ),
        tag: mainTag,
        protocol: main['protocol'] as String? ?? '',
      ),
    );
    if (firstMainTag == null) {
      firstTags = tags;
      firstMainTag = mainTag;
    }
  }
  if (nodes.isEmpty) {
    throw const FormatException('The Xray profile has no outbounds');
  }
  final selected = nodes.firstWhere(
    (node) => node.name == options.selectedNode,
    orElse: () => nodes.first,
  );

  outbounds.addAll([
    {'tag': XrayRuntimeConfig.directTag, 'protocol': 'freedom'},
    if (options.tun) {'tag': XrayRuntimeConfig.dnsTag, 'protocol': 'dns'},
  ]);

  final first = elements.first;
  final sourceRouting = first['routing'] is Map
      ? Map<String, dynamic>.from(first['routing'] as Map)
      : <String, dynamic>{};
  final balancer = {
    'tag': XrayRuntimeConfig.balancerTag,
    'selector': [for (final node in nodes) node.tag],
  };
  final toNodes = {'balancerTag': XrayRuntimeConfig.balancerTag};
  final rules = <Map<String, dynamic>>[
    if (options.tun)
      {
        'inboundTag': [XrayRuntimeConfig.tunTag],
        'port': '53',
        'outboundTag': XrayRuntimeConfig.dnsTag,
      },
    ...switch (options.mode) {
      Mode.rule => [
        for (final rule in _maps(sourceRouting['rules']))
          _routeRule(rule, firstTags, firstMainTag!),
      ],
      Mode.global => const <Map<String, dynamic>>[],
      Mode.direct => const <Map<String, dynamic>>[],
    },
    {
      'network': 'tcp,udp',
      ...options.mode == Mode.direct
          ? {'outboundTag': XrayRuntimeConfig.directTag}
          : toNodes,
    },
  ];
  final routing = <String, dynamic>{
    ...sourceRouting,
    'balancers': [
      if (options.mode == Mode.rule)
        for (final b in _maps(sourceRouting['balancers']))
          {
            ...b,
            'selector': [
              for (final s in (b['selector'] as List? ?? const []))
                firstTags[s] ?? s,
            ],
          },
      balancer,
    ],
    'rules': rules,
  };

  final listen = options.allowLan ? '0.0.0.0' : '127.0.0.1';
  final accounts = [
    for (final credential in options.credentials)
      if (credential.contains(':'))
        {
          'user': credential.substring(0, credential.indexOf(':')),
          'pass': credential.substring(credential.indexOf(':') + 1),
        },
  ];
  final sniffing = {
    'enabled': true,
    'destOverride': ['http', 'tls', 'quic'],
    'routeOnly': true,
  };
  final inbounds = [
    if (options.tun)
      {
        'tag': XrayRuntimeConfig.tunTag,
        'protocol': 'tun',
        'port': 0,
        'settings': {'name': 'xray0', 'MTU': 9000},
        'sniffing': sniffing,
      },
    {
      'tag': XrayRuntimeConfig.mixedTag,
      'protocol': 'socks', // falls back to HTTP on the same port
      'listen': listen,
      'port': options.mixedPort,
      'settings': {
        'udp': true,
        if (accounts.isNotEmpty) ...{'auth': 'password', 'accounts': accounts},
      },
      'sniffing': sniffing,
    },
    if (options.localVless case final vless?)
      {
        'tag': XrayRuntimeConfig.vlessTag,
        'protocol': 'vless',
        'listen': listen,
        'port': vless.port,
        'settings': {
          'clients': [
            {'id': vless.uuid, 'email': 'routami'},
          ],
          'decryption': 'none',
        },
        'sniffing': sniffing,
      },
  ];

  final policy = first['policy'] is Map
      ? Map<String, dynamic>.from(first['policy'] as Map)
      : <String, dynamic>{};
  final config = <String, dynamic>{
    'log': {'loglevel': _logLevel(options.logLevel)},
    if (first['dns'] != null) 'dns': first['dns'],
    'stats': <String, dynamic>{},
    'policy': {
      ...policy,
      'system': {
        if (policy['system'] is Map) ...policy['system'] as Map,
        'statsOutboundUplink': true,
        'statsOutboundDownlink': true,
      },
    },
    'inbounds': inbounds,
    'outbounds': outbounds,
    'routing': routing,
  };
  return XrayRuntimeConfig(
    json: const JsonEncoder.withIndent('  ').convert(config),
    nodes: nodes,
    selectedTag: selected.tag,
  );
}

const _utilityProtocols = {'freedom', 'blackhole', 'dns', 'loopback'};

List<Map<String, dynamic>> _maps(Object? value) => [
  if (value is List)
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
];

/// Copies [outbound] with its own and every referenced tag of the same
/// element renamed (dialer chains, proxySettings).
Map<String, dynamic> _retag(
  Map<String, dynamic> outbound,
  Map<String, String> tags,
  String fallbackTag,
) {
  final copy = jsonDecode(jsonEncode(outbound)) as Map<String, dynamic>;
  copy['tag'] = tags[copy['tag'] ?? fallbackTag];
  final sockopt = (copy['streamSettings'] as Map?)?['sockopt'];
  if (sockopt is Map && tags[sockopt['dialerProxy']] != null) {
    sockopt['dialerProxy'] = tags[sockopt['dialerProxy']];
  }
  final proxySettings = copy['proxySettings'];
  if (proxySettings is Map && tags[proxySettings['tag']] != null) {
    proxySettings['tag'] = tags[proxySettings['tag']];
  }
  return copy;
}

/// A source rule pointed at the node now points at the balancer; other
/// tags (direct, block) at their renamed copies.
Map<String, dynamic> _routeRule(
  Map<String, dynamic> rule,
  Map<String, String> tags,
  String mainTag,
) {
  final copy = Map<String, dynamic>.from(rule);
  final target = copy['outboundTag'];
  if (target is String) {
    final renamed = tags[target];
    if (renamed == mainTag) {
      copy.remove('outboundTag');
      copy['balancerTag'] = XrayRuntimeConfig.balancerTag;
    } else if (renamed != null) {
      copy['outboundTag'] = renamed;
    }
  }
  return copy;
}

String _uniqueName(String name, Set<String> used) {
  var candidate = name;
  for (var i = 2; used.contains(candidate); i++) {
    candidate = '$name ($i)';
  }
  used.add(candidate);
  return candidate;
}

String _logLevel(LogLevel level) => switch (level) {
  LogLevel.debug => 'debug',
  LogLevel.info => 'info',
  LogLevel.warning => 'warning',
  LogLevel.error => 'error',
  LogLevel.silent => 'none',
};
