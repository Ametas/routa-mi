/// Runtime profile patch for the local listeners' credentials: the app's
/// list replaces the profile's `authentication`, and `skip-auth-prefixes` is
/// cleared so no address (loopback included) is exempt from it.
void applyOwnedAuthenticationPatch(
  Map<String, dynamic> rawConfig,
  List<String> authentication,
) {
  rawConfig['authentication'] = List<String>.of(authentication);
  rawConfig['skip-auth-prefixes'] = <String>[];
}

/// Runtime profile patch for the app's VLESS inbound: a profile listener
/// with the same name is replaced, and none is added when it is off.
void applyOwnedVlessListenerPatch(
  Map<String, dynamic> rawConfig,
  Map<String, dynamic>? listener,
  String name,
) {
  final existing = rawConfig['listeners'];
  final listeners = [
    if (existing is List)
      for (final item in existing)
        if (item is! Map || item['name'] != name) item,
    ?listener,
  ];
  if (listeners.isEmpty && existing == null) return;
  rawConfig['listeners'] = listeners;
}
