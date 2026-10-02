import 'package:fl_clash/common/local_proxy_auth.dart';
import 'package:fl_clash/common/local_vless.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/local_vless_items.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/component_catalog.dart';

const _uuid = '3b2f8a5e-6f0c-4d1e-9a7b-2c4d6e8f0a1b';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    LocalVlessProps vless = const LocalVlessProps(enable: true, uuid: _uuid),
  }) async {
    final container = ProviderContainer(
      overrides: [
        networkSettingProvider.overrideWithBuild(
          (_, _) => NetworkProps(localVless: vless),
        ),
      ],
    );
    addTearDown(container.dispose);
    keepLocalProxyCredentials(container);
    globalState.container = container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: catalogApp(
          brightness: Brightness.light,
          textScale: 1,
          child: const SurgeSection(
            children: [
              LocalVlessItem(),
              LocalVlessPortItem(),
              LocalVlessUuidItem(),
              LocalVlessLinkItem(),
              LocalVlessRegenerateItem(),
            ],
          ),
        ),
      ),
    );
    return container;
  }

  testWidgets('turning the inbound on fills in a UUID', (tester) async {
    final container = await pump(tester, vless: const LocalVlessProps());
    await tester.tap(find.byType(SurgeSwitch));
    await tester.pumpAndSettle();
    final vless = container.read(networkSettingProvider).localVless;
    expect(vless.enable, isTrue);
    expect(LocalVless.uuidPattern.hasMatch(vless.uuid), isTrue);
  });

  testWidgets('the UUID is hidden until revealed', (tester) async {
    await pump(tester);
    expect(find.text('127.0.0.1:$defaultLocalVlessPort'), findsOneWidget);
    expect(find.text(_uuid), findsNothing);
    await tester.tap(find.byIcon(SurgeIcons.visibility));
    await tester.pumpAndSettle();
    expect(find.text(_uuid), findsOneWidget);
  });

  testWidgets('copy link puts the share link on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester);
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(
      copied,
      const LocalVlessProps(enable: true, uuid: _uuid).shareLink(),
    );
  });

  testWidgets('regenerating replaces the UUID after confirming', (
    tester,
  ) async {
    final container = await pump(tester);
    await tester.tap(find.byIcon(SurgeIcons.refresh));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    final uuid = container.read(networkSettingProvider).localVless.uuid;
    expect(uuid, isNot(_uuid));
    expect(LocalVless.uuidPattern.hasMatch(uuid), isTrue);
  });
}
