/// Indexes only group boundaries; nodes are materialized by the viewport.
///
/// Each group is one card: a header row, an optional notice row (an
/// automatic group pinned by hand) and its node rows. With [columns] above
/// one a node row holds that many nodes side by side. [groupGap] belongs to
/// the header row of every group after the first; [headerOffsets] point at
/// the header itself, below the gap. [groupFooter] pads the last row of a
/// group that has rows.
class ProxyListLayout {
  ProxyListLayout({
    required List<int> nodeCounts,
    required this.headerHeight,
    required this.nodeHeight,
    this.groupGap = 0,
    this.columns = 1,
    List<bool>? notices,
    this.noticeHeight = 0,
    this.groupFooter = 0,
  }) : assert(columns > 0) {
    var offset = 0.0;
    for (final (index, count) in nodeCounts.indexed) {
      final notice = notices != null && notices[index];
      final rows = (count + columns - 1) ~/ columns;
      final gap = index == 0 ? 0.0 : groupGap;
      _starts.add(rowCount);
      _notices.add(notice);
      _rows.add(rows);
      headerOffsets.add(offset + gap);
      rowCount += 1 + (notice ? 1 : 0) + rows;
      offset +=
          gap +
          headerHeight +
          (notice ? noticeHeight : 0) +
          rows * nodeHeight +
          (notice || rows > 0 ? groupFooter : 0);
    }
  }

  /// [rowAt] returns this proxy index for a header row.
  static const header = -1;

  /// [rowAt] returns this proxy index for a notice row.
  static const notice = -2;

  final double headerHeight;
  final double nodeHeight;
  final double groupGap;
  final int columns;
  final double noticeHeight;
  final double groupFooter;

  final _starts = <int>[];
  final _notices = <bool>[];
  final _rows = <int>[];
  final headerOffsets = <double>[];
  int rowCount = 0;

  /// The group and what the row shows: [header], [notice] or the index of
  /// the node row (the node index itself when [columns] is one).
  ({int groupIndex, int proxyIndex}) rowAt(int index) {
    RangeError.checkValidIndex(index, this, 'index', rowCount);
    var low = 0;
    var high = _starts.length;
    while (low + 1 < high) {
      final mid = (low + high) ~/ 2;
      if (_starts[mid] <= index) {
        low = mid;
      } else {
        high = mid;
      }
    }
    final local = index - _starts[low];
    if (local == 0) return (groupIndex: low, proxyIndex: header);
    if (_notices[low]) {
      if (local == 1) return (groupIndex: low, proxyIndex: notice);
      return (groupIndex: low, proxyIndex: local - 2);
    }
    return (groupIndex: low, proxyIndex: local - 1);
  }

  bool hasNotice(int groupIndex) => _notices[groupIndex];

  int rowsOf(int groupIndex) => _rows[groupIndex];

  /// Whether the row ends its group's card.
  bool isLastOfGroup(int groupIndex, int proxyIndex) {
    final rows = _rows[groupIndex];
    if (proxyIndex == header) return rows == 0 && !_notices[groupIndex];
    if (proxyIndex == notice) return rows == 0;
    return proxyIndex == rows - 1;
  }

  double extentAt(int index) {
    final row = rowAt(index);
    final footer =
        isLastOfGroup(row.groupIndex, row.proxyIndex) &&
            row.proxyIndex != header
        ? groupFooter
        : 0.0;
    return switch (row.proxyIndex) {
      header => headerHeight + (row.groupIndex == 0 ? 0 : groupGap),
      notice => noticeHeight + footer,
      _ => nodeHeight + footer,
    };
  }
}
