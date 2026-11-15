import 'package:fl_clash/common/launch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const exe = r'C:\Program Files\RoutaMi\RoutaMi.exe';

  test('autostart quotes the path under Program Files', () {
    expect(
      autoLaunchCommand(exe, toTray: false),
      r'"C:\Program Files\RoutaMi\RoutaMi.exe"',
    );
  });

  test('autostart to tray launches lite mode', () {
    expect(
      autoLaunchCommand(exe, toTray: true),
      r'"C:\Program Files\RoutaMi\RoutaMi.exe" --lite',
    );
  });
}
