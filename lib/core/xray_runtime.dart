import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/enum/profile_core.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/xray_config/xray_runtime_config.dart';

/// Which core runs and, for Xray, its nodes. `pending` is the config the
/// last materialization built (null for a mihomo profile); `active` is what
/// the core runs once a setup succeeded.
class XrayRuntime {
  XrayRuntimeConfig? pending;
  XrayRuntimeConfig? active;

  bool get isActive => active != null;

  /// The node list as the proxy screen's single selector group.
  List<Group> groups() {
    final runtime = active;
    if (runtime == null) return const [];
    return [
      Group(
        type: GroupType.Selector,
        name: XrayRuntimeConfig.groupName,
        now: runtime.selectedNode?.name,
        all: [
          for (final node in runtime.nodes)
            Proxy(name: node.name, type: _displayType(node.protocol)),
        ],
      ),
    ];
  }

  /// Balancer target for [proxyName], or null when it is not a node.
  String? tagOf(String groupName, String proxyName) {
    final runtime = active;
    if (runtime == null || groupName != XrayRuntimeConfig.groupName) {
      return null;
    }
    for (final node in runtime.nodes) {
      if (node.name == proxyName) return node.tag;
    }
    return null;
  }

  void select(String tag) {
    final runtime = active;
    if (runtime == null) return;
    active = XrayRuntimeConfig(
      json: runtime.json,
      nodes: runtime.nodes,
      selectedTag: tag,
    );
  }
}

final xrayRuntime = XrayRuntime();

String _displayType(String protocol) => protocol.isEmpty
    ? protocol
    : '${protocol[0].toUpperCase()}${protocol.substring(1)}';

/// Node list of an Xray profile that is not running (profile cards), or
/// null when [profilePath] is not an Xray profile.
Future<List<Group>?> xrayProfileGroups(
  String profilePath,
  Map<String, String> selectedMap,
) async {
  final bytes = await File(profilePath).readAsBytes();
  if (detectProfileCore(bytes) != ProfileCore.xray) return null;
  final runtime = buildXrayRuntimeConfig(
    utf8.decode(bytes, allowMalformed: true),
    XrayRuntimeOptions(
      tun: false,
      mixedPort: 0,
      selectedNode: selectedMap[XrayRuntimeConfig.groupName],
    ),
  );
  return (XrayRuntime()..active = runtime).groups();
}
