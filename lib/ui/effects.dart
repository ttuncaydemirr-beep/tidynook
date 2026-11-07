import 'dart:math' as math;

import 'package:flutter/material.dart';

const List<Color> _sparkColors = <Color>[
  Color(0xFFF6D26B),
  Color(0xFF9FD3C0),
  Color(0xFFF4A7B9),
  Color(0xFFFFFFFF),
  Color(0xFFCDBFE3),
];

class SparkParticle {
  const SparkParticle(this.angle, this.dist, this.radius, this.color);
  final double angle;
  final double dist;
  final double radius;
  final Color color;
}

/// One burst of coloured dots, like sparkle() in the HTML.
class SparkGroup {
  SparkGroup({
    required this.center,
    required this.start,
    required this.duration,
    required this.particles,
  });

  final Offset center;
  final double start; // ms on the owner's clock
  final double duration; // ms
  final List<SparkParticle> particles;

  static SparkGroup create(
    math.Random r,
    Offset center,
    double start, {
    double duration = 520,
    int count = 10,
    double minDist = 26,
    double maxDist = 48,
  }) {
    final list = <SparkParticle>[];
    for (var i = 0; i < count; i++) {
      list.add(SparkParticle(
        i / count * math.pi * 2 + (r.nextDouble() * 0.6 - 0.3),
        minDist + r.nextDouble() * (maxDist - minDist),
        2 + r.nextDouble() * 2,
        _sparkColors[i % _sparkColors.length],
      ));
    }
    return SparkGroup(
        center: center, start: start, duration: duration, particles: list);
  }

  double progress(double now) => ((now - start) / duration).clamp(0.0, 1.0);
}

/// Draws spark groups. `now` is the owner's clock in ms. `origin` is
/// subtracted from the centres (board space -> local space).
class SparkPainter extends CustomPainter {
  SparkPainter(this.groups, this.now, {this.origin = Offset.zero});

  final List<SparkGroup> groups;
  final double now;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final g in groups) {
      final k = g.progress(now);
      if (now < g.start || k >= 1) {
        continue;
      }
      final inv = 1 - k;
      final e = 1 - inv * inv;
      for (final p in g.particles) {
        final pos = g.center -
            origin +
            Offset(math.cos(p.angle), math.sin(p.angle)) * (p.dist * e);
        paint.color = p.color.withValues(alpha: (1 - k).clamp(0.0, 1.0));
        canvas.drawCircle(pos, p.radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SparkPainter oldDelegate) => true;
}
