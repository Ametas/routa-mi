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
