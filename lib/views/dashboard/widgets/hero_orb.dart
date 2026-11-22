import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The orb behind the start ring's label while the proxy runs (design
/// artifact "RoutaMi AMOLED"): a turning Julia set in [color], drawn by
/// `shaders/hero_orb.frag`.
///
/// Paints nothing until the shader has loaded, or at all where it cannot
/// load; the ring then reads as before. Time only advances while [animate]
/// is set and animations are allowed, so a still orb costs no frames.
class HeroOrb extends StatefulWidget {
  const HeroOrb({
    super.key,
    required this.color,
    required this.opacity,
    required this.animate,
  });

  final Color color;

  /// 0 hides the orb; the ring fades it in with its fill progress.
  final double opacity;
  final bool animate;

  /// Where a still orb starts: a frame with the fractal well inside the
  /// ring.
  static const double restTime = 8;

  static Future<ui.FragmentProgram?>? _program;

  /// Loads the shader once for every ring; null where it cannot load.
  static Future<ui.FragmentProgram?> loadProgram() {
    return _program ??= ui.FragmentProgram.fromAsset(
      'shaders/hero_orb.frag',
    ).then<ui.FragmentProgram?>((program) => program, onError: (_) => null);
  }

  @override
  State<HeroOrb> createState() => _HeroOrbState();
}

class _HeroOrbState extends State<HeroOrb> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _time = ValueNotifier<double>(HeroOrb.restTime);
  ui.FragmentShader? _shader;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    HeroOrb.loadProgram().then((program) {
      if (!mounted || program == null) return;
      setState(() => _shader = program.fragmentShader());
      _syncTicker();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(HeroOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  bool get _shouldTick =>
      _shader != null &&
      widget.animate &&
      widget.opacity > 0 &&
      !MediaQuery.disableAnimationsOf(context);

  void _syncTicker() {
    if (_shouldTick && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!_shouldTick && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final step =
        (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    // A long pause (the app in the background) must not jump the orb.
    _time.value += step.clamp(0, 0.05);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null || widget.opacity <= 0) return const SizedBox.expand();
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _OrbPainter(
          shader: shader,
          time: _time,
          color: widget.color,
          opacity: widget.opacity.clamp(0.0, 1.0),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.shader,
    required this.time,
    required this.color,
    required this.opacity,
  }) : super(repaint: time);

  final ui.FragmentShader shader;
  final ValueNotifier<double> time;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time.value)
      ..setFloat(3, color.r)
      ..setFloat(4, color.g)
      ..setFloat(5, color.b)
      ..setFloat(6, opacity);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.shader != shader || old.color != color || old.opacity != opacity;
}
