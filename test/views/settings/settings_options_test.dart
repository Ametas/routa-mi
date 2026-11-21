import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/views/settings/settings_options.dart';
import 'package:fl_clash/widgets/settings_unfold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('the mixed port keeps the port dialog checks', () {
    String? check(String value) =>
        validateMixedPort(value, l10n: l10n, otherPorts: const [7891]);
    expect(check(''), l10n.emptyTip(l10n.mixedPort));
    expect(check('port'), l10n.numberTip(l10n.mixedPort));
    expect(check('80'), l10n.portTip(l10n.mixedPort));
    expect(check('7891'), l10n.portConflictTip);
    expect(check('7890'), isNull);
  });

  test('a section sums up its values and skips the ones at rest', () {
    final options = <UnfoldOption>[
      UnfoldChoice<String>(
        'Mode',
        values: const ['Auto', 'Dark'],
        value: 'Dark',
        labelOf: (v) => v,
        onChanged: (_) {},
      ),
      UnfoldSwitch('AMOLED', value: true, onChanged: (_) {}),
      UnfoldSwitch('Off', value: false, onChanged: (_) {}),
      UnfoldChoice<double>(
        'Text size',
        values: settingsTextScales,
        value: 0,
        labelOf: (v) => '$v',
        summaryOf: (v) => v == 0 ? null : '$v',
        onChanged: (_) {},
      ),
      UnfoldField(
        'Test url',
        value: 'https://www.gstatic.com/generate_204',
        validator: (_) => null,
        onSubmitted: (_) {},
      ),
      UnfoldLink('All settings', onTap: () {}),
    ];
    expect(
      unfoldSummary(options),
      'Dark · AMOLED · www.gstatic.com/generate_204',
    );
  });
}
