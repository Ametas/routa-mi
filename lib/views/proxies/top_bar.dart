import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common.dart';
import 'setting.dart';

/// The open groups the bolt tests: all of them while nothing is open.
List<Group> proxiesGroupsToTest({
  required List<Group> groups,
  required Set<String> unfold,
  required String query,
}) {
  final open = [
    for (final group in groups)
      if (query.isNotEmpty || unfold.contains(group.name)) group,
  ];
  return open.isEmpty ? groups : open;
}

/// The title row of the proxies page (design 3.1 "RoutaMi Proxies"):
/// search, a latency test of the open groups and the sort menu, which also
/// holds the page's providers and settings.
class ProxiesTopBar extends ConsumerStatefulWidget {
  const ProxiesTopBar({
    super.key,
    this.menuItems = const [],
    this.isLoading = false,
  });

  /// Shown under the sort options.
  final List<PopupMenuItemData> menuItems;
  final bool isLoading;

  @override
  ConsumerState<ProxiesTopBar> createState() => _ProxiesTopBarState();
}

class _ProxiesTopBarState extends ConsumerState<ProxiesTopBar> {
  final _query = TextEditingController();
  bool _searchOpen = false;
  bool _testing = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    ref.read(queryProvider(QueryTag.proxies).notifier).value = value;
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (!_searchOpen && _query.text.isNotEmpty) {
      _query.clear();
      _setQuery('');
    }
  }

  Future<void> _testOpenGroups() async {
    final state = ref.read(proxiesListStateProvider);
    final groups = proxiesGroupsToTest(
      groups: state.groups,
      unfold: state.currentUnfoldSet,
      query: ref.read(queryProvider(QueryTag.proxies)),
    );
    if (groups.isEmpty) return;
    setState(() => _testing = true);
    final seen = <String>{};
    try {
      await Future.wait([
        for (final group in groups)
          delayTest([
            for (final proxy in group.all)
              if (seen.add(proxy.name)) proxy,
          ], group.testUrl),
      ]);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _setSort(ProxiesSortType type) {
    ref
        .read(proxiesStyleSettingProvider.notifier)
        .update((state) => state.copyWith(sortType: type));
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    final sortType = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.sortType),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SurgeSpace.l,
        SurgeSpace.m,
        SurgeSpace.l,
        SurgeSpace.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.proxies,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.rootAppBarTitle.copyWith(
                    color: surge.textPrimary,
                  ),
                ),
              ),
              ProxyRoundAction(
                icon: SurgeIcons.search,
                tooltip: l10n.search,
                active: _searchOpen,
                onPressed: _toggleSearch,
              ),
              const SizedBox(width: SurgeSpace.s),
              ProxyRoundAction(
                icon: SurgeIcons.flashOn,
                tooltip: l10n.testOpenGroups,
                busy: _testing,
                onPressed: _testOpenGroups,
              ),
              const SizedBox(width: SurgeSpace.s),
              CommonPopupBox(
                popup: CommonPopupMenu(
                  items: [
                    for (final type in ProxiesSortType.values)
                      PopupMenuItemData(
                        icon: type == sortType
                            ? SurgeIcons.confirm
                            : ProxiesSetting.sortIcon(type),
                        label: ProxiesSetting.sortLabel(context, type),
                        onPressed: () => _setSort(type),
                      ),
                    ...widget.menuItems,
                  ],
                ),
                targetBuilder: (open) => ProxyRoundAction(
                  icon: SurgeIcons.sort,
                  tooltip: l10n.sort,
                  onPressed: () => open(
                    offset: const Offset(
                      ProxyGroupBits.action,
                      ProxyGroupBits.action + SurgeSpace.xs,
                    ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: SurgeMotion.container,
            curve: SurgeMotion.stateCurve,
            alignment: Alignment.topCenter,
            child: _searchOpen
                ? Padding(
                    padding: const EdgeInsets.only(top: SurgeSpace.m),
                    child: TextField(
                      controller: _query,
                      autofocus: true,
                      onChanged: _setQuery,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: l10n.searchNodes,
                        prefixIcon: const Icon(
                          SurgeIcons.search,
                          size: SurgeIconSize.inline,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          if (widget.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: SurgeSpace.s),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
