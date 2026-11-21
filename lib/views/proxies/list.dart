import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/services/providers/provider_readiness_service.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';
import 'common.dart';
import 'empty.dart';
import 'list_layout.dart';
import 'list_metrics.dart';
import 'scrolling_label.dart';

class ProxiesListView extends StatefulWidget {
  const ProxiesListView({super.key});

  @override
  State<ProxiesListView> createState() => _ProxiesListViewState();
}

class _ProxiesListViewState extends State<ProxiesListView> {
  final _controller = ScrollController();
  final _labelPlaybackCoordinator = ProxyLabelPlaybackCoordinator();
  final _headerStateNotifier = ValueNotifier<ProxiesListHeaderSelectorState?>(
    null,
  );
  List<double> _headerOffset = [];
  List<Group> _groups = [];
  double _headerHeight = 0;
  double containerHeight = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_adjustHeader);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjustHeader();
    });
  }

  ProxiesListHeaderSelectorState _getProxiesListHeaderSelectorState(
    double initOffset,
  ) {
    final index = _headerOffset.findInterval(initOffset);
    final currentIndex = index;
    double headerOffset = 0.0;
    if (index + 1 <= _headerOffset.length - 1) {
      final endOffset = _headerOffset[index + 1];
      final startOffset = endOffset - _headerHeight;
      if (initOffset > startOffset && initOffset < endOffset) {
        headerOffset = initOffset - startOffset;
      }
    }
    return ProxiesListHeaderSelectorState(
      offset: max(headerOffset, 0),
      currentIndex: currentIndex,
    );
  }

  void _adjustHeader() {
    _headerStateNotifier.value = _getProxiesListHeaderSelectorState(
      !_controller.hasClients ? 0 : _controller.offset,
    );
  }

  @override
  void dispose() {
    _labelPlaybackCoordinator.dispose();
    _headerStateNotifier.dispose();
    _controller.removeListener(_adjustHeader);
    _controller.dispose();
    super.dispose();
  }

  bool _onUserScroll(UserScrollNotification notification) {
    if (notification.direction != ScrollDirection.idle) {
      _labelPlaybackCoordinator.cancelActive();
    }
    return false;
  }

  void _handleChange(String groupName) {
    _labelPlaybackCoordinator.requestReplayFor(groupName);
    _autoScrollToGroup(groupName);
    final tempUnfoldSet = Set<String>.from(
      globalState.container.read(unfoldSetProvider),
    );
    if (tempUnfoldSet.contains(groupName)) {
      tempUnfoldSet.remove(groupName);
    } else {
      tempUnfoldSet.add(groupName);
    }
    updateCurrentUnfoldSet(tempUnfoldSet);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjustHeader();
    });
  }

  bool _shouldShowStickyHeader({required int index, required bool expanded}) {
    if (!_controller.hasClients ||
        index < 0 ||
        index >= _headerOffset.length ||
        _controller.offset <= _headerOffset[index] + 0.5) {
      return false;
    }
    return expanded;
  }

  Widget _buildRow(
    ProxyListLayout layout,
    int index, {
    required List<Group> groups,
    required bool Function(Group group) expanded,
    required bool grid,
  }) {
    final row = layout.rowAt(index);
    final group = groups[row.groupIndex];
    final last = layout.isLastOfGroup(row.groupIndex, row.proxyIndex);
    if (row.proxyIndex == ProxyListLayout.header) {
      return Padding(
        key: ValueKey(group.name),
        padding: EdgeInsets.only(
          top: row.groupIndex == 0 ? 0 : ProxyListMetrics.groupGap,
        ),
        child: ProxyGroupHeader(
          key: ValueKey('proxy-header-${group.name}'),
          labelPlaybackCoordinator: _labelPlaybackCoordinator,
          playbackOrder: row.groupIndex,
          isExpand: expanded(group),
          slice: last ? ProxyCardSlice.whole : ProxyCardSlice.top,
          showDivider: !last && !grid,
          group: group,
          onChange: _handleChange,
        ),
      );
    }
    final slice = last ? ProxyCardSlice.bottom : ProxyCardSlice.middle;
    if (row.proxyIndex == ProxyListLayout.notice) {
      return ProxyGroupCardSlice(
        slice: slice,
        child: ProxyAutoNotice(group: group),
      );
    }
    if (!grid) {
      final proxy = group.all[row.proxyIndex];
      return ProxyGroupCardSlice(
        slice: slice,
        child: ProxyCard(
          key: ValueKey('${group.name}.${proxy.name}'),
          group: group,
          proxy: proxy,
          showDivider: row.proxyIndex > 0 || layout.hasNotice(row.groupIndex),
        ),
      );
    }
    final columns = layout.columns;
    final start = row.proxyIndex * columns;
    return ProxyGroupCardSlice(
      slice: slice,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ProxyListMetrics.cardEnd,
          0,
          ProxyListMetrics.cardEnd,
          last ? ProxyListMetrics.cardEnd : ProxyListMetrics.gridGap,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var column = 0; column < columns; column++) ...[
              if (column > 0) const SizedBox(width: ProxyListMetrics.gridGap),
              Expanded(
                child: start + column < group.all.length
                    ? ProxyTileCard(
                        key: ValueKey(
                          '${group.name}.${group.all[start + column].name}',
                        ),
                        group: group,
                        proxy: group.all[start + column],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _getGroupOffset(String groupName) {
    if (_controller.position.maxScrollExtent == 0) {
      return 0;
    }
    final findIndex = _groups.indexWhere((item) => item.name == groupName);
    final index = findIndex != -1 ? findIndex : 0;
    return index < _headerOffset.length ? _headerOffset[index] : 0;
  }

  void _scrollToMakeVisibleWithPadding({
    required double containerHeight,
    required double pixels,
    required double start,
    required double end,
    double padding = 24,
  }) {
    final visibleStart = pixels;
    final visibleEnd = pixels + containerHeight;

    final isElementVisible = start >= visibleStart && end <= visibleEnd;
    if (isElementVisible) {
      return;
    }

    double targetScrollOffset;

    if (end <= visibleStart) {
      targetScrollOffset = start;
    } else if (start >= visibleEnd) {
      targetScrollOffset = end - containerHeight + padding;
    } else {
      final visibleTopPart = end - visibleStart;
      final visibleBottomPart = visibleEnd - start;
      if (visibleTopPart.abs() >= visibleBottomPart.abs()) {
        targetScrollOffset = end - containerHeight + padding;
      } else {
        targetScrollOffset = start;
      }
    }

    targetScrollOffset = targetScrollOffset.clamp(
      _controller.position.minScrollExtent,
      _controller.position.maxScrollExtent,
    );

    _controller.jumpTo(targetScrollOffset);
  }

  void _autoScrollToGroup(String groupName) {
    if (!_controller.hasClients) return;
    final pixels = _controller.position.pixels;
    final offset = _getGroupOffset(groupName);
    _scrollToMakeVisibleWithPadding(
      containerHeight: containerHeight,
      pixels: pixels,
      start: offset,
      end: offset + _headerHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, _) {
        ProxyTrace.noteHotspotBuild('proxies_list');
        ref.listen<PageLabel>(currentPageLabelProvider, (previous, next) {
          _labelPlaybackCoordinator.setPageActive(next == PageLabel.proxies);
        });
        _labelPlaybackCoordinator.setPageActive(
          ref.read(currentPageLabelProvider) == PageLabel.proxies,
        );
        final state = ref.watch(proxiesListStateProvider);
        final snapshotState = ref.watch(proxyGroupsSnapshotProvider);
        ref.watch(themeSettingProvider.select((state) => state.textScale));
        final hasGroups = state.groups.isNotEmpty;
        if (hasGroups) {
          ProxyTrace.noteFirstGroupVisible();
        }
        final freshness = snapshotState.freshness;
        if (!hasGroups) {
          final isFailed = freshness == ProxyGroupsFreshnessState.failed;
          final isRefreshing =
              freshness == ProxyGroupsFreshnessState.refreshing;
          final canRefresh = freshness != ProxyGroupsFreshnessState.refreshing;
          final readinessError = snapshotState.error;
          final emptyKind = isRefreshing
              ? ProxiesEmptyStateKind.loading
              : readinessError is ProviderReadinessCoreUnavailable
              ? ProxiesEmptyStateKind.coreUnavailable
              : readinessError is ProviderReadinessTimeout
              ? ProxiesEmptyStateKind.timeout
              : isFailed
              ? ProxiesEmptyStateKind.failed
              : ProxiesEmptyStateKind.empty;
          final emptyLabel = switch (emptyKind) {
            ProxiesEmptyStateKind.loading =>
              context.appLocalizations.syncingProxyGroups,
            ProxiesEmptyStateKind.timeout =>
              context.appLocalizations.providerNotReady,
            ProxiesEmptyStateKind.coreUnavailable =>
              context.appLocalizations.proxyCoreUnavailable,
            ProxiesEmptyStateKind.failed =>
              context.appLocalizations.providerLoadFailed,
            ProxiesEmptyStateKind.empty =>
              context.appLocalizations.noProxyGroups,
          };
          final emptyDescription = switch (emptyKind) {
            ProxiesEmptyStateKind.loading =>
              context.appLocalizations.fetchingProviderNodes,
            ProxiesEmptyStateKind.timeout =>
              context.appLocalizations.checkNetworkAndRetry,
            ProxiesEmptyStateKind.coreUnavailable =>
              context.appLocalizations.reconnectPrompt,
            ProxiesEmptyStateKind.failed =>
              context.appLocalizations.tryAgainLater,
            ProxiesEmptyStateKind.empty =>
              context.appLocalizations.noAvailableNodesInProfile,
          };
          return ProxiesEmptyState(
            label: emptyLabel,
            description: emptyDescription,
            actionLabel: canRefresh
                ? emptyKind == ProxiesEmptyStateKind.coreUnavailable
                      ? context.appLocalizations.reconnect
                      : emptyKind == ProxiesEmptyStateKind.empty
                      ? context.appLocalizations.refreshProxyGroups
                      : context.appLocalizations.reload
                : null,
            onAction: canRefresh
                ? () {
                    globalState.loadingRun(
                      () async {
                        await ref
                            .read(proxiesActionProvider.notifier)
                            .ensureCurrentProfileReady(forceApply: true);
                      },
                      silence: false,
                      tag: LoadingTag.proxies,
                    );
                  }
                : null,
            actionLoading: isRefreshing,
            kind: emptyKind,
          );
        }
        final query = ref.watch(queryProvider(QueryTag.proxies));
        final unfold = state.currentUnfoldSet;
        // While searching, every group with a match shows its matches.
        bool expanded(Group group) =>
            query.isNotEmpty || unfold.contains(group.name);
        final grid = ref.watch(
          navigationStateProvider.select(
            (state) => state.viewMode != ViewMode.mobile,
          ),
        );
        final groups = state.groups;
        return LayoutBuilder(
          builder: (context, constraints) {
            containerHeight = constraints.maxHeight;
            final metrics = ProxyListMetrics.of(context);
            final layout = ProxyListLayout(
              nodeCounts: [
                for (final group in groups)
                  expanded(group) ? group.all.length : 0,
              ],
              notices: [
                for (final group in groups)
                  expanded(group) && proxyGroupPinned(group) != null,
              ],
              headerHeight: metrics.headerHeight,
              nodeHeight: grid ? metrics.gridRowHeight : metrics.rowHeight,
              groupGap: ProxyListMetrics.groupGap,
              columns: grid
                  ? ProxyListMetrics.columnsFor(
                      constraints.maxWidth - 2 * SurgeSpace.l,
                    )
                  : 1,
              noticeHeight: metrics.noticeHeight,
              groupFooter: grid
                  ? ProxyListMetrics.cardEnd - ProxyListMetrics.gridGap
                  : 0,
            );
            _headerOffset = layout.headerOffsets;
            _headerHeight = metrics.headerHeight;
            _groups = groups;
            return CommonScrollBar(
              controller: _controller,
              thumbVisibility: true,
              trackVisibility: true,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ScrollConfiguration(
                      behavior: HiddenBarScrollBehavior(),
                      child: NotificationListener<UserScrollNotification>(
                        onNotification: _onUserScroll,
                        child: ListView.builder(
                          key: proxiesListStoreKey,
                          padding: EdgeInsets.fromLTRB(
                            SurgeSpace.l,
                            SurgeSpace.s,
                            SurgeSpace.l,
                            SurgeBottomNavLayout.mainPageBottomPadding(context),
                          ),
                          controller: _controller,
                          itemCount: layout.rowCount,
                          itemExtentBuilder: (index, _) =>
                              layout.extentAt(index),
                          itemBuilder: (_, index) => _buildRow(
                            layout,
                            index,
                            groups: groups,
                            expanded: expanded,
                            grid: grid,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ValueListenableBuilder(
                      valueListenable: _headerStateNotifier,
                      builder: (_, headerState, _) {
                        if (headerState == null) {
                          return const SizedBox.shrink();
                        }
                        final index = headerState.currentIndex;
                        if (index < 0 ||
                            index >= groups.length ||
                            index >= _headerOffset.length) {
                          return const SizedBox.shrink();
                        }
                        final group = groups[index];
                        final hasBody = !layout.isLastOfGroup(
                          index,
                          ProxyListLayout.header,
                        );
                        if (!hasBody ||
                            !_shouldShowStickyHeader(
                              index: index,
                              expanded: expanded(group),
                            )) {
                          return const SizedBox.shrink();
                        }
                        return Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            height: metrics.headerHeight,
                            child: ColoredBox(
                              color: SurgeTheme.of(context).background,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SurgeSpace.l,
                                ),
                                child: ProxyGroupHeader(
                                  key: Key(group.name),
                                  labelPlaybackCoordinator:
                                      _labelPlaybackCoordinator,
                                  playbackOrder: index,
                                  enterAnimated: false,
                                  isExpand: true,
                                  slice: ProxyCardSlice.top,
                                  showDivider: !grid,
                                  group: group,
                                  onChange: _handleChange,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// A group card's header (design 3.1): icon tile, name over type chip and
/// choice, the latency test and the open arrow. A tap opens the group.
class ProxyGroupHeader extends StatefulWidget {
  const ProxyGroupHeader({
    super.key,
    this.enterAnimated = true,
    this.slice = ProxyCardSlice.whole,
    this.showDivider = false,
    this.playbackOrder = 0,
    required this.group,
    required this.onChange,
    required this.isExpand,
    required this.labelPlaybackCoordinator,
  });

  final Group group;
  final void Function(String groupName) onChange;
  final bool isExpand;
  final ProxyCardSlice slice;
  final bool showDivider;
  final bool enterAnimated;
  final int playbackOrder;
  final ProxyLabelPlaybackCoordinator labelPlaybackCoordinator;

  @override
  State<ProxyGroupHeader> createState() => _ProxyGroupHeaderState();
}

class _ProxyGroupHeaderState extends State<ProxyGroupHeader> {
  bool _testing = false;

  String get groupName => widget.group.name;

  Future<void> _delayTest() async {
    if (_testing) return;
    setState(() => _testing = true);
    try {
      await delayTest(widget.group.all, widget.group.testUrl);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ProxyTrace.noteHotspotBuild('list_header');
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    final group = widget.group;
    final card = ProxyGroupCardSlice(
      slice: widget.slice,
      child: Semantics(
        button: true,
        expanded: widget.isExpand,
        child: SurgePressable(
          scaleFeedback: false,
          onTap: () => widget.onChange(groupName),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: widget.showDivider
                      ? surge.separator
                      : Colors.transparent,
                  width: ProxyListMetrics.hairline,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ProxyListMetrics.cardStart,
                ProxyListMetrics.headerPadding,
                ProxyListMetrics.cardEnd,
                ProxyListMetrics.headerPadding,
              ),
              child: Consumer(
                builder: (_, ref, _) {
                  final nameIcons = ref.watch(
                    proxiesStyleSettingProvider.select(
                      (state) => state.nameIcons,
                    ),
                  );
                  final proxyName = ref
                      .watch(selectedProxyNameProvider(groupName))
                      .takeFirstValid([]);
                  final displayLabel = proxyName.isEmpty
                      ? ''
                      : proxyFullDisplayName(
                          visibleName: proxyName,
                          resolved: ref.watch(
                            realSelectedProxyStateProvider(proxyName),
                          ),
                        );
                  final choice = proxyTitle(displayLabel, nameIcons);
                  return Row(
                    children: [
                      ProxyGroupIconTile(group: group, nameIcons: nameIcons),
                      const SizedBox(width: SurgeSpace.m),
                      Expanded(
                        child: LongPressFullText(
                          message: displayLabel.isNotEmpty
                              ? displayLabel
                              : groupName,
                          onLongPress: () => widget.labelPlaybackCoordinator
                              .requestReplayFor(groupName),
                          child: ProxyNameAndChoice(
                            title: proxyTitle(groupName, nameIcons),
                            type: group.type.name,
                            automatic: proxyGroupIsAutomatic(group),
                            pinned: proxyGroupPinned(group) != null,
                            choice: choice,
                            titleStyle: context.typography.cardTitle,
                            choiceWidget: choice.isEmpty
                                ? const SizedBox.shrink()
                                : ScrollingProxyLabel(
                                    text: choice,
                                    ownerKey: groupName,
                                    order: widget.playbackOrder,
                                    enableInternalLongPress: false,
                                    coordinator:
                                        widget.labelPlaybackCoordinator,
                                    replayToken: widget.isExpand,
                                    style: context.typography.proxyCardSubtitle
                                        .copyWith(color: surge.textSecondary),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: SurgeSpace.s),
                      ProxyRoundAction(
                        icon: SurgeIcons.flashOn,
                        tooltip: l10n.testLatency,
                        busy: _testing,
                        onPressed: _delayTest,
                      ),
                      const SizedBox(width: SurgeSpace.s),
                      Tooltip(
                        message: widget.isExpand ? l10n.collapse : l10n.expand,
                        child: ProxyGroupOpenToggle(open: widget.isExpand),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    return widget.enterAnimated ? FadeScaleEnterBox(child: card) : card;
  }
}
