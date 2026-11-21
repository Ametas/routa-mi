import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One option of a settings unfold (design 3.1 "RoutaMi Settings Unfold").
/// Each kind brings its own editor; [disabledReason] dims the option and
/// says why a tap does nothing.
sealed class UnfoldOption {
  const UnfoldOption(this.label, {this.disabledReason});

  final String label;
  final String? disabledReason;

  /// What the option adds to its section's summary line.
  String? get summary;
}

/// Changes with a tap; no editor.
class UnfoldSwitch extends UnfoldOption {
  const UnfoldSwitch(
    super.label, {
    required this.value,
    required this.onChanged,
    super.disabledReason,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  String? get summary => value ? label : null;
}

enum UnfoldChoiceStyle { segments, chips }

/// A pick among a few values: segments for two or three, chips beyond.
class UnfoldChoice<T> extends UnfoldOption {
  const UnfoldChoice(
    super.label, {
    required this.values,
    required this.value,
    required this.labelOf,
    required this.onChanged,
    UnfoldChoiceStyle? style,
    this.summaryOf,
    super.disabledReason,
  }) : _style = style;

  final List<T> values;
  final T value;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;
  final UnfoldChoiceStyle? _style;

  /// What the section summary shows; null leaves the value out of it.
  final String? Function(T value)? summaryOf;

  String get valueLabel => labelOf(value);

  /// Built here so the editor keeps the option's value type.
  Widget _editor(void Function(VoidCallback apply) onPicked) =>
      _ChoiceEditor<T>(option: this, onPicked: onPicked);

  UnfoldChoiceStyle get style =>
      _style ??
      (values.length <= 3
          ? UnfoldChoiceStyle.segments
          : UnfoldChoiceStyle.chips);

  @override
  String? get summary => (summaryOf ?? labelOf)(value);
}

/// A pick among colours.
class UnfoldSwatches extends UnfoldOption {
  const UnfoldSwatches(
    super.label, {
    required this.colors,
    required this.names,
    required this.index,
    required this.onChanged,
    super.disabledReason,
  });

  final List<Color> colors;
  final List<String> names;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  String? get summary => disabledReason == null ? names[index] : null;
}

/// A typed value, saved only once [validator] accepts it.
class UnfoldField extends UnfoldOption {
  const UnfoldField(
    super.label, {
    required this.value,
    required this.validator,
    required this.onSubmitted,
    this.hint,
    this.keyboardType = TextInputType.text,
    super.disabledReason,
  });

  final String value;
  final String? hint;
  final String? Function(String value) validator;
  final ValueChanged<String> onSubmitted;
  final TextInputType keyboardType;

  @override
  String? get summary => value.replaceFirst(RegExp(r'^https?://'), '');
}

/// Opens a page of its own; the unfold closes first.
class UnfoldLink extends UnfoldOption {
  const UnfoldLink(super.label, {required this.onTap, this.value});

  final String? value;
  final VoidCallback onTap;

  @override
  String? get summary => null;
}

typedef UnfoldOptionsBuilder =
    List<UnfoldOption> Function(BuildContext context, WidgetRef ref);

/// The first values of a section, joined for its subtitle.
String unfoldSummary(List<UnfoldOption> options, {int count = 3}) => options
    .map((option) => option.summary)
    .whereType<String>()
    .where((value) => value.isNotEmpty)
    .take(count)
    .join(' · ');

/// Timing and placement of one unfold, fixed when it opens.
class SettingsUnfoldLayout {
  SettingsUnfoldLayout._({
    required this.anchor,
    required this.up,
    required this.count,
    required this.topLimit,
    required this.bottomLimit,
  });

  /// Options keep their order: the first [up] of them stand above the
  /// anchor, the rest below. Room for one open editor is kept free.
  factory SettingsUnfoldLayout.compute({
    required Rect anchor,
    required Size screen,
    required EdgeInsets padding,
    required int count,
    required double rowHeight,
  }) {
    final topLimit = padding.top + edge;
    final bottomLimit = screen.height - padding.bottom - edge;
    final step = rowHeight + gap;
    final roomUp = math.max(
      0,
      ((anchor.top - gap - topLimit - editorReserve + gap) / step).floor(),
    );
    final roomDown = math.max(
      0,
      ((bottomLimit - anchor.bottom - gap - editorReserve + gap) / step)
          .floor(),
    );
    var up = (count * roomUp / math.max(1, roomUp + roomDown)).round();
    up = up.clamp(math.max(0, count - roomDown), math.min(count, roomUp));
    return SettingsUnfoldLayout._(
      anchor: anchor,
      up: up,
      count: count,
      topLimit: topLimit,
      bottomLimit: bottomLimit,
    );
  }

  static const double gap = SurgeSpace.s;
  static const double edge = SurgeSpace.l;
  static const double editorReserve = 84;

  static const Duration lead = SurgeDuration.short1;
  static const Duration step = SurgeDuration.short1;
  static const Duration item = SurgeDuration.medium1;
  static const Duration scrim = SurgeMotion.fade;

  final Rect anchor;
  final int up;
  final int count;
  final double topLimit;
  final double bottomLimit;

  bool isUp(int index) => index < up;

  /// 1 for the options next to the anchor, growing outward.
  int distance(int index) => index < up ? up - index : index - up + 1;

  int get _farthest => math.max(up, count - up);

  Duration startOf(int index) => lead + step * (distance(index) - 1);

  Duration get total {
    final last = count == 0 ? Duration.zero : lead + step * (_farthest - 1);
    final items = last + item;
    return items > scrim ? items : scrim;
  }

  Interval interval(int index, Curve curve) {
    final whole = total.inMicroseconds;
    final start = startOf(index).inMicroseconds / whole;
    final end = (startOf(index) + item).inMicroseconds / whole;
    return Interval(start, math.min(1, end), curve: curve);
  }

  Interval scrimInterval(Curve curve) =>
      Interval(0, scrim.inMicroseconds / total.inMicroseconds, curve: curve);

  /// The height of a closed option at the current text scale.
  static double rowHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(SurgeSpace.l) + 36;
}

/// Opens [options] around the row at [anchorContext]: the row stays where it
/// is, the screen dims and the options slide out of it, nearest first.
/// Tapping the row again, the dimmed screen or back folds them in.
Future<void> showSettingsUnfold(
  BuildContext anchorContext, {
  required Widget Function(BuildContext context, Animation<double> open)
  anchorBuilder,
  required UnfoldOptionsBuilder options,
  required int count,
}) {
  final navigator = Navigator.of(anchorContext, rootNavigator: true);
  final box = anchorContext.findRenderObject()! as RenderBox;
  final overlay = navigator.context.findRenderObject()! as RenderBox;
  final anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  final media = MediaQuery.of(navigator.context);
  final layout = SettingsUnfoldLayout.compute(
    anchor: anchor,
    screen: overlay.size,
    padding: media.padding,
    count: count,
    rowHeight: SettingsUnfoldLayout.rowHeight(anchorContext),
  );
  return navigator.push(
    SettingsUnfoldRoute(
      layout: layout,
      anchorBuilder: anchorBuilder,
      options: options,
    ),
  );
}

class SettingsUnfoldRoute extends PageRoute<void> {
  SettingsUnfoldRoute({
    required this.layout,
    required this.anchorBuilder,
    required this.options,
  });

  final SettingsUnfoldLayout layout;
  final Widget Function(BuildContext context, Animation<double> open)
  anchorBuilder;
  final UnfoldOptionsBuilder options;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => layout.total;

  @override
  Duration get reverseTransitionDuration => layout.total;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _SettingsUnfoldPage(route: this, animation: animation);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class _SettingsUnfoldPage extends ConsumerStatefulWidget {
  const _SettingsUnfoldPage({required this.route, required this.animation});

  final SettingsUnfoldRoute route;
  final Animation<double> animation;

  @override
  ConsumerState<_SettingsUnfoldPage> createState() =>
      _SettingsUnfoldPageState();
}

class _SettingsUnfoldPageState extends ConsumerState<_SettingsUnfoldPage> {
  int? _open;
  double _lift = 0;
  final _fieldKey = GlobalKey();

  SettingsUnfoldLayout get layout => widget.route.layout;

  void _close() {
    if (widget.animation.status == AnimationStatus.reverse) return;
    Navigator.of(context).maybePop();
  }

  void _toggle(int index) => setState(() {
    _open = _open == index ? null : index;
  });

  void _collapse(int index) {
    if (mounted && _open == index) setState(() => _open = null);
  }

  /// Keeps an open field above the keyboard by lifting the whole unfold.
  void _keepFieldVisible(double keyboard) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
      var lift = 0.0;
      if (keyboard > 0 && box != null && box.attached) {
        final bottom = box.localToGlobal(Offset(0, box.size.height)).dy + _lift;
        final visible =
            MediaQuery.sizeOf(context).height -
            keyboard -
            SettingsUnfoldLayout.edge;
        lift = math.max(0, bottom - visible);
      }
      if ((lift - _lift).abs() > 0.5) setState(() => _lift = lift);
    });
  }

