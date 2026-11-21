import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/dashboard_layout.dart';
import 'package:fl_clash/views/proxies/common.dart' as proxy_common;
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _heroFillDuration = SurgeMotion.heroFill;
const _statusLightPulseDuration = SurgeMotion.statusLightPulse;

bool heroOutboundFillActive({
  required bool isStart,
  required bool isSmartStopped,
}) {
  return isStart || isSmartStopped;
}

/// Smart pause shares the flatter dynamic-color treatment so its warm state
/// does not gain an extra static-theme gradient.
bool heroUsesDynamicSurfaceTreatment({
  required bool dynamicColor,
  required bool isSmartPaused,
}) {
  return dynamicColor || isSmartPaused;
}

/// True only when the active-fill color actually changed. First mount with
/// begin == end is a visual no-op and must not start the 1500ms ticker.
bool heroActiveFillShouldAnimate({
  required Color? previous,
  required Color next,
}) {
  return previous != null && previous != next;
}

/// Status-light pulse / connecting chrome. PAUSED must not pulse even if
/// Core is attaching or a leftover connecting timer is still true.
bool heroConnectingPulseActive({
  required bool isSmartStopped,
  required CoreStatus coreStatus,
  required bool showConnecting,
}) {
  return !isSmartStopped &&
      (coreStatus == CoreStatus.connecting || showConnecting);
}

class SurgeDashboardHero extends ConsumerStatefulWidget {
  const SurgeDashboardHero({
    super.key,
    required this.layout,
    this.allocatedHeight,
  });

  final DashboardResponsiveLayout layout;
  final double? allocatedHeight;

  @override
  ConsumerState<SurgeDashboardHero> createState() => _SurgeDashboardHeroState();
}

