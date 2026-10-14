import 'package:fl_clash/common/user_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('panels recognise the client from the start of the User-Agent', () {
    final ua = subscriptionUserAgent(
      appName: 'RoutaMi',
      appVersion: '0.1.0',
      platform: 'android',
      mihomoVersion: 'v1.19.31',
    );
    expect(ua, 'mihomo/v1.19.31 clash-verge RoutaMi/v0.1.0 Platform/android');
    // Typical panel rules (Marzban, Remnawave) are anchored at the start.
    expect(RegExp(r'^([Cc]lash-verge|[Mm]ihomo)').hasMatch(ua), isTrue);
    expect(ua, contains('clash'));
  });

  test('a build without the core version still names the core', () {
    final ua = subscriptionUserAgent(
      appName: 'RoutaMi',
      appVersion: '0.1.0',
      platform: 'android',
      mihomoVersion: '',
    );
    expect(ua, startsWith('mihomo clash-verge RoutaMi/v0.1.0'));
  });
}
