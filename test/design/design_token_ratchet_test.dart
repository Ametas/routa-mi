// Design-token ratchet: raw visual literals (spacing, radii, colours,
// alpha, shadows, durations, icon sizes) may only go down.
//
// The per-file counts are frozen in design_token_baseline.json. A change
// that adds a literal fails; a change that removes some must lower the
// baseline in the same commit so the gain cannot silently come back:
//
//   UPDATE_DESIGN_BASELINE=1 flutter test test/design/design_token_ratchet_test.dart
//
// Token definitions live in the excluded files below; everything else
// should use SurgeSpace, SurgeIconSize, surge.radii, SurgeTheme colours,
// SurgeOpacity, SurgeShadows and SurgeMotion.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baselinePath = 'test/design/design_token_baseline.json';
const _testPath = 'test/design/design_token_ratchet_test.dart';

const _excluded = <String>{
  'lib/widgets/surge/surge_tokens.dart',
  'lib/widgets/surge/surge_motion.dart',
  'lib/widgets/surge/surge_theme_extension.dart',
  'lib/widgets/surge/surge_shadows.dart',
};

const _excludedPrefixes = <String>['lib/theme/', 'lib/l10n/'];

final _categories = <String, RegExp>{
  'spacing': RegExp(
    r'EdgeInsets(?:Directional)?\.(?:all|symmetric|only|fromLTRB|fromSTEB)\([^()]*?(?<![\w.])(?:[1-9]\d*(?:\.\d+)?|0\.\d+)\b',
  ),
  'gap': RegExp(
    r'SizedBox\(\s*(?:width|height):\s*(?:[1-9]\d*(?:\.\d+)?|0\.\d+)\b',
  ),
  'radius': RegExp(r'Radius\.circular\(\s*\d'),
  'color': RegExp(r'Color\(0x|Colors\.(?!transparent\b)[a-z]\w*'),
  'alpha': RegExp(
    r'with(?:Values\(\s*alpha:|Opacity\(|Alpha\()(?:[^,()]*?[?:])?\s*\d',
  ),
  'shadow': RegExp(r'BoxShadow\('),
  // Motion only: durations handed to animations, routes and snackbars.
  // Timers, timeouts and debounce windows (`}, duration: …` calls) are logic.
  'duration': RegExp(
    r'(?<!\}, )\b(?:duration|reverseDuration|transitionDuration|'
    r'reverseTransitionDuration)\b\s*(?::|=>|=)\s*(?:const\s+)?'
    r'(?:Duration\(|(?:commonDuration|midDuration|animateDuration|moreDuration)\b)',
  ),
  'iconSize': RegExp(
    r'(?:\bIcon\((?:[^()]|\([^()]*\))*?\bsize:\s*\d)|(?:\biconSize:\s*\d)',
  ),
};

String _stripComments(String source) {
  return source
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');
}

