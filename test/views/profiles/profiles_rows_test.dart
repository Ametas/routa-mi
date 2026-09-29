import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/views.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/component_catalog.dart';

void main() {
  testWidgets('current profile rows render through SurgeRow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(384, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    globalState.container = ProviderContainer();
    addTearDown(globalState.container.dispose);
    await tester.pumpWidget(
      catalogApp(
        brightness: Brightness.light,
        textScale: 1,
        overrides: [
          profilesProvider.overrideWithBuild(
            (_, _) => const [
              Profile(
                id: 1,
                label: 'Home',
                url: 'https://example.com/home',
                autoUpdateDuration: Duration(hours: 12),
              ),
            ],
          ),
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        ],
        child: const SizedBox(height: 850, child: ProfilesView()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    for (final label in ['Media check', 'Show profile nodes']) {
      expect(
        find.ancestor(of: find.text(label), matching: find.byType(SurgeRow)),
        findsOneWidget,
        reason: '$label should render through SurgeRow',
      );
    }

    // Expanding loads the profile's proxies from disk, so only check that
    // the row is enabled and wired rather than tapping it here.
    final expand = tester.widget<SurgeRow>(
      find.ancestor(
        of: find.text('Show profile nodes'),
        matching: find.byType(SurgeRow),
      ),
    );
    expect(expand.enabled, isTrue);
    expect(expand.onTap, isNotNull);
    expect(expand.minTileHeight, 52);
  });
}
