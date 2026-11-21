import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/views/dashboard/dashboard.dart';
import 'package:fl_clash/views/dashboard/dashboard_layout.dart';
import 'package:fl_clash/views/dashboard/widgets/surge_dashboard_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardResponsiveLayout _layout(double width) =>
    DashboardResponsiveLayout.fromViewport(viewportWidth: width);

void main() {
  test('the hero takes the page layout', () {
    final layout = _layout(384);
    expect(SurgeDashboardHero(layout: layout).layout, same(layout));
    expect(const DashboardView(), isA<DashboardView>());
  });

  group('DashboardResponsiveLayout', () {
    test('uses the measured 384dp phone as the visual baseline', () {
      final layout = _layout(384);
      expect(layout.geometryScale, 1);
      expect(layout.pageHorizontalPadding, 18);
      expect(layout.cardGap, 16);
      expect(layout.contentMaxWidth, double.infinity);
    });

    test('scales geometry down on a 360dp phone', () {
      final layout = _layout(360);
      expect(layout.geometryScale, 0.9375);
      expect(layout.geometry(16), 15);
    });

    test('uses a centered, bounded single column on wide screens', () {
      final layout = _layout(800);
      expect(layout.contentMaxWidth, 520);
      expect(layout.pageHorizontalPadding, 32);
      expect(layout.geometryScale, 1.07);
    });

    test('keeps the bottom gap after the last panel', () {
      expect(DashboardResponsiveLayout.scrollEndBottomGap, 30);
    });
  });

  group('heroOutboundFillActive', () {
    test('keeps outbound fill on smart pause even when VPN is not running', () {
      expect(
        heroOutboundFillActive(isStart: false, isSmartStopped: true),
        isTrue,
      );
    });

    test('keeps outbound fill while connected', () {
      expect(
        heroOutboundFillActive(isStart: true, isSmartStopped: false),
        isTrue,
      );
    });

    test('clears outbound fill when idle', () {
      expect(
        heroOutboundFillActive(isStart: false, isSmartStopped: false),
        isFalse,
      );
    });
  });

  group('heroActiveFillShouldAnimate', () {
    test('skips the first-mount no-op ticker when begin equals end', () {
      expect(
        heroActiveFillShouldAnimate(
          previous: null,
          next: const Color(0xFF1565C0),
        ),
        isFalse,
      );
      expect(
        heroActiveFillShouldAnimate(
          previous: const Color(0xFF1565C0),
          next: const Color(0xFF1565C0),
        ),
        isFalse,
      );
    });

    test('keeps active to paused color animation', () {
      expect(
        heroActiveFillShouldAnimate(
          previous: const Color(0xFF1565C0),
          next: const Color(0xFFFFC107),
        ),
        isTrue,
      );
    });
  });

  group('heroConnectingPulseActive', () {
    test('suppresses pulse on smart-pause even if Core is connecting', () {
      expect(
        heroConnectingPulseActive(
          isSmartStopped: true,
          coreStatus: CoreStatus.connecting,
          showConnecting: true,
        ),
        isFalse,
      );
    });

    test('suppresses leftover connecting timer on paused reopen', () {
      expect(
        heroConnectingPulseActive(
          isSmartStopped: true,
          coreStatus: CoreStatus.disconnected,
          showConnecting: true,
        ),
        isFalse,
      );
    });

    test('pulses while a real start is connecting', () {
      expect(
        heroConnectingPulseActive(
          isSmartStopped: false,
          coreStatus: CoreStatus.connecting,
          showConnecting: false,
        ),
        isTrue,
      );
    });

    test('pulses while the start timer is still showing connecting', () {
      expect(
        heroConnectingPulseActive(
          isSmartStopped: false,
          coreStatus: CoreStatus.disconnected,
          showConnecting: true,
        ),
        isTrue,
      );
    });

    test('idle disconnected does not pulse', () {
      expect(
        heroConnectingPulseActive(
          isSmartStopped: false,
          coreStatus: CoreStatus.disconnected,
          showConnecting: false,
        ),
        isFalse,
      );
    });
  });
}