Map<String, Map<String, int>> _scan() {
  final result = <String, Map<String, int>>{};
  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path.replaceAll(r'\', '/'))
          .where((path) => path.endsWith('.dart'))
          .where((path) => !path.contains('/generated/'))
          .where((path) => !_excluded.contains(path))
          .where((path) => !_excludedPrefixes.any(path.startsWith))
          .toList()
        ..sort();
  for (final path in files) {
    final source = _stripComments(File(path).readAsStringSync());
    final counts = <String, int>{};
    for (final MapEntry(key: category, value: pattern) in _categories.entries) {
      final count = pattern.allMatches(source).length;
      if (count > 0) {
        counts[category] = count;
      }
    }
    if (counts.isNotEmpty) {
      result[path] = counts;
    }
  }
  return result;
}

void main() {
  test('raw design literals never increase', () {
    final current = _scan();
    final baselineFile = File(_baselinePath);

    if (Platform.environment['UPDATE_DESIGN_BASELINE'] == '1') {
      baselineFile.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(current)}\n',
      );
      return;
    }

    expect(
      baselineFile.existsSync(),
      isTrue,
      reason: 'Missing $_baselinePath; run with UPDATE_DESIGN_BASELINE=1.',
    );
    final baseline = (jsonDecode(baselineFile.readAsStringSync()) as Map).map(
      (file, counts) => MapEntry(
        file as String,
        (counts as Map).map(
          (category, count) => MapEntry(category as String, count as int),
        ),
      ),
    );

    final increased = <String>[];
    final decreased = <String>[];
    final files = {...baseline.keys, ...current.keys}.toList()..sort();
    for (final file in files) {
      final before = baseline[file] ?? const <String, int>{};
      final after = current[file] ?? const <String, int>{};
      for (final category in _categories.keys) {
        final was = before[category] ?? 0;
        final now = after[category] ?? 0;
        if (now > was) {
          increased.add('$file: $category $was -> $now');
        } else if (now < was) {
          decreased.add('$file: $category $was -> $now');
        }
      }
    }

    expect(
      increased,
      isEmpty,
      reason:
          'New raw design literals; use SurgeSpace / SurgeIconSize / '
          'surge.radii / SurgeTheme colours / SurgeOpacity / SurgeShadows / '
          'SurgeMotion instead:\n${increased.join('\n')}',
    );
    expect(
      decreased,
      isEmpty,
      reason:
          'Raw design literals went down — lock the gain in by running\n'
          '  UPDATE_DESIGN_BASELINE=1 flutter test $_testPath\n'
          '${decreased.join('\n')}',
    );
  });

  test('ratchet patterns match what they are meant to', () {
    int count(String category, String source) =>
        _categories[category]!.allMatches(source).length;

    expect(count('spacing', 'EdgeInsets.all(16)'), 1);
    expect(count('spacing', 'EdgeInsets.all(SurgeSpace.l)'), 0);
    expect(count('spacing', 'EdgeInsets.symmetric(horizontal: 0)'), 0);
    expect(count('gap', 'SizedBox(height: 8)'), 1);
    expect(count('gap', 'SizedBox(width: SurgeSpace.s)'), 0);
    expect(count('radius', 'BorderRadius.circular(12)'), 1);
    expect(count('radius', 'BorderRadius.circular(surge.radii.card)'), 0);
    expect(count('color', 'Colors.white'), 1);
    expect(count('color', 'Colors.transparent'), 0);
    expect(count('color', 'Color(0xFF000000)'), 1);
    expect(count('alpha', 'c.withValues(alpha: 0.4)'), 1);
    expect(count('alpha', 'c.withValues(alpha: opacity.muted)'), 0);
    expect(count('alpha', 'c.withValues(alpha: on ? 0.2 : SurgeAlpha.a12)'), 1);
    expect(count('alpha', 'c.withValues(alpha: on ? x : 0.2)'), 1);
    expect(
      count(
        'alpha',
        'c.withValues(alpha: on ? SurgeAlpha.a24 : SurgeAlpha.a12)',
      ),
      0,
    );
    expect(count('shadow', 'BoxShadow(blurRadius: 4)'), 1);
    expect(count('duration', 'duration: const Duration(milliseconds: 200)'), 1);
    expect(count('duration', 'SurgeMotion.state'), 0);
    expect(count('duration', 'duration: SurgeMotion.state'), 0);
    expect(count('duration', 'duration: commonDuration,'), 1);
    expect(
      count('duration', 'Duration get transitionDuration => const Duration('),
      1,
    );
    expect(count('duration', 'Timer(const Duration(seconds: 2), f)'), 0);
    expect(count('duration', '}, duration: const Duration(seconds: 1));'), 0);
    expect(count('iconSize', 'Icon(SurgeIcons.add, size: 20)'), 1);
    expect(
      count('iconSize', 'Icon(SurgeIcons.add, size: SurgeIconSize.regular)'),
      0,
    );
    expect(count('iconSize', 'IconButton(iconSize: 24)'), 1);
  });
}
