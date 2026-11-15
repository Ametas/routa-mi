import 'package:fl_clash/common/windows_tun.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a core the helper started can turn TUN on', () {
    expect(
      tunAuthorizationWithService(coreUnderHelper: true, helperError: null),
      AuthorizeCode.none,
    );
  });

  test('a core started before the service is restarted through it', () {
    expect(
      tunAuthorizationWithService(coreUnderHelper: false, helperError: null),
      AuthorizeCode.success,
    );
  });

  test('a core the service refused keeps TUN off', () {
    // Before, the app ran its own core without rights and reported TUN on.
    expect(
      tunAuthorizationWithService(
        coreUnderHelper: false,
        helperError: 'core hash abc does not match def',
      ),
      AuthorizeCode.error,
    );
  });
}
