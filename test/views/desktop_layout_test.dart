import 'package:fl_clash/views/desktop_layout.dart';
import 'package:fl_clash/views/profiles/add_profile_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pages split into two panes only when they get the room', () {
    expect(DesktopLayout.twoPane(384), isFalse);
    expect(DesktopLayout.twoPane(DesktopLayout.twoPaneMinWidth - 1), isFalse);
    expect(DesktopLayout.twoPane(DesktopLayout.twoPaneMinWidth), isTrue);
    expect(DesktopLayout.twoPane(1100), isTrue);
  });

  test('adding a profile is a dialog in a wide window, a sheet on phones', () {
    expect(AddProfileSheet.asDialog(412), isFalse);
    expect(AddProfileSheet.asDialog(1160), isTrue);
  });
}
