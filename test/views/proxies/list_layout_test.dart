import 'package:fl_clash/views/proxies/list_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('large expanded groups and collapsed groups retain row boundaries', () {
    final layout = ProxyListLayout(
      nodeCounts: [10000, 0, 3],
      headerHeight: 40,
      nodeHeight: 60,
    );
    expect(layout.rowCount, 10006);
    expect(layout.headerOffsets, [0, 600040, 600080]);
    expect(layout.rowAt(0), (groupIndex: 0, proxyIndex: -1));
    expect(layout.rowAt(10000), (groupIndex: 0, proxyIndex: 9999));
    expect(layout.rowAt(10001), (groupIndex: 1, proxyIndex: -1));
    expect(layout.rowAt(10002), (groupIndex: 2, proxyIndex: -1));
    expect(layout.rowAt(10005), (groupIndex: 2, proxyIndex: 2));
    expect(() => layout.rowAt(10006), throwsRangeError);
  });

  test('cards keep gaps, notices and grid rows apart', () {
    final layout = ProxyListLayout(
      nodeCounts: [5, 0, 2],
      notices: [false, false, true],
      headerHeight: 60,
      nodeHeight: 40,
      groupGap: 10,
      columns: 2,
      noticeHeight: 30,
      groupFooter: 4,
    );
    // Group 0: header + 3 grid rows; group 1: header; group 2: header,
    // notice and one grid row.
    expect(layout.rowCount, 4 + 1 + 3);
    expect(layout.headerOffsets, [0, 60 + 120 + 4 + 10, 194 + 60 + 10]);
    expect(layout.rowAt(3), (groupIndex: 0, proxyIndex: 2));
    expect(layout.rowAt(5), (
      groupIndex: 2,
      proxyIndex: ProxyListLayout.header,
    ));
    expect(layout.rowAt(6), (
      groupIndex: 2,
      proxyIndex: ProxyListLayout.notice,
    ));
    expect(layout.rowAt(7), (groupIndex: 2, proxyIndex: 0));
    expect(
      [for (var i = 0; i < layout.rowCount; i++) layout.extentAt(i)],
      [60, 40, 40, 44, 70, 70, 30, 44],
    );
    expect(layout.isLastOfGroup(1, ProxyListLayout.header), isTrue);
    expect(layout.isLastOfGroup(2, ProxyListLayout.notice), isFalse);
    expect(layout.isLastOfGroup(2, 0), isTrue);
  });
}
