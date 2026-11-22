import 'package:fl_clash/widgets/surge/surge.dart';

/// When a main page switches to its desktop layout (design artifact
/// "RoutaMi for Windows"): two columns on Home, list and details on
/// Profiles, sections and their options on Settings.
///
/// Decided by the width the page itself gets, so a narrow window, or a
/// phone in landscape, keeps the phone layout.
abstract final class DesktopLayout {
  /// About a 1000 px window once the side menu takes its share.
  static const double twoPaneMinWidth = 760;

  /// Gap between the two panes.
  static const double paneGap = SurgeSpace.l;

  /// Left pane of Profiles and Settings.
  static const double listPaneWidth = 300;

  static bool twoPane(double width) => width >= twoPaneMinWidth;
}
