import 'package:fl_clash/common/profile_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a https address is a subscription', () {
    final link = parseProfileLink('  https://sub.routa.example/s/7f3a9c ');
    expect(link.kind, ProfileLinkKind.subscription);
    expect(link.url, 'https://sub.routa.example/s/7f3a9c');
    expect(link.host, 'sub.routa.example');
    expect(link.isValid, isTrue);
    expect(link.plainHttp, isFalse);
  });

  test('a clash:// link gives its address and name', () {
    final link = parseProfileLink(
      'clash://install-config?url=https%3A%2F%2Fvpn.example.net%2Fclash%2Fhome&name=Home',
    );
    expect(link.kind, ProfileLinkKind.clash);
    expect(link.url, 'https://vpn.example.net/clash/home');
    expect(link.name, 'Home');
    expect(link.host, 'vpn.example.net');
  });

  test('plain http is accepted and flagged', () {
    final link = parseProfileLink('http://10.0.0.2.nip.io/sub');
    expect(link.isValid, isTrue);
    expect(link.plainHttp, isTrue);
  });

  test('node links, broken clash links and text are told apart', () {
    expect(parseProfileLink('').kind, ProfileLinkKind.empty);
    expect(
      parseProfileLink('vless://uuid@host:443?security=reality').kind,
      ProfileLinkKind.node,
    );
    expect(
      parseProfileLink('ss://YWVz@1.2.3.4:8388').kind,
      ProfileLinkKind.node,
    );
    expect(
      parseProfileLink('clash://install-config?name=x').kind,
      ProfileLinkKind.clashWithoutUrl,
    );
    expect(parseProfileLink('my subscription').kind, ProfileLinkKind.invalid);
    expect(
      parseProfileLink('https://localhost/sub').kind,
      ProfileLinkKind.invalid,
    );
  });
}
