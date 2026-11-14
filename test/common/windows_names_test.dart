import 'dart:io';

import 'package:fl_clash/common/constant.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Windows app, the helper service (core/helper) and the build tool must
/// agree on file names and the helper port; a mismatch silently leaves the
/// app without a core.
void main() {
  test('the app uses the helper and core names the Go side builds', () {
    final helper = File('core/helper/helper.go').readAsStringSync();
    final service = File('core/helper/helper_windows.go').readAsStringSync();
    final builder = File(
      'plugins/setup/buildkit/build_tool/lib/src/windows_builder.dart',
    ).readAsStringSync();
    expect(helper, contains('listenAddr  = "127.0.0.1:$helperPort"'));
    expect(helper, contains('coreExeName = "$coreExecutableName.exe"'));
    expect(helper, contains('appExeName  = "$appName.exe"'));
    expect(service, contains('serviceName = "$appHelperService"'));
    expect(builder, contains("coreName = '$coreExecutableName.exe'"));
    expect(builder, contains("helperName = '$appHelperService.exe'"));
  });
}