  Widget _option(UnfoldOption option, int index) {
    final up = layout.isUp(index);
    final animation = CurvedAnimation(
      parent: widget.animation,
      curve: layout.interval(index, SurgeMotion.enterCurve),
      reverseCurve: layout.interval(index, SurgeMotion.exitCurve),
    );
    final reduce = MediaQuery.disableAnimationsOf(context);
    final card = _UnfoldOptionCard(
      key: ValueKey('unfold-option-$index'),
      option: option,
      open: _open == index,
      growUp: up,
      fieldKey: _open == index ? _fieldKey : null,
      onToggle: () => _toggle(index),
      onDone: () => _collapse(index),
      onLink: () {
        final link = option as UnfoldLink;
        Navigator.of(context).pop();
        link.onTap();
      },
    );
    return FadeTransition(
      opacity: animation,
      child: reduce
          ? card
          : SlideTransition(
              position: Tween(
                begin: Offset(0, up ? 1 : -1),
                end: Offset.zero,
              ).animate(animation),
              child: card,
            ),
    );
  }

  List<Widget> _spaced(Iterable<Widget> children) => [
    for (final (index, child) in children.indexed) ...[
      if (index > 0) const SizedBox(height: SettingsUnfoldLayout.gap),
      child,
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final options = widget.route.options(context, ref);
    _keepFieldVisible(MediaQuery.viewInsetsOf(context).bottom);
    final anchor = layout.anchor;
    final scrim = CurvedAnimation(
      parent: widget.animation,
      curve: layout.scrimInterval(SurgeMotion.enterCurve),
      reverseCurve: layout.scrimInterval(SurgeMotion.exitCurve),
    );
    final count = math.min(options.length, layout.count);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: context.appLocalizations.collapse,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: FadeTransition(
                  opacity: scrim,
                  child: ColoredBox(
                    color: SurgePalette.scrim.withValues(
                      alpha: SurgeMotion.modalBarrierOpacity,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The anchor was measured in the navigator's box: lay out in it too.
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) {
                final size = box.biggest;
                return TweenAnimationBuilder<double>(
                  tween: Tween(end: _lift),
                  duration: SurgeMotion.container,
                  curve: SurgeMotion.stateCurve,
                  builder: (context, lift, child) => Transform.translate(
                    offset: Offset(0, -lift),
                    child: child,
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: anchor.left,
                        width: anchor.width,
                        top: layout.topLimit,
                        bottom:
                            size.height - anchor.top + SettingsUnfoldLayout.gap,
                        // Grows past its room rather than clipping an open editor.
                        child: OverflowBox(
                          alignment: Alignment.bottomCenter,
                          minHeight: 0,
                          maxHeight: double.infinity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _spaced([
                              for (
                                var i = 0;
                                i < math.min(layout.up, count);
                                i++
                              )
                                _option(options[i], i),
                            ]),
                          ),
                        ),
                      ),
                      Positioned(
                        left: anchor.left,
                        width: anchor.width,
                        top: anchor.bottom + SettingsUnfoldLayout.gap,
                        bottom: size.height - layout.bottomLimit,
                        // Grows past its room rather than clipping an open editor.
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          minHeight: 0,
                          maxHeight: double.infinity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _spaced([
                              for (var i = layout.up; i < count; i++)
                                _option(options[i], i),
                            ]),
                          ),
                        ),
                      ),
                      Positioned.fromRect(
                        rect: anchor,
                        child: Semantics(
                          button: true,
                          expanded: true,
                          onTapHint: context.appLocalizations.collapse,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _close,
                            child: widget.route.anchorBuilder(context, scrim),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UnfoldOptionCard extends StatelessWidget {
  const _UnfoldOptionCard({
    super.key,
    required this.option,
    required this.open,
    required this.growUp,
    required this.onToggle,
    required this.onDone,
    required this.onLink,
    this.fieldKey,
  });

  final UnfoldOption option;
  final bool open;
  final bool growUp;
  final VoidCallback onToggle;
  final VoidCallback onDone;
  final VoidCallback onLink;
  final Key? fieldKey;

  void _tapHead(BuildContext context) {
    final reason = option.disabledReason;
    if (reason != null) {
      context.showNotifier(reason);
      return;
    }
    switch (option) {
      case final UnfoldSwitch option:
        option.onChanged(!option.value);
      case UnfoldLink():
        onLink();
      default:
        onToggle();
    }
  }

  /// A pick applies at once and folds the editor shortly after.
  void _picked(VoidCallback apply) {
    apply();
    Future.delayed(SurgeMotion.reveal, onDone);
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final disabled = option.disabledReason != null;
    final radius = BorderRadius.circular(surge.radii.list);
    final editor = open ? _editor(context) : null;
    return Opacity(
      opacity: disabled ? SurgeAlpha.a48 : SurgeAlpha.full,
      child: AnimatedContainer(
        duration: SurgeMotion.state,
        decoration: BoxDecoration(
          color: surge.elevatedCard,
          borderRadius: radius,
          border: Border.all(
            color: open ? surge.primary : surge.separator,
            width: surge.spacing.hairline * 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: AnimatedSize(
            duration: SurgeMotion.container,
            curve: SurgeMotion.stateCurve,
            alignment: growUp ? Alignment.bottomCenter : Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _head(context),
                if (editor != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SurgeSpace.m,
                      SurgeSpace.xxs,
                      SurgeSpace.m,
                      SurgeSpace.m,
                    ),
                    child: editor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _head(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final valueStyle = context.typography.technical.copyWith(
      color: surge.primary,
    );
    final turn = AnimatedRotation(
      turns: open ? 0.5 : 0,
      duration: SurgeMotion.container,
      child: Icon(
        SurgeIcons.expand,
        size: SurgeIconSize.inline,
        color: open ? surge.primary : surge.textSecondary,
      ),
    );
    final Widget trailing = switch (option) {
      final UnfoldSwitch option => SurgeSwitch(
        value: option.value,
        onChanged: option.disabledReason == null ? option.onChanged : null,
      ),
      final UnfoldChoice option => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _Value(option.valueLabel, style: valueStyle)),
          const SizedBox(width: SurgeSpace.xs),
          turn,
        ],
      ),
      final UnfoldSwatches option => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: SurgeIconSize.micro,
            height: SurgeIconSize.micro,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: option.colors[option.index],
            ),
          ),
          const SizedBox(width: SurgeSpace.xs + SurgeSpace.xxs),
          Flexible(
            child: _Value(option.names[option.index], style: valueStyle),
          ),
          const SizedBox(width: SurgeSpace.xs),
          turn,
        ],
      ),
      final UnfoldField option => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _Value(option.summary ?? '', style: valueStyle)),
          const SizedBox(width: SurgeSpace.s),
          Icon(
            SurgeIcons.edit,
            size: SurgeIconSize.inline,
            color: open ? surge.primary : surge.textSecondary,
          ),
        ],
      ),
      final UnfoldLink option => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (option.value != null)
            Flexible(
              child: _Value(
                option.value!,
                style: context.typography.technical.copyWith(
                  color: surge.textSecondary,
                ),
              ),
            ),
          Icon(
            SurgeIcons.chevronRight,
            size: SurgeIconSize.regular,
            color: surge.textSecondary,
          ),
        ],
      ),
    };
    final toggled = option is UnfoldSwitch
        ? (option as UnfoldSwitch).value
        : null;
    return Semantics(
      button: true,
      toggled: toggled,
      expanded: option is UnfoldLink || option is UnfoldSwitch ? null : open,
      child: SurgePressable(
        onTap: () => _tapHead(context),
        scaleFeedback: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: SettingsUnfoldLayout.rowHeight(context),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SurgeSpace.l,
              SurgeSpace.s,
              SurgeSpace.m,
              SurgeSpace.s,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.controlLabel.copyWith(
                      color: surge.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: SurgeSpace.m),
                Flexible(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailing,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _editor(BuildContext context) => switch (option) {
    final UnfoldChoice option => option._editor(_picked),
    final UnfoldSwatches option => _SwatchEditor(
      option: option,
      onPicked: (apply) => _picked(apply),
    ),
    final UnfoldField option => _FieldEditor(
      key: fieldKey,
      option: option,
      onDone: onDone,
    ),
    _ => null,
  };
}

class _Value extends StatelessWidget {
  const _Value(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.end,
    style: style,
  );
}

class _ChoiceEditor<T> extends StatelessWidget {
  const _ChoiceEditor({required this.option, required this.onPicked});

  final UnfoldChoice<T> option;
  final void Function(VoidCallback apply) onPicked;

  @override
  Widget build(BuildContext context) {
    if (option.style == UnfoldChoiceStyle.segments) {
      return SurgeSegmentedControl<T>(
        value: option.value,
        items: [
          for (final value in option.values)
            SurgeSegmentedItem(value: value, label: option.labelOf(value)),
        ],
        onChanged: (value) => onPicked(() => option.onChanged(value)),
      );
    }
    final surge = SurgeTheme.of(context);
    return Wrap(
      spacing: SurgeSpace.xs + SurgeSpace.xxs,
      runSpacing: SurgeSpace.xs + SurgeSpace.xxs,
      children: [
        for (final value in option.values)
          Builder(
            builder: (context) {
              final selected = value == option.value;
              final radius = BorderRadius.circular(surge.radii.button);
              return Semantics(
                button: true,
                selected: selected,
                child: SurgePressable(
                  onTap: () => onPicked(() => option.onChanged(value)),
                  borderRadius: radius,
                  child: AnimatedContainer(
                    duration: SurgeMotion.state,
                    padding: const EdgeInsets.symmetric(
                      horizontal: SurgeSpace.m,
                      vertical: SurgeSpace.xs + SurgeSpace.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? surge.primary.withValues(alpha: SurgeAlpha.a16)
                          : null,
                      borderRadius: radius,
                      border: Border.all(
                        color: selected ? surge.primary : surge.separator,
                      ),
                    ),
                    child: Text(
                      option.labelOf(value),
                      style: context.typography.technical.copyWith(
                        color: selected ? surge.primary : surge.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _SwatchEditor extends StatelessWidget {
  const _SwatchEditor({required this.option, required this.onPicked});

  static const double size = 34;

  final UnfoldSwatches option;
  final void Function(VoidCallback apply) onPicked;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Row(
      children: [
        for (final (index, color) in option.colors.indexed) ...[
          if (index > 0) const SizedBox(width: SurgeSpace.m),
          Semantics(
            button: true,
            selected: index == option.index,
            label: option.names[index],
            child: SurgePressable(
              onTap: () => onPicked(() => option.onChanged(index)),
              borderRadius: BorderRadius.circular(size / 2),
              child: AnimatedContainer(
                duration: SurgeMotion.state,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: index == option.index
                        ? surge.textPrimary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: index == option.index
                    ? Icon(
                        SurgeIcons.confirm,
                        size: SurgeIconSize.inline,
                        color: surge.onPrimary,
                      )
                    : null,
              ),
            ),
          ),
        ],
        const SizedBox(width: SurgeSpace.m),
        Expanded(
          child: Text(
            option.names[option.index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.supporting.copyWith(
              color: surge.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldEditor extends StatefulWidget {
  const _FieldEditor({super.key, required this.option, required this.onDone});

  final UnfoldField option;
  final VoidCallback onDone;

  @override
  State<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<_FieldEditor> {
  late final _controller = TextEditingController(text: widget.option.value);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    final error = widget.option.validator(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    widget.option.onSubmitted(value);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    final help = _error ?? widget.option.hint;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onDone,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: widget.option.keyboardType,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  style: context.typography.technical.copyWith(
                    color: surge.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.option.label,
                  ),
                ),
              ),
              const SizedBox(width: SurgeSpace.s),
              IconButton.filled(
                tooltip: l10n.save,
                onPressed: _submit,
                icon: const Icon(SurgeIcons.confirm),
              ),
              IconButton(
                tooltip: l10n.cancel,
                onPressed: widget.onDone,
                icon: const Icon(SurgeIcons.close),
              ),
            ],
          ),
          if (help != null) ...[
            const SizedBox(height: SurgeSpace.xs),
            Text(
              help,
              style: context.typography.supporting.copyWith(
                color: _error != null ? surge.red : surge.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
