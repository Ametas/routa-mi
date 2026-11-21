import 'dart:async';

import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Makes [profileId] the current profile: the profiles list and the add
/// sheet's "Make current" share it.
void selectProfile(WidgetRef ref, int profileId) {
  if (profileId == ref.read(currentProfileIdProvider)) return;
  ref.read(providersProvider.notifier).clear();
  ref.read(groupsProvider.notifier).value = const [];
  ref.read(groupsOwnerProfileIdProvider.notifier).set(null);
  final proxies = ref.read(proxiesActionProvider.notifier);
  proxies.beginRuntimeProfileTransition(profileId);
  ref.read(currentProfileIdProvider.notifier).value = profileId;
  unawaited(() async {
    await proxies.hydrateProxyGroupsSnapshot();
    await proxies.ensureCurrentProfileReady(forceApply: true);
  }());
}
