import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Draws a crisp orange "FOR SALE" corner ribbon in the bottom-right corner of a rabbit thumbnail or profile photo.
class SaleRibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ribbonExtent = w * 0.68;
    final bandThickness = w * 0.28;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final shadowPath = Path()
      ..moveTo(w - ribbonExtent - 1, h + 1)
      ..lineTo(w + 1, h - ribbonExtent - 1)
      ..lineTo(w + 1, h - (ribbonExtent - bandThickness) + 1)
      ..lineTo(w - (ribbonExtent - bandThickness) - 1, h + 1)
      ..close();
    canvas.drawPath(shadowPath, shadowPaint);

    final ribbonPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xFFE65100), Color(0xFFFF9100), Color(0xFFFFB300)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final ribbonPath = Path()
      ..moveTo(w - ribbonExtent, h)
      ..lineTo(w, h - ribbonExtent)
      ..lineTo(w, h - (ribbonExtent - bandThickness))
      ..lineTo(w - (ribbonExtent - bandThickness), h)
      ..close();
    canvas.drawPath(ribbonPath, ribbonPaint);

    // Subtle edge borders for crisp definition
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;
    canvas.drawLine(
      Offset(w - ribbonExtent, h),
      Offset(w, h - ribbonExtent),
      borderPaint,
    );
    canvas.drawLine(
      Offset(w - (ribbonExtent - bandThickness), h),
      Offset(w, h - (ribbonExtent - bandThickness)),
      borderPaint,
    );

    // Center of the diagonal band
    final midDist = (ribbonExtent - bandThickness / 2) / 2;
    final centerX = w - midDist;
    final centerY = h - midDist;

    final fontSize = (w * 0.085).clamp(5.5, 9.0);
    final letterSpacing = w < 70 ? 0.3 : 0.6;

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'FOR SALE',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: letterSpacing,
          shadows: const [
            Shadow(
              color: Color(0x66000000),
              offset: Offset(0, 1),
              blurRadius: 1,
            ),
          ],
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.rotate(-3.14159265 / 4);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
