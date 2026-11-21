/// What a pasted profile link is (design 3.1 "RoutaMi Add Profile").
enum ProfileLinkKind {
  empty,

  /// A http(s) subscription address.
  subscription,

  /// clash://install-config?url=…[&name=…], as the app's deep link takes.
  clash,

  /// A single node (vless://, ss://, …): not something a profile loads.
  node,

  /// clash:// without a subscription address.
  clashWithoutUrl,
  invalid,
}

class ProfileLink {
  const ProfileLink(this.kind, {this.url = '', this.name = '', this.host = ''});

  final ProfileLinkKind kind;

  /// The subscription address to load.
  final String url;

  /// A name the link carries (clash:// &name=).
  final String name;
  final String host;

  bool get isValid =>
      kind == ProfileLinkKind.subscription || kind == ProfileLinkKind.clash;

  bool get plainHttp => url.startsWith('http://');
}

final _nodeScheme = RegExp(
  r'^(vless|vmess|ss|ssr|trojan|hysteria2?|hy2|tuic|wireguard|naive\+https?)://',
  caseSensitive: false,
);

ProfileLink parseProfileLink(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const ProfileLink(ProfileLinkKind.empty);
  if (_nodeScheme.hasMatch(text)) {
    return const ProfileLink(ProfileLinkKind.node);
  }
  var url = text;
  var name = '';
  var kind = ProfileLinkKind.subscription;
  if (text.toLowerCase().startsWith('clash://')) {
    final uri = Uri.tryParse(text);
    final address = uri?.queryParameters['url'];
    if (uri == null || uri.host != 'install-config' || address == null) {
      return const ProfileLink(ProfileLinkKind.clashWithoutUrl);
    }
    url = address.trim();
    name = uri.queryParameters['name']?.trim() ?? '';
    kind = ProfileLinkKind.clash;
  }
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !(uri.scheme == 'https' || uri.scheme == 'http') ||
      !uri.host.contains('.')) {
    return const ProfileLink(ProfileLinkKind.invalid);
  }
  return ProfileLink(kind, url: url, name: name, host: uri.host);
}
