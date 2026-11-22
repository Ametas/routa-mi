import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/views/dashboard/dashboard_layout.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widgets/home_group_panel.dart';
import 'package:fl_clash/views/dashboard/widgets/home_ip_card.dart';
import 'package:fl_clash/views/dashboard/widgets/home_panels.dart';
import 'package:fl_clash/views/desktop_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

import 'widgets/surge_dashboard_hero.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = ref.watch(
      navigationStateProvider.select(
        (state) => state.viewMode == ViewMode.mobile,
      ),
    );
    if (NavigationTrace.enabled) {
      NavigationTrace.noteHotspotBuild('dashboard_view');
    }
    final mediaQuery = MediaQuery.of(context);
    final pageBackground = SurgeTheme.of(context).background;
    final bottomPadding = SurgeBottomNavLayout.mainPageBottomPadding(context);

    return MediaQuery(
      data: mediaQuery,
      // No title bar: the brand bar opens the page (design 3.1).
      child: Scaffold(
        backgroundColor: pageBackground,
        body: SafeArea(
          bottom: false,
          child: ColoredBox(
            color: pageBackground,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = DashboardResponsiveLayout.fromViewport(
                  viewportWidth: constraints.maxWidth,
                );
                if (DesktopLayout.twoPane(constraints.maxWidth)) {
                  return _DesktopHome(
                    layout: layout,
                    bottomPadding: bottomPadding,
                  );
                }
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    layout.pageHorizontalPadding,
                    layout.pageTopPadding,
                    layout.pageHorizontalPadding,
                    bottomPadding +
                        DashboardResponsiveLayout.scrollEndBottomGap,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: layout.contentMaxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HomeBrandBar(showBrand: isMobile),
                          SizedBox(height: layout.cardGap),
                          SurgeDashboardHero(layout: layout),
                          SizedBox(height: layout.cardGap),
                          const HomeNetworkPanel(),
                          SizedBox(height: layout.cardGap),
                          const HomeIpCard(),
                          SizedBox(height: layout.cardGap),
                          const HomeGroupPanel(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Home in a wide window (design artifact "RoutaMi for Windows"): the route,
/// modes, network and IP on the left; the shown group fills the right
/// column's height and scrolls inside.
class _DesktopHome extends StatelessWidget {
  const _DesktopHome({required this.layout, required this.bottomPadding});

  final DashboardResponsiveLayout layout;
  final double bottomPadding;

  /// The left column is a little wider, as in the artifact.
  static const int leftFlex = 21;
  static const int rightFlex = 20;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.pageHorizontalPadding,
        layout.pageTopPadding,
        layout.pageHorizontalPadding,
        bottomPadding + layout.pageTopPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HomeBrandBar(showBrand: false),
          SizedBox(height: layout.cardGap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: leftFlex,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SurgeDashboardHero(layout: layout),
                        SizedBox(height: layout.cardGap),
                        const HomeNetworkPanel(),
                        SizedBox(height: layout.cardGap),
                        const HomeIpCard(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: DesktopLayout.paneGap),
                const Expanded(
                  flex: rightFlex,
                  child: HomeGroupPanel(expand: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
