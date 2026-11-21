import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/views/dashboard/dashboard_layout.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widgets/home_group_panel.dart';
import 'package:fl_clash/views/dashboard/widgets/home_panels.dart';
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
                final viewportSize = MediaQuery.sizeOf(context);
                final layout = DashboardResponsiveLayout.fromViewport(
                  viewportWidth: constraints.maxWidth,
                  viewportHeight: viewportSize.height,
                  textScaler: MediaQuery.textScalerOf(context),
                );
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
