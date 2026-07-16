import 'dart:math';
import 'package:flutter/material.dart';
import 'theme.dart';
import 'voice.dart';

/// Animated voice orb. Colour reflects the engine state; radius pulses with
/// the live mic level.
class VoiceOrb extends StatefulWidget {
  final VoiceState state;
  final ValueListenable<double> level;
  const VoiceOrb({super.key, required this.state, required this.level});

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.state) {
      case VoiceState.listen:
        return OrbitColors.cyan;
      case VoiceState.rec:
        return OrbitColors.green;
      case VoiceState.think:
        return OrbitColors.violet;
      case VoiceState.talk:
        return OrbitColors.coral;
      case VoiceState.idle:
        return OrbitColors.textDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_c, widget.level]),
      builder: (_, __) {
        return CustomPaint(
          size: const Size(240, 240),
          painter: _OrbPainter(
            t: _c.value,
            level: widget.level.value.clamp(0.0, 0.6),
            color: _color,
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  final double level;
  final Color color;
  _OrbPainter({required this.t, required this.level, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.width * 0.28;
    final pulse = base * (1 + level * 1.6);

    // outer glow rings
    for (var i = 3; i >= 1; i--) {
      final p = Paint()
        ..color = color.withValues(alpha: 0.06 * i)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(c, pulse + i * 18.0 + sin(t * 2 * pi) * 4, p);
    }
    // core gradient
    final rect = Rect.fromCircle(center: c, radius: pulse);
    final core = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.35)],
      ).createShader(rect);
    canvas.drawCircle(c, pulse, core);

    // rotating highlight
    final hi = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final a = t * 2 * pi;
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: pulse * 0.82), a, 1.4, false, hi);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.t != t || old.level != level || old.color != color;
}
