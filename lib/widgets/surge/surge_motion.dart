import 'package:flutter/material.dart';

/// Duration scale: the Material 3 motion steps (Flutter [Durations]).
/// Transitions use these steps only; looping ambient animations (hero fill,
/// sheen, spinners) are periods, not transitions, and live in [SurgeMotion].
abstract final class SurgeDuration {
  static const short1 = Durations.short1; // 50 ms
  static const short2 = Durations.short2; // 100 ms
  static const short3 = Durations.short3; // 150 ms
  static const short4 = Durations.short4; // 200 ms
  static const medium1 = Durations.medium1; // 250 ms
  static const medium2 = Durations.medium2; // 300 ms
  static const medium3 = Durations.medium3; // 350 ms
  static const medium4 = Durations.medium4; // 400 ms
  static const long1 = Durations.long1; // 450 ms
  static const long2 = Durations.long2; // 500 ms
  static const long3 = Durations.long3; // 550 ms
  static const long4 = Durations.long4; // 600 ms
  static const extralong1 = Durations.extralong1; // 700 ms
  static const extralong2 = Durations.extralong2; // 800 ms
  static const extralong3 = Durations.extralong3; // 900 ms
  static const extralong4 = Durations.extralong4; // 1000 ms

  static const values = <Duration>[
    short1,
    short2,
    short3,
    short4,
    medium1,
    medium2,
    medium3,
    medium4,
    long1,
    long2,
    long3,
    long4,
    extralong1,
    extralong2,
    extralong3,
    extralong4,
  ];

  /// Nearest step; ties go to the longer step.
  static Duration snap(Duration value) {
    var best = values.first;
    for (final step in values) {
      final distance = (step - value).abs();
      final bestDistance = (best - value).abs();
      if (distance < bestDistance ||
          (distance == bestDistance && step > best)) {
        best = step;
      }
    }
    return best;
  }
}

/// Motion roles. Transitions point at [SurgeDuration] steps.
class SurgeMotion {
  const SurgeMotion._();

  static const press = SurgeDuration.short2;
  static const state = SurgeDuration.short3;
  static const reveal = SurgeDuration.short4;
  static const container = SurgeDuration.short4;
  static const scroll = SurgeDuration.medium2;
  static const pageEnter = SurgeDuration.medium2;
  static const pageExit = SurgeDuration.short4;
  static const sheetEnter = SurgeDuration.medium2;
  static const sheetExit = SurgeDuration.short4;
  static const statusLightPulse = SurgeDuration.short2;

  /// Fade in/out of routes and overlays.
  static const fade = SurgeDuration.short4;

  /// Cross-fades and swaps of whole content blocks.
  static const contentSwap = SurgeDuration.medium2;

  /// Submenu slide inside a popup menu.
  static const menu = SurgeDuration.medium1;

  /// Chart value transitions.
  static const chart = SurgeDuration.medium2;

  /// How long a transient snackbar stays on screen.
  static const snackBar = Duration(milliseconds: 1500);

  // Looping ambient animations: periods, not transitions.
  static const heroFill = Duration(milliseconds: 1500);
  static const heroSheen = Duration(milliseconds: 1400);
  static const latencyFlow = Duration(milliseconds: 1300);
  static const loadingSpin = Duration(seconds: 3);
  static const loadingDots = Duration(seconds: 1);

  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;
  static const stateCurve = Curves.easeOutCubic;

  static const double pressedScale = 0.98;
  static const double compactPressedScale = 0.985;
  static const double pressedOverlayOpacity = 0.07;
  static const double revealOffset = 10;
  static const double modalBarrierOpacity = 0.52;
}
