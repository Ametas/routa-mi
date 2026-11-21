import 'package:flutter/foundation.dart';

/// A node or group name split into the emoji shown as its icon and the
/// title shown beside it.
@immutable
class ProxyNameParts {
  const ProxyNameParts(this.icon, this.title);

  /// The flag or symbol for the icon tile; null when the name has none.
  final String? icon;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is ProxyNameParts && other.icon == icon && other.title == title;

  @override
  int get hashCode => Object.hash(icon, title);

  @override
  String toString() => 'ProxyNameParts($icon, $title)';
}

// A flag: two regional indicators, or a subdivision flag (🏴 + tag letters).
final _flag = RegExp(
  r'^(?:[\u{1F1E6}-\u{1F1FF}]{2}|\u{1F3F4}[\u{E0061}-\u{E007A}]+\u{E007F})$',
  unicode: true,
);

// Words: Latin, Cyrillic or digits never form a prefix ("A1", "В", "5G").
final _word = RegExp(
  r'[\p{Script=Latin}\p{Script=Cyrillic}\p{N}]',
  unicode: true,
);

/// Leading tokens like "★", "ϟ", "◈", "≋" or a flag, separated by spaces.
bool _isPrefixToken(String token) =>
    token.isNotEmpty && token.runes.length <= 8 && !_word.hasMatch(token);

/// Splits the emoji prefix of [name] off for an icon tile, the way
/// subscriptions name their nodes ("★ 🇩🇪 Emerald", "◈ Auto"):
/// - a flag among the leading tokens becomes the icon and leaves the title,
///   other symbols stay ("★ 🇩🇪 Emerald" → 🇩🇪, "★ Emerald");
/// - with no flag, the first leading symbol becomes the icon
///   ("◈ Auto" → ◈, "Auto");
/// - a name without a prefix, or with nothing after it, keeps its title.
ProxyNameParts splitProxyNameIcon(String name) {
  final tokens = name.trim().split(RegExp(r'\s+'));
  var prefix = 0;
  while (prefix < tokens.length - 1 &&
      prefix < 3 &&
      _isPrefixToken(tokens[prefix])) {
    prefix++;
  }
  if (prefix == 0) return ProxyNameParts(null, name);
  final flagIndex = tokens.take(prefix).toList().indexWhere(_flag.hasMatch);
  final iconIndex = flagIndex >= 0 ? flagIndex : 0;
  final icon = tokens[iconIndex];
  final title = [...tokens]..removeAt(iconIndex);
  return ProxyNameParts(icon, title.join(' '));
}
