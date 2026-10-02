import 'package:fl_clash/common/app_changelog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the changelog is RoutaMi\'s own, starting at v0.1.0', () {
    expect(appChangelogEntries.first.version, 'v0.1.0');
    expect(appChangelogEntries.first.changes, [
      'changelog010Item1',
      'changelog010Item2',
      'changelog010Item3',
      'changelog010Item4',
    ]);
    expect(
      appChangelogEntries.map((entry) => entry.version),
      everyElement(isNot(startsWith('v2.'))),
      reason: 'SlClash release history is not carried over',
    );
  });

  test('fresh installs do not show the changelog automatically', () {
    expect(
      shouldShowChangelogAfterUpdate(wasUpdated: false, lastShownVersion: null),
      isFalse,
    );
  });

  test('an updated install shows the latest changelog once', () {
    expect(
      shouldShowChangelogAfterUpdate(wasUpdated: true, lastShownVersion: null),
      isTrue,
    );
    expect(
      shouldShowChangelogAfterUpdate(
        wasUpdated: true,
        lastShownVersion: appChangelogEntries.first.version,
      ),
      isFalse,
    );
  });
}
