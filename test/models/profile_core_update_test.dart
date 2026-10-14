import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/enum/profile_core.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

ProfileSourceResponse response(String body) => ProfileSourceResponse(
  bytes: Uint8List.fromList(utf8.encode(body)),
  subscriptionInfo: const SubscriptionInfo(),
  fallbackLabel: null,
);

void main() {
  final profile = Profile.normal(label: 'Sub', url: 'https://x');
  final now = DateTime(2026);

  test('a JSON subscription runs on Xray whatever was picked', () {
    final merged = mergeRemoteProfileResponse(
      profile,
      response('[{"remarks": "JP", "outbounds": []}]'),
      updatedAt: now,
    );
    expect(merged.core, ProfileCore.xray);
  });

  test('a panel that switches back to YAML switches the core back', () {
    final merged = mergeRemoteProfileResponse(
      profile.copyWith(core: ProfileCore.xray),
      response('proxies: []\n'),
      updatedAt: now,
    );
    expect(merged.core, ProfileCore.mihomo);
  });

  test('content that cannot tell keeps the chosen core', () {
    final merged = mergeRemoteProfileResponse(
      profile.copyWith(core: ProfileCore.xray),
      response('vless://id@host:443#JP'),
      updatedAt: now,
    );
    expect(merged.core, ProfileCore.xray);
  });

  test('old backups without the field are mihomo profiles', () {
    final json = profile.toJson()..remove('core');
    expect(Profile.fromJson(json).core, ProfileCore.mihomo);
  });
}
