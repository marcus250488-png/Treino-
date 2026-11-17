import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'telas.dart';

/// Caixa de água com onda animada. O nível sobe conforme a meta é atingida.
class OndaAgua extends StatefulWidget {
  final double prog; // 0..1
  const OndaAgua({super.key, required this.prog});
  @override
  State<OndaAgua> createState() => _OndaAguaEstado();
}

class _OndaAguaEstado extends State<OndaAgua>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: widget.prog),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, nivel, _) => AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: _OndaPainter(nivel, _c.value),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _OndaPainter extends CustomPainter {
  final double nivel;
  final double t;
  _OndaPainter(this.nivel, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = branco(.07));
    if (nivel <= 0) return;
    final base = size.height * (1 - nivel);
    const amp = 6.0;
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 4) {
      final y = base +
          amp *
              math.sin((x / size.width) * 2 * math.pi * 1.5 +
                  t * 2 * math.pi);
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [kAzul.withOpacity(.85), const Color(0xFF0A1F4D)],
    ).createShader(Offset.zero & size);
    canvas.drawPath(path, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _OndaPainter old) =>
      old.nivel != nivel || old.t != t;
}
