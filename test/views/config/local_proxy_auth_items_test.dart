import 'package:fl_clash/common/local_proxy_auth.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/local_proxy_auth_items.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/component_catalog.dart';

void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        networkSettingProvider.overrideWithBuild(
          (_, _) => const NetworkProps(
            authentication: AuthenticationProps(
              username: 'routami',
              password: 'secret-pass',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: catalogApp(
          brightness: Brightness.light,
          textScale: 1,
          child: const SurgeSection(
            children: [
              AuthenticationItem(),
              AuthenticationAccountItem(),
              AuthenticationPasswordItem(),
              AuthenticationRegenerateItem(),
            ],
          ),
        ),
      ),
    );
    return container;
  }

  testWidgets('the password is hidden until revealed', (tester) async {
    await pump(tester);
    expect(find.text('routami'), findsOneWidget);
    expect(find.text('secret-pass'), findsNothing);
    await tester.tap(find.byIcon(SurgeIcons.visibility));
    await tester.pump();
    expect(find.text('secret-pass'), findsOneWidget);
  });

  testWidgets('turning authentication off asks first', (tester) async {
    final container = await pump(tester);
    await tester.tap(find.byType(SurgeSwitch));
    await tester.pumpAndSettle();
    // Cancel keeps it on.
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();
    expect(
      container.read(networkSettingProvider).authentication.enable,
      isTrue,
    );

    await tester.tap(find.byType(SurgeSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    final auth = container.read(networkSettingProvider).authentication;
    expect(auth.enable, isFalse);
    expect(auth.credentials, isEmpty);
  });

  testWidgets('regenerating replaces both values', (tester) async {
    final container = await pump(tester);
    await tester.tap(find.byIcon(SurgeIcons.refresh));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    final auth = container.read(networkSettingProvider).authentication;
    expect(auth.username, isNot('routami'));
    expect(auth.password, hasLength(LocalProxyAuth.passwordLength));
  });
}
