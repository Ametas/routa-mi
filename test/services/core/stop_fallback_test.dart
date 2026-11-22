import 'package:fl_clash/services/core/stop_fallback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows stops by replacing the core, as Clash Verge does', () {
    expect(stopByReplacingCore(isWindows: true), isTrue);
    expect(stopByReplacingCore(isWindows: false), isFalse);
  });

  test('a working core gets far longer than it needs to confirm', () {
    expect(
      coreStopConfirmTimeout,
      greaterThanOrEqualTo(const Duration(seconds: 5)),
    );
  });
}