class _SurgeDashboardHeroState extends ConsumerState<SurgeDashboardHero>
    with TickerProviderStateMixin {
  Timer? _failureTimer;
  Timer? _connectingTimer;
  bool _showFailure = false;
  bool _showConnecting = false;
  String? _transitionKind;
  late final AnimationController _fillController;
  late final AnimationController _sheenController;
  late final Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    final isStart = ref.read(isStartProvider);
    final isSmartStopped = ref.read(isSmartStoppedProvider);
    _fillController = AnimationController(
      vsync: this,
      duration: _heroFillDuration,
      value:
          heroOutboundFillActive(
            isStart: isStart,
            isSmartStopped: isSmartStopped,
          )
          ? 1
          : 0,
    );
    _fillAnimation = CurvedAnimation(
      parent: _fillController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _sheenController = AnimationController(
      vsync: this,
      duration: SurgeMotion.heroSheen,
    );
  }

  @override
  void dispose() {
    if (NavigationTrace.enabled) {
      NavigationTrace.dashboardHeroMounted = false;
      NavigationTrace.dashboardSheenRepeating = false;
    }
    _failureTimer?.cancel();
    _connectingTimer?.cancel();
    _fillController.dispose();
    _sheenController.dispose();
    super.dispose();
  }

  String _modeLabel(Mode mode) {
    return switch (mode) {
      Mode.rule => 'Rule',
      Mode.global => 'Global',
      Mode.direct => 'Direct',
    };
  }

  void _handleSwitchStart(WidgetRef ref) {
    final nextIsStart = !ref.read(isStartProvider);
    final kind = nextIsStart ? 'start' : 'stop';
    if (mounted) {
      setState(() => _transitionKind = kind);
      _sheenController.repeat();
    }
    if (nextIsStart) {
      _startConnectingAnimation();
      _fillController.forward();
    } else {
      _fillController.reverse();
    }
    unawaited(() async {
      try {
        // Register intent immediately. SetupAction owns the attachment wait,
        // so a later Stop can invalidate this tap while startup is pending.
        await globalState.container
            .read(setupActionProvider.notifier)
            .updateStatus(nextIsStart);
      } finally {
        if (mounted) {
          setState(() => _transitionKind = null);
          _sheenController.stop();
        }
      }
    }());
  }

  void _handleChangeMode(Mode mode, WidgetRef ref) {
    ref.read(setupActionProvider.notifier).changeMode(mode);
  }

  void _syncOutboundFill({
    required bool isStart,
    required bool isSmartStopped,
  }) {
    if (heroOutboundFillActive(
      isStart: isStart,
      isSmartStopped: isSmartStopped,
    )) {
      _fillController.forward();
    } else {
      _fillController.reverse();
    }
  }

  void _startConnectingAnimation() {
    _connectingTimer?.cancel();
    if (mounted) {
      setState(() => _showConnecting = true);
    }
    _connectingTimer = Timer(_heroFillDuration, () {
      if (mounted) {
        setState(() => _showConnecting = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (NavigationTrace.enabled) {
      NavigationTrace.noteHotspotBuild('dashboard_hero');
      NavigationTrace.dashboardHeroMounted = true;
      NavigationTrace.dashboardSheenRepeating = _sheenController.isAnimating;
    }
    final surge =
        Theme.of(context).extension<SurgeTheme>() ?? SurgeTheme.light();
    final appLocalizations = context.appLocalizations;
    final isStart = ref.watch(isStartProvider);
    final isSmartResuming = ref.watch(isSmartResumingProvider);
    final isSmartStopped = ref.watch(isSmartStoppedProvider);
    final isSmartPaused = isSmartStopped && !isStart;
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final coreStatus = ref.watch(coreStatusProvider);
    final connecting = heroConnectingPulseActive(
      isSmartStopped: isSmartStopped,
      coreStatus: coreStatus,
      showConnecting: _showConnecting,
    );
    final transitionStart = _transitionKind == 'start';
    final transitionStop = _transitionKind == 'stop';
    final transitionPausing = _transitionKind == 'pausing';
    final buttonLabel = transitionPausing
        ? appLocalizations.pausing
        : isSmartResuming
        ? appLocalizations.resuming
        : transitionStop
        ? appLocalizations.stopping
        : (transitionStart || connecting)
        ? appLocalizations.starting
        : isSmartPaused
        ? appLocalizations.resume
        : isStart
        ? appLocalizations.stop
        : appLocalizations.start;
    final buttonLoading =
        transitionPausing ||
        isSmartResuming ||
        transitionStart ||
        transitionStop ||
        connecting;
    final statusLabel = isSmartPaused
        ? appLocalizations.smartStopped
        : isStart
        ? appLocalizations.connected
        : appLocalizations.disconnected;
    ref.listen(isStartProvider, (previous, next) {
      final smartStopped = ref.read(isSmartStoppedProvider);
      _syncOutboundFill(isStart: next, isSmartStopped: smartStopped);
      // Visible providers can publish an intermediate RUNNING/PAUSED snapshot
      // before updateStatus has finished reconciling the native transition.
      // Keep the action disabled until _handleSwitchStart's Future completes;
      // otherwise the button can change meaning underneath a rapid second tap.
    });

    ref.listen(isSmartStoppedProvider, (previous, next) {
      _syncOutboundFill(
        isStart: ref.read(isStartProvider),
        isSmartStopped: next,
      );
      // Auto smart-stop triggered during start transition → "暂停中"
      if (next && previous == false && _transitionKind == 'start') {
        _sheenController.repeat();
        if (mounted) setState(() => _transitionKind = 'pausing');
      }
    });

    ref.listen(coreStatusProvider, (previous, next) {
      final isFailedStart =
          previous == CoreStatus.connecting && next == CoreStatus.disconnected;
      if (next == CoreStatus.disconnected &&
          !ref.read(isSmartStoppedProvider)) {
        _fillController.reverse();
      }
      if (next != CoreStatus.disconnected || !isFailedStart) {
        _failureTimer?.cancel();
        if (_showFailure && mounted) {
          setState(() => _showFailure = false);
        }
        return;
      }
      _failureTimer?.cancel();
      if (mounted) {
        setState(() => _showFailure = true);
      }
      _failureTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) {
          setState(() => _showFailure = false);
        }
      });
    });

    final layout = widget.layout;
    final status = _StatusPill(
      active: isStart,
      isSmartPaused: isSmartPaused,
      connecting: connecting,
      failed: _showFailure,
      label: statusLabel,
      layout: layout,
    );
    final actionButton = _HeroStartRing(
      size: layout.geometry(88),
      fillProgress: _fillAnimation,
      isSmartPaused: isSmartPaused || isSmartResuming || transitionPausing,
      stopping: transitionStop,
      loading: buttonLoading,
      label: buttonLabel,
      sheenController: _sheenController,
      onPressed: buttonLoading
          ? null
          : () {
              if (isSmartPaused) {
                ref.read(smartAutoStopManagerProvider.notifier).resumeNow();
              } else {
                _handleSwitchStart(ref);
              }
            },
    );
    final title = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appLocalizations.outboundTraffic,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.typography.screenTitle.copyWith(
            color: surge.textPrimary,
          ),
        ),
        Text(
          '${_modeLabel(mode)} mode',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.typography.supporting.copyWith(
            color: surge.textSecondary,
          ),
        ),
      ],
    );

    // Design 3.1 (the "RoutaMi AMOLED" artifact): the route card with the
    // running time and the start ring, then the three mode buttons.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(layout.geometry(18)),
          decoration: BoxDecoration(
            color: surge.card,
            borderRadius: BorderRadius.circular(layout.cardRadius),
            border: Border.all(
              color: surge.separator,
              width: surge.spacing.hairline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  SizedBox(width: layout.geometry(12)),
                  status,
                ],
              ),
              SizedBox(height: layout.geometry(18)),
              Row(
                children: [
                  Expanded(child: _HeroUptime(running: isStart)),
                  SizedBox(width: layout.geometry(16)),
                  actionButton,
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: layout.geometry(16)),
        _ModeSwitch(
          value: mode,
          onChanged: (value) => _handleChangeMode(value, ref),
          layout: layout,
        ),
      ],
    );
  }
}

