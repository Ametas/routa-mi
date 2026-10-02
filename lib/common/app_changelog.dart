class AppChangelogEntry {
  const AppChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });

  final String version;
  final String date;
  final List<String> changes;
}

/// RoutaMi release notes, newest first. Items are ARB keys resolved by
/// `AppChangelogDialog`; the SlClash history (v2.x) is not carried over.
const appChangelogEntries = <AppChangelogEntry>[
  AppChangelogEntry(
    version: 'v0.1.0',
    date: '',
    changes: [
      'changelog010Item1',
      'changelog010Item2',
      'changelog010Item3',
      'changelog010Item4',
    ],
  ),
];

const lastShownChangelogVersionKey = 'lastShownChangelogVersion';

bool shouldShowChangelogAfterUpdate({
  required bool wasUpdated,
  required String? lastShownVersion,
  List<AppChangelogEntry> entries = appChangelogEntries,
}) {
  if (!wasUpdated || entries.isEmpty) return false;
  return lastShownVersion != entries.first.version;
}
