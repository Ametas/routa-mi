import 'package:fl_clash/views/desktop_layout.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

/// The section a wide settings screen shows beside its list.
@immutable
class SettingsPaneSection {
  const SettingsPaneSection({required this.title, required this.page});

  final String title;
  final WidgetBuilder page;
}

/// Tells the settings rows that a pane beside them shows their pages: a tap
/// selects the section instead of opening it over the list.
class SettingsPaneScope extends InheritedWidget {
  const SettingsPaneScope({
    super.key,
    required this.selected,
    required this.onSelect,
    required super.child,
  });

  /// Title of the section in the pane.
  final String selected;
  final ValueChanged<SettingsPaneSection> onSelect;

  static SettingsPaneScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsPaneScope>();

  @override
  bool updateShouldNotify(SettingsPaneScope old) => old.selected != selected;
}

/// Settings in a wide window (design artifact "RoutaMi for Windows"): the
/// sections on the left, the selected one's page on the right. Switching
/// sections fades the old page out and slides the new one in.
class SettingsTwoPane extends StatefulWidget {
  const SettingsTwoPane({
    super.key,
    required this.initial,
    required this.list,
    this.padding = EdgeInsets.zero,
  });

  final SettingsPaneSection initial;

  /// The section rows; they find the pane through [SettingsPaneScope].
  final Widget list;
  final EdgeInsets padding;

  /// How far the incoming page slides, as a fraction of its width.
  static const double slide = 0.02;

  @override
  State<SettingsTwoPane> createState() => _SettingsTwoPaneState();
}

class _SettingsTwoPaneState extends State<SettingsTwoPane> {
  late SettingsPaneSection _section = widget.initial;

  void _select(SettingsPaneSection section) {
    if (section.title == _section.title) return;
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SettingsPaneScope(
      selected: _section.title,
      onSelect: _select,
      child: Padding(
        padding: widget.padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: DesktopLayout.listPaneWidth, child: widget.list),
            const SizedBox(width: DesktopLayout.paneGap),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: SurgeSpace.m),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surge.background,
                    borderRadius: BorderRadius.circular(surge.radii.card),
                    border: Border.all(
                      color: surge.separator,
                      width: surge.spacing.hairline,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(surge.radii.card),
                    child: AnimatedSwitcher(
                      duration: SurgeMotion.container,
                      switchInCurve: SurgeMotion.enterCurve,
                      switchOutCurve: SurgeMotion.exitCurve,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(SettingsTwoPane.slide, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_section.title),
                        child: Builder(builder: _section.page),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