class HeroActiveFill extends StatefulWidget {
  const HeroActiveFill({
    super.key,
    required this.activeFill,
    required this.builder,
    required this.child,
  });

  final Color activeFill;
  final Widget Function(BuildContext context, Color fill, Widget? child)
  builder;
  final Widget child;

  @override
  State<HeroActiveFill> createState() => HeroActiveFillState();
}

class HeroActiveFillState extends State<HeroActiveFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  ColorTween? _tween;
  late Color _displayed;

  /// True only while a real activeFill color transition is ticking.
  @visibleForTesting
  bool get debugIsAnimating => _controller.isAnimating;

  @override
  void initState() {
    super.initState();
    _displayed = widget.activeFill;
    _controller = AnimationController(vsync: this, duration: _heroFillDuration);
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _controller.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    _displayed = widget.activeFill;
    _tween = null;
    if (mounted) {
      setState(() {});
    }
  }

  Color _currentVisualColor() {
    final tween = _tween;
    if (tween == null || !_controller.isAnimating) {
      return _displayed;
    }
    return tween.evaluate(_curve) ?? _displayed;
  }

  @override
  void didUpdateWidget(covariant HeroActiveFill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!heroActiveFillShouldAnimate(
      previous: oldWidget.activeFill,
      next: widget.activeFill,
    )) {
      return;
    }
    final from = _currentVisualColor();
    _displayed = from;
    _tween = ColorTween(begin: from, end: widget.activeFill);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tween = _tween;
    if (tween == null || !_controller.isAnimating) {
      return widget.builder(context, widget.activeFill, widget.child);
    }
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        return widget.builder(
          context,
          tween.evaluate(_curve) ?? widget.activeFill,
          child,
        );
      },
      child: widget.child,
    );
  }
}

