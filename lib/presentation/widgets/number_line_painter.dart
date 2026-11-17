import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../domain/math_engine/models/inequality_models.dart';
import 'casio_lcd_screen.dart';
import '../painters/number_line_painter.dart';

export '../painters/number_line_painter.dart';

/// Widget visual para la recta real de inecuaciones (1.º grado, 2.º grado, valor absoluto y sistemas 1D).
class NumberLineWidget extends StatelessWidget {
  final Inequality1DVisualData data;
  final bool isOledDark;
  final double height;

  const NumberLineWidget({
    super.key,
    required this.data,
    this.isOledDark = false,
    this.height = 135,
  });

  @override
  Widget build(BuildContext context) {
    const paddingX = 44.0;
    final labelColor = isOledDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);

    return LayoutBuilder(
      builder: (context, constraints) {
        final actualH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : height;
        final hasSol = data.solutionLatex.isNotEmpty && actualH >= 65.0;
        // En LCD muy baja (apaisado) se oculta la barra de título para no desbordar.
        final showHeader = actualH >= 44.0;

        return Container(
          width: double.infinity,
          height: constraints.maxHeight.isFinite ? null : height,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: isOledDark ? const Color(0xFF14181B) : const Color(0xFFE8EFEA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isOledDark ? const Color(0xFF334155) : const Color(0xFF94A3B8),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra superior: Título didáctico y Solución en intervalo
              // (altura fija: evita overflow vertical en LCD apaisada baja)
              if (showHeader)
              SizedBox(
                height: 16,
                child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    data.isSystem
                        ? 'SISTEMA 1D (INTERSECCIÓN)'
                        : 'RECTA REAL DE SIGNOS',
                    style: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: isOledDark ? const Color(0xFF38BDF8) : const Color(0xFF0F766E),
                    ),
                  ),
                  if (hasSol)
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Math.tex(
                            CasioLcdScreen.sanitizeForMathTex(data.solutionLatex),
                            textStyle: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              color: labelColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                ),
              ),
              if (showHeader) const SizedBox(height: 2),

              // Área de dibujo CustomPaint
              Expanded(
                child: LayoutBuilder(
                  builder: (context, innerBox) {
                    final w = innerBox.maxWidth;
                    final h = innerBox.maxHeight;
                    if (w <= 0 || h <= 0) return const SizedBox.shrink();

                    final vals = data.criticalPoints.map((p) => p.value).toList();
                    final double minVal;
                    final double maxVal;

                    if (vals.isEmpty) {
                      minVal = -5.0;
                      maxVal = 5.0;
                    } else if (vals.length == 1) {
                      minVal = vals.first - 4.0;
                      maxVal = vals.first + 4.0;
                    } else {
                      final vMin = vals.reduce(math.min);
                      final vMax = vals.reduce(math.max);
                      final span = (vMax - vMin).abs();
                      final margin = math.max(1.5, span * 0.35);
                      minVal = vMin - margin;
                      maxVal = vMax + margin;
                    }

                    final centerY = (h * 0.42).clamp(18.0, 38.0);

                    return Stack(
                      children: [
                        CustomPaint(
                          size: Size(w, h),
                          painter: NumberLinePainter(
                            data: data,
                            isOledDark: isOledDark,
                            paddingX: paddingX,
                            centerY: centerY,
                            minVal: minVal,
                            maxVal: maxVal,
                          ),
                        ),

                        // Etiquetas de valores debajo de cada punto crítico usando Math.tex
                        for (final cp in data.criticalPoints)
                          Builder(
                            builder: (context) {
                              final drawW = w - 2 * paddingX;
                              final t = (cp.value - minVal) / (maxVal - minVal);
                              final sx = paddingX + t.clamp(0.0, 1.0) * drawW;

                              return Positioned(
                                left: sx - 24,
                                top: centerY + 8,
                                width: 48,
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Math.tex(
                                      CasioLcdScreen.sanitizeForMathTex(cp.label),
                                      textStyle: TextStyle(
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.bold,
                                        color: labelColor,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
