import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The updater dialog lists every "- " line of the GitHub Release body
  // (utils.parseReleaseBody); release.yml builds that body from these files.
  test('release notes are bullet lists the update dialog can show', () {
    final files = Directory('docs/releases')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.md'))
        .toList();
    expect(files, isNotEmpty);
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      expect(name, matches(RegExp(r'^v\d+\.\d+\.\d+\.md$')));
      final lines = file
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty)
          .toList();
      expect(lines, everyElement(startsWith('- ')), reason: name);
      expect(
        utils.parseReleaseBody(file.readAsStringSync()),
        hasLength(lines.length),
      );
    }
  });
}
