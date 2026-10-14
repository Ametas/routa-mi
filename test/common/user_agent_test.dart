import 'package:fl_clash/common/user_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app comes first, then the active core', () {
    expect(
      subscriptionUserAgent(appVersion: '0.1.0', coreVersion: 'v1.19.31'),
      'RoutaMi/0.1.0 mihomo/1.19.31',
    );
    expect(
      subscriptionUserAgent(
        appVersion: '0.1.0',
        coreName: 'xray',
        coreVersion: '25.10.15',
      ),
      'RoutaMi/0.1.0 xray/25.10.15',
    );
  });

  test('a build without the core version still names the core', () {
    expect(
      subscriptionUserAgent(appVersion: '0.1.0', coreVersion: ''),
      'RoutaMi/0.1.0 mihomo',
    );
  });
}
