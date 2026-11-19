import 'package:flutter/material.dart';

import '../theme/calculator_themes.dart';

/// Pintor del cuerpo del D-Pad segun la morfologia del tema activo.
/// `Predeterminado` conserva exactamente el aspecto original.
abstract final class DPadMorphologyStyle {
  static BoxDecoration outer(CalculatorHardwareTheme hw, double height) {
    if (hw.isDefault) {
      return BoxDecoration(
        color: const Color(0xFF2A2E37),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: const Color(0xFF474E5D), width: 1.8),
        boxShadow: const [
          BoxShadow(color: Color(0xB3000000), offset: Offset(0, 4), blurRadius: 6.0),
          BoxShadow(color: Color(0x26FFFFFF), offset: Offset(0, -1), blurRadius: 1.0),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF333844), Color(0xFF2A2E37), Color(0xFF1B1E24)],
        ),
      );
    }
    switch (hw.dpad) {
      case DPadMorphology.retroCross:
        return const BoxDecoration(); // la cruz se dibuja en el fondo
      case DPadMorphology.minimalRing:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: hw.dpadBorder, width: 1.6),
          color: hw.dpadBody,
        );
      case DPadMorphology.circularPetal:
        return BoxDecoration(
          color: hw.dpadBody,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: hw.dpadBorder, width: 2.0),
          boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 3), blurRadius: 4)],
        );
      case DPadMorphology.defaultOriginal:
        return BoxDecoration(
          color: hw.dpadBody,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: hw.dpadBorder, width: 1.8),
          boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 3), blurRadius: 5)],
        );
    }
  }

  /// Fondo extra (cruceta retro o petalos) bajo las flechas.
  static Widget? backdrop(CalculatorHardwareTheme hw) {
    if (hw.isDefault) return null;
    if (hw.dpad == DPadMorphology.retroCross) {
      return Positioned.fill(child: CustomPaint(painter: _CrossPainter(hw.dpadBody, hw.dpadBorder)));
    }
    if (hw.dpad == DPadMorphology.circularPetal) {
      return Positioned.fill(child: CustomPaint(painter: _PetalPainter(hw.dpadBorder)));
    }
    return null;
  }

  static Color ringColor(CalculatorHardwareTheme hw) =>
      hw.isDefault ? const Color(0xFF3E4554).withValues(alpha: 0.6) : hw.dpadBorder.withValues(alpha: 0.35);

  static bool showRing(CalculatorHardwareTheme hw) =>
      hw.isDefault || hw.dpad == DPadMorphology.defaultOriginal || hw.dpad == DPadMorphology.minimalRing;

  static Color icon(CalculatorHardwareTheme hw) => hw.isDefault ? const Color(0xFFE2E8F0) : hw.dpadIcon;

  static Color accent(CalculatorHardwareTheme hw) => hw.isDefault ? const Color(0xFFE5A93C) : hw.appBarAccent;
}

class _CrossPainter extends CustomPainter {
  final Color fill;
  final Color border;
  _CrossPainter(this.fill, this.border);

  @override
  void paint(Canvas canvas, Size size) {
    final arm = size.height * 0.36;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: size.width * 0.86, height: arm), const Radius.circular(3)))
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: arm * 1.15, height: size.height), const Radius.circular(3)));
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = border);
  }

  @override
  bool shouldRepaint(covariant _CrossPainter old) => old.fill != fill || old.border != border;
}

class _PetalPainter extends CustomPainter {
  final Color line;
  _PetalPainter(this.line);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = line.withValues(alpha: 0.55);
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(Offset(size.width * 0.18, size.height * 0.18), Offset(c.dx - 6, c.dy - 5), p);
    canvas.drawLine(Offset(size.width * 0.82, size.height * 0.18), Offset(c.dx + 6, c.dy - 5), p);
    canvas.drawLine(Offset(size.width * 0.18, size.height * 0.82), Offset(c.dx - 6, c.dy + 5), p);
    canvas.drawLine(Offset(size.width * 0.82, size.height * 0.82), Offset(c.dx + 6, c.dy + 5), p);
  }

  @override
  bool shouldRepaint(covariant _PetalPainter old) => old.line != line;
}