/// The start button of design 3.1: a ring in the theme's start colour that
/// fills while the proxy runs ([fillProgress] follows the old mode card's
/// fill) and spins an arc while starting or stopping.
class _HeroStartRing extends StatelessWidget {
  const _HeroStartRing({
    required this.size,
    required this.fillProgress,
    required this.isSmartPaused,
    required this.stopping,
    required this.loading,
    required this.label,
    required this.sheenController,
    required this.onPressed,
  });

  final double size;
  final Animation<double> fillProgress;
  final bool isSmartPaused;
  final bool stopping;
  final bool loading;
  final String label;
  final AnimationController sheenController;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final base = isSmartPaused
        ? surge.semantic.state.heroPause
        : stopping
        ? surge.semantic.state.heroStop
        : surge.semantic.state.heroStart;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: HeroActiveFill(
        activeFill: base,
        builder: (context, color, child) => AnimatedBuilder(
          animation: fillProgress,
          builder: (context, _) {
            final progress = fillProgress.value.clamp(0.0, 1.0);
            final fill = Color.lerp(surge.card, color, progress)!;
            final foreground = Color.lerp(
              color,
              surge.semantic.state.onHeroAction,
              progress,
            )!;
            return SizedBox.square(
              dimension: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                  boxShadow: progress > 0
                      ? SurgeShadows.glow(color, scale: progress)
                      : null,
                ),
                child: SurgePressable(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(size / 2),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (loading)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(SurgeSpace.xxs),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: foreground,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SurgeSpace.s,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                maxLines: 1,
                                style: context.typography.controlLabel.copyWith(
                                  color: foreground,
                                ),
                              ),
                              if (loading) ...[
                                const SizedBox(height: SurgeSpace.xxs),
                                _LoadingDots(
                                  controller: sheenController,
                                  color: foreground,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        child: const SizedBox.shrink(),
      ),
    );
  }
}

/// The running time, ticking every second from the session's start.
class _HeroUptime extends ConsumerStatefulWidget {
  const _HeroUptime({required this.running});

  final bool running;

  @override
  ConsumerState<_HeroUptime> createState() => _HeroUptimeState();
}

class _HeroUptimeState extends ConsumerState<_HeroUptime> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _HeroUptime oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.running != widget.running) _sync();
  }

  void _sync() {
    _ticker?.cancel();
    _ticker = widget.running
        ? Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() {});
          })
        : null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int? _elapsed() {
    if (!widget.running) return null;
    final start = ref.read(setupActionProvider.notifier).startTime;
    if (start == null) return ref.read(runTimeProvider);
    return DateTime.now().difference(start).inMilliseconds;
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.appLocalizations.uptime.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.typography.badgeLabel.copyWith(
            color: surge.textSecondary,
          ),
        ),
        const SizedBox(height: SurgeSpace.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            utils.getTimeText(_elapsed()),
            maxLines: 1,
            style: context.typography.dashboardUptime.copyWith(
              color: widget.running ? surge.textPrimary : surge.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Three subtle dots that pulse during loading.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.controller, required this.color});

  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(color: color, opacity: _dotOpacity(t, 0)),
            _Dot(color: color, opacity: _dotOpacity(t, 1)),
            _Dot(color: color, opacity: _dotOpacity(t, 2)),
          ],
        );
      },
    );
  }

  double _dotOpacity(double t, int index) {
    final phase = (t + index / 3) % 1;
    return phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// The current profile as a chip beside the brand; opens the profile list.
class DashboardProfileChip extends ConsumerWidget {
  const DashboardProfileChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final profiles = ref.watch(profilesProvider);
    final currentProfile = ref.watch(currentProfileProvider);
    final label =
        currentProfile?.realLabel.takeFirstValid([appName]) ?? appName;
    return SurgePressable(
      onTap: () => _showSubscriptionSelectorSheet(
        context,
        ref,
        profiles,
        currentProfile?.id,
      ),
      borderRadius: BorderRadius.circular(surge.radii.button),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SurgeSpace.m,
          vertical: SurgeSpace.xs + SurgeSpace.xxs,
        ),
        decoration: BoxDecoration(
          color: surge.card,
          borderRadius: BorderRadius.circular(surge.radii.button),
          border: Border.all(color: surge.separator),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.technical.copyWith(
                  color: surge.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: SurgeSpace.xs),
            Icon(
              SurgeIcons.expand,
              size: SurgeIconSize.compact,
              color: surge.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showSubscriptionSelectorSheet(
    BuildContext context,
    WidgetRef ref,
    List<Profile> profiles,
    int? currentProfileId,
  ) {
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: false),
      builder: (sheetContext) {
        final surge = SurgeTheme.of(sheetContext);
        return AdaptiveSheetScaffold(
          title: context.appLocalizations.selectProfile,
          appBarActions: const [],
          body: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: SurgeSpace.xl,
              vertical: SurgeSpace.m,
            ),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final isSelected = profile.id == currentProfileId;
              return Padding(
                padding: const EdgeInsets.only(bottom: SurgeSpace.s),
                child: SurgeSelectableRow(
                  selected: isSelected,
                  onTap: () {
                    ref
                        .read(proxiesActionProvider.notifier)
                        .beginRuntimeProfileTransition(profile.id);
                    ref.read(currentProfileIdProvider.notifier).value =
                        profile.id;
                    Navigator.of(context).pop();
                  },
                  presentation: SurgeSelectionPresentation.menu,
                  showBorder: true,
                  radius: surge.radii.menuRow,
                  selectedSurfaceColor: surge.selectedFill,
                  unselectedSurfaceColor: surge.fill,
                  selectedBorderColor: surge.primary.withValues(
                    alpha: SurgeAlpha.a48,
                  ),
                  unselectedBorderColor: surge.separator,
                  selectedBorderWidth: 1,
                  unselectedBorderWidth: surge.spacing.hairline,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SurgeSpace.m,
                      vertical: SurgeSpace.m,
                    ),
                    child: Row(
                      children: [
                        if (isSelected) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: surge.semantic.connected,
                              shape: BoxShape.circle,
                            ),
                            margin: const EdgeInsets.only(right: SurgeSpace.s),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            profile.realLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.typography.sheetRowTitle.copyWith(
                              color: surge.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          profile.type == ProfileType.url
                              ? 'URL'
                              : context.appLocalizations.local,
                          style: context.typography.sheetLabel.copyWith(
                            color: surge.textSecondary,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: SurgeSpace.s),
                          Icon(
                            SurgeIcons.success,
                            size: SurgeIconSize.compact,
                            color: surge.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Connected, paused, failed or idle, on the hero card's own surface.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.active,
    required this.isSmartPaused,
    required this.connecting,
    required this.failed,
    required this.label,
    required this.layout,
  });

  final bool active;
  final bool isSmartPaused;
  final bool connecting;
  final bool failed;
  final String label;
  final DashboardResponsiveLayout layout;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final tone = failed
        ? surge.red
        : isSmartPaused
        ? surge.orange
        : active || connecting
        ? surge.semantic.connected
        : surge.textSecondary;
    final lit = failed || isSmartPaused || active || connecting;
    return AnimatedContainer(
      duration: SurgeMotion.reveal,
      padding: EdgeInsets.symmetric(
        horizontal: layout.geometry(10),
        vertical: layout.geometry(6),
      ),
      decoration: BoxDecoration(
        color: lit ? tone.withValues(alpha: SurgeAlpha.a12) : null,
        borderRadius: BorderRadius.circular(surge.radii.button),
        border: Border.all(
          color: lit ? tone.withValues(alpha: SurgeAlpha.a38) : surge.separator,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillStatusLight(
            active: active,
            isSmartPaused: isSmartPaused,
            connecting: connecting,
            failed: failed,
            size: layout.geometry(8),
          ),
          SizedBox(width: layout.geometry(7)),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: context.typography.badgeLabel.copyWith(color: tone),
          ),
        ],
      ),
    );
  }
}

class _PillStatusLight extends StatefulWidget {
  const _PillStatusLight({
    required this.active,
    required this.isSmartPaused,
    required this.connecting,
    required this.failed,
    required this.size,
  });

  final bool active;
  final bool isSmartPaused;
  final bool connecting;
  final bool failed;
  final double size;

  @override
  State<_PillStatusLight> createState() => _PillStatusLightState();
}

class _PillStatusLightState extends State<_PillStatusLight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _statusLightPulseDuration,
      lowerBound: 0.35,
      upperBound: 1,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _PillStatusLight oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (widget.connecting) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  Color _color(SurgeTheme surge) {
    if (widget.failed) return surge.semantic.statusLightError;
    if (widget.isSmartPaused) return surge.semantic.statusLightPaused;
    if (widget.connecting || widget.active) {
      return surge.semantic.statusLightActive;
    }
    return surge.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    if (NavigationTrace.enabled) {
      NavigationTrace.dashboardPulseRepeating = _controller.isAnimating;
    }
    final surge = SurgeTheme.of(context);
    final color = _color(surge);

    return FadeTransition(
      opacity: _opacity,
      child: AnimatedContainer(
        duration: SurgeMotion.reveal,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: SurgeShadows.halo(
            color,
            alpha:
                !widget.active &&
                    !widget.connecting &&
                    !widget.failed &&
                    !widget.isSmartPaused
                ? SurgeAlpha.none
                : SurgeAlpha.a38,
          ),
        ),
      ),
    );
  }
}

/// Rule, direct, global as three separate pills; the chosen one is filled
/// with the accent.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.value,
    required this.onChanged,
    required this.layout,
  });

  final Mode value;
  final ValueChanged<Mode> onChanged;
  final DashboardResponsiveLayout layout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    final items = [
      (Mode.rule, l10n.rule),
      (Mode.direct, l10n.direct),
      (Mode.global, l10n.global),
    ];
    return SizedBox(
      height: layout.geometry(40),
      child: Row(
        children: [
          for (final (index, (mode, label)) in items.indexed) ...[
            if (index > 0) SizedBox(width: layout.geometry(6)),
            Expanded(
              child: _ModePill(
                label: label,
                selected: mode == value,
                onTap: () => onChanged(mode),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final radius = BorderRadius.circular(surge.radii.list);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SurgePressable(
        onTap: onTap,
        scaleFeedback: false,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: SurgeMotion.state,
          curve: SurgeMotion.stateCurve,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? surge.primary : surge.fill,
            borderRadius: radius,
            border: Border.all(
              color: selected ? surge.primary : surge.separator,
              width: surge.spacing.hairline,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (selected
                        ? context.typography.selectedModeTabLabel
                        : context.typography.modeTabLabel)
                    .copyWith(
                      color: selected ? surge.onPrimary : surge.textSecondary,
                    ),
          ),
        ),
      ),
    );
  }
}

/// The proxy group the dashboard shows: the profile's current group, or the
/// first one.
String dashboardGroupName(List<Group> groups, String currentGroupName) {
  if (currentGroupName.isNotEmpty &&
      groups.any((group) => group.name == currentGroupName)) {
    return currentGroupName;
  }
  return groups.isNotEmpty ? groups.first.name : '';
}

void showDashboardGroupSheet(
  BuildContext context,
  List<Group> groups,
  String selectedGroupName,
) {
  showSheet(
    context: context,
    props: const SheetProps(isScrollControlled: true),
    builder: (sheetContext) {
      final surge = SurgeTheme.of(sheetContext);
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: AdaptiveSheetScaffold(
          title: sheetContext.appLocalizations.proxyGroup,
          appBarActions: const [],
          body: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: SurgeSpace.xl,
              vertical: SurgeSpace.m,
            ),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final isSelected = group.name == selectedGroupName;
              return Padding(
                padding: const EdgeInsets.only(bottom: SurgeSpace.s),
                child: SurgeSelectableRow(
                  selected: isSelected,
                  onTap: () {
                    proxy_common.updateCurrentGroupName(group.name);
                    Navigator.of(context).pop();
                  },
                  presentation: SurgeSelectionPresentation.menu,
                  showBorder: true,
                  radius: surge.radii.menuRow,
                  selectedSurfaceColor: surge.selectedFill,
                  unselectedSurfaceColor: surge.fill,
                  selectedBorderColor: surge.primary.withValues(
                    alpha: SurgeAlpha.a48,
                  ),
                  unselectedBorderColor: surge.separator,
                  selectedBorderWidth: 1,
                  unselectedBorderWidth: surge.spacing.hairline,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SurgeSpace.m,
                      vertical: SurgeSpace.m,
                    ),
                    child: Row(
                      children: [
                        if (isSelected) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: surge.semantic.connected,
                              shape: BoxShape.circle,
                            ),
                            margin: const EdgeInsets.only(right: SurgeSpace.s),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.typography.sheetRowTitle.copyWith(
                              color: surge.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          group.type.name,
                          style: context.typography.sheetLabel.copyWith(
                            color: surge.textSecondary,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: SurgeSpace.s),
                          Icon(
                            SurgeIcons.success,
                            size: SurgeIconSize.compact,
                            color: surge.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

void showDashboardNodeSheet(
  BuildContext context,
  WidgetRef ref,
  String groupName,
  String currentProxyName,
) {
  final groups = ref.read(groupsProvider);
  final matchingGroups = groups.where((g) => g.name == groupName);
  final group = matchingGroups.isNotEmpty ? matchingGroups.first : groups.first;
  showSheet(
    context: context,
    props: const SheetProps(isScrollControlled: true),
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: AdaptiveSheetScaffold(
        title: sheetContext.appLocalizations.nodes,
        body: _NodeSelectionSheet(
          group: group,
          currentProxyName: currentProxyName,
        ),
      ),
    ),
  );
}

class _NodeSelectionSheet extends ConsumerStatefulWidget {
  const _NodeSelectionSheet({
    required this.group,
    required this.currentProxyName,
  });

  final Group group;
  final String currentProxyName;

  @override
  ConsumerState<_NodeSelectionSheet> createState() =>
      _NodeSelectionSheetState();
}

class _NodeSelectionSheetState extends ConsumerState<_NodeSelectionSheet> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchQuery = '';
  bool _isDelayTesting = false;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _delayTest() async {
    if (_isDelayTesting) return;
    setState(() => _isDelayTesting = true);
    await proxy_common.delayTest(widget.group.all, widget.group.testUrl);
    if (mounted) setState(() => _isDelayTesting = false);
  }

  void _scrollToSelected() {
    final proxies = widget.group.all;
    final selectedIndex = proxies.indexWhere(
      (p) => p.name == widget.currentProxyName,
    );
    if (selectedIndex == -1) return;
    // Each node card: padding vertical 10*2 + text ~18 + bottom margin 6 = ~44
    // Use a safe offset that ensures the item is visible near the top
    final targetOffset = (selectedIndex * 44.0) - 80;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: SurgeMotion.scroll,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final filteredProxies = widget.group.all
        .where(
          (p) =>
              _searchQuery.isEmpty ||
              p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return Column(
      children: [
        // Search field with embedded action buttons
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SurgeSpace.xl,
            vertical: SurgeSpace.s,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            style: context.typography.body,
            decoration: surgeInputDecoration(
              context,
              hintText: context.appLocalizations.search,
              prefixIcon: Icon(
                SurgeIcons.search,
                color: surge.textSecondary,
                size: SurgeIconSize.regular,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(SurgeSpace.xs),
                    onPressed: _scrollToSelected,
                    iconSize: SurgeIconSize.regular,
                    icon: Icon(SurgeIcons.selector, color: surge.textSecondary),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(SurgeSpace.xs),
                    onPressed: _isDelayTesting ? null : _delayTest,
                    iconSize: SurgeIconSize.regular,
                    icon: _isDelayTesting
                        ? SizedBox.square(
                            dimension: SurgeIconSize.inline,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: surge.textSecondary,
                            ),
                          )
                        : Icon(
                            SurgeIcons.networkPing,
                            color: surge.textSecondary,
                          ),
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: SurgeSpace.m,
                vertical: SurgeSpace.s,
              ),
            ),
          ),
        ),
        // Node list
        Expanded(
          child: filteredProxies.isEmpty
              ? Center(
                  child: Text(
                    context.appLocalizations.noData,
                    style: context.typography.supporting,
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SurgeSpace.xl,
                    vertical: SurgeSpace.s,
                  ),
                  itemCount: filteredProxies.length,
                  itemBuilder: (context, index) {
                    final proxy = filteredProxies[index];
                    return _NodeCard(
                      proxy: proxy,
                      group: widget.group,
                      isSelected: proxy.name == widget.currentProxyName,
                      onTap: () {
                        if (proxy_common.applyProxyGroupMemberTap(
                          group: widget.group,
                          tappedName: proxy.name,
                        )) {
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NodeCard extends ConsumerWidget {
  const _NodeCard({
    required this.proxy,
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  final Proxy proxy;
  final Group group;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final delay = ref.watch(
      delayProvider(proxyName: proxy.name, testUrl: group.testUrl),
    );
    final delayColor = delay == null
        ? surge.textSecondary
        : delay == 0
        ? surge.textSecondary
        : delay < 0
        ? surge.red
        : surge.latencyColor(delay) ?? surge.textSecondary;
    final delayLabel = delay == null
        ? ''
        : delay == 0
        ? '...'
        : delay > 0
        ? '${delay}ms'
        : 'Timeout';

    return Padding(
      padding: const EdgeInsets.only(bottom: SurgeSpace.s),
      child: SurgeSelectableRow(
        selected: isSelected,
        onTap: onTap,
        presentation: SurgeSelectionPresentation.menu,
        showBorder: true,
        radius: surge.radii.menuRow,
        selectedSurfaceColor: surge.selectedFill,
        unselectedSurfaceColor: surge.fill,
        selectedBorderColor: surge.primary.withValues(alpha: SurgeAlpha.a48),
        unselectedBorderColor: surge.separator,
        selectedBorderWidth: 1,
        unselectedBorderWidth: surge.spacing.hairline,
        child: SizedBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SurgeSpace.m,
              vertical: SurgeSpace.m,
            ),
            child: Row(
              children: [
                if (isSelected) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: surge.semantic.connected,
                      shape: BoxShape.circle,
                    ),
                    margin: const EdgeInsets.only(right: SurgeSpace.s),
                  ),
                ],
                Expanded(
                  child: Text(
                    proxy.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.sheetRowTitle.copyWith(
                      color: surge.textPrimary,
                    ),
                  ),
                ),
                if (delayLabel.isNotEmpty) ...[
                  const SizedBox(width: SurgeSpace.s),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SurgeSpace.s,
                      vertical: SurgeSpace.s,
                    ),
                    decoration: BoxDecoration(
                      color: delayColor.withValues(alpha: SurgeAlpha.a12),
                      borderRadius: BorderRadius.circular(surge.radii.metric),
                    ),
                    child: Text(
                      delayLabel,
                      style: context.typography.sheetLabel.copyWith(
                        color: delayColor,
                      ),
                    ),
                  ),
                ],
                if (isSelected) ...[
                  const SizedBox(width: SurgeSpace.s),
                  Icon(
                    SurgeIcons.success,
                    size: SurgeIconSize.compact,
                    color: surge.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
