import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class LoginBackground extends StatelessWidget {
  const LoginBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.black, Color(0xFF07150F), Color(0xFF020403)],
            stops: [0, .52, 1],
          ),
        ),
        child: CustomPaint(painter: _CanvasPainter()),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.emerald.withValues(alpha: .22),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .86, size.height * .12),
              radius: size.shortestSide * .72,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * .86, size.height * .12),
      size.shortestSide * .72,
      glow,
    );

    final ribbon = Path()
      ..moveTo(-size.width * .2, size.height * .73)
      ..cubicTo(
        size.width * .15,
        size.height * .57,
        size.width * .48,
        size.height * .94,
        size.width * 1.2,
        size.height * .63,
      )
      ..lineTo(size.width * 1.2, size.height)
      ..lineTo(-size.width * .2, size.height)
      ..close();
    canvas.drawPath(
      ribbon,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.forest.withValues(alpha: .12),
            AppColors.emerald.withValues(alpha: .22),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );

    final linePaint = Paint()
      ..color = AppColors.mint.withValues(alpha: .07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var index = 0; index < 5; index++) {
      final path = Path();
      for (double x = 0; x <= size.width; x += 12) {
        final y =
            size.height * (.18 + index * .15) + math.sin(x / 55 + index) * 14;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
