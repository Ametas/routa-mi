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
    version: 'v0.6.1',
    date: '',
    changes: ['changelog061Item1', 'changelog061Item2', 'changelog061Item3'],
  ),
  AppChangelogEntry(
    version: 'v0.6.0',
    date: '',
    changes: [
      'changelog060Item1',
      'changelog060Item2',
      'changelog060Item3',
      'changelog060Item4',
      'changelog060Item5',
    ],
  ),
  AppChangelogEntry(
    version: 'v0.5.1',
    date: '',
    changes: ['changelog051Item1', 'changelog051Item2', 'changelog051Item3'],
  ),
  AppChangelogEntry(
    version: 'v0.5.0',
    date: '',
    changes: [
      'changelog050Item1',
      'changelog050Item2',
      'changelog050Item3',
      'changelog050Item4',
    ],
  ),
  AppChangelogEntry(
    version: 'v0.4.0',
    date: '',
    changes: ['changelog040Item1', 'changelog040Item2', 'changelog040Item3'],
  ),
  AppChangelogEntry(
    version: 'v0.3.0',
    date: '',
    changes: ['changelog030Item1', 'changelog030Item2', 'changelog030Item3'],
  ),
  AppChangelogEntry(
    version: 'v0.2.0',
    date: '',
    changes: [
      'changelog020Item1',
      'changelog020Item2',
      'changelog020Item3',
      'changelog020Item4',
      'changelog020Item5',
    ],
  ),
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
