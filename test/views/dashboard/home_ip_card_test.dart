import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widgets/home_ip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/component_catalog.dart';

void main() {
  test('a two-letter country code becomes its flag', () {
    expect(countryFlag('pl'), '🇵🇱');
    expect(countryFlag('DE'), '🇩🇪');
    expect(countryFlag('EU1'), 'EU1');
    expect(countryFlag(''), '');
  });

  test('the card shows the address first, then a check in progress', () {
    const ip = IpInfo(ip: '51.68.141.9', countryCode: 'PL');
    expect(
      homeIpStatus(const NetworkDetectionState(isLoading: true, ipInfo: ip)),
      HomeIpStatus.shown,
    );
    expect(
      homeIpStatus(const NetworkDetectionState(isLoading: true, ipInfo: null)),
      HomeIpStatus.checking,
    );
    expect(
      homeIpStatus(
        const NetworkDetectionState(
          isLoading: false,
          ipInfo: null,
          hasChecked: true,
        ),
      ),
      HomeIpStatus.failed,
    );
    expect(
      homeIpStatus(const NetworkDetectionState(isLoading: false, ipInfo: null)),
      HomeIpStatus.idle,
    );
  });

  Widget host(NetworkDetectionState state) => catalogApp(
    brightness: Brightness.dark,
    textScale: 1,
    overrides: [networkDetectionProvider.overrideWithBuild((_, _) => state)],
    child: const HomeIpCard(),
  );

  testWidgets('the card shows where traffic leaves from', (tester) async {
    await tester.pumpWidget(
      host(
        const NetworkDetectionState(
          isLoading: false,
          ipInfo: IpInfo(ip: '51.68.141.9', countryCode: 'pl'),
          hasChecked: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('External IP'), findsOneWidget);
    expect(find.text('🇵🇱'), findsOneWidget);
    expect(find.text('PL'), findsOneWidget);
    expect(find.text('51.68.141.9'), findsOneWidget);
  });

  testWidgets('a failed check says so and can be retried', (tester) async {
    await tester.pumpWidget(
      host(
        const NetworkDetectionState(
          isLoading: false,
          ipInfo: null,
          hasChecked: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Timeout'), findsOneWidget);
    expect(find.byTooltip('Check the external IP again'), findsOneWidget);
  });
}
