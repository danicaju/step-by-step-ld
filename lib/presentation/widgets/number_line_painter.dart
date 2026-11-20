import 'package:flutter/material.dart';

import '../../domain/math_engine/models/inequality_models.dart';
import '../painters/number_line_layout.dart';
import '../painters/number_line_painter.dart';
import '../painters/number_line_palette.dart';
import 'casio_lcd_screen.dart';
import 'safe_math.dart';

export '../painters/number_line_painter.dart';

/// Recta real de signos de las inecuaciones (M6, M7 1D). Se dibuja en su propio paso.
///
/// Altura holgada en tres bandas (SI / NO arriba, recta en el centro, etiquetas LaTeX abajo)
/// sin recortes: si la LCD es mas baja, todo el conjunto se escala (`FittedBox`) en vez de
/// cortarse. Con 4 o mas puntos criticos se desplaza horizontalmente.
class NumberLineWidget extends StatelessWidget {
  final Inequality1DVisualData data;
  final bool isOledDark;
  final double height;

  /// Alto minimo natural de la recta (cabecera + 3 bandas + margenes).
  static const double naturalHeight = 4 + 20 + 2 + NumberLineBands.body + 4 + 4;

  const NumberLineWidget({
    super.key,
    required this.data,
    this.isOledDark = false,
    this.height = naturalHeight,
  });

  @override
  Widget build(BuildContext context) {
    final pal = NumberLinePalette.of(dark: isOledDark);
    return LayoutBuilder(
      builder: (context, c) {
        final availW = c.maxWidth.isFinite ? c.maxWidth : 360.0;
        final panel = _panel(pal, availW);
        final natural = height < naturalHeight ? naturalHeight : height;
        if (c.maxHeight.isFinite && c.maxHeight < natural) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(width: availW, height: natural, child: panel),
          );
        }
        return Align(alignment: Alignment.center, child: SizedBox(width: availW, child: panel));
      },
    );
  }

  Widget _panel(NumberLinePalette pal, double availW) {
    final innerW = availW - 16;
    final layout = NumberLineLayout.of(data, innerW);
    Widget body = SizedBox(
      width: layout.contentWidth,
      height: NumberLineBands.body,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: NumberLinePainter(data: data, palette: pal, layout: layout)),
            ),
          ),
          for (final cp in data.criticalPoints) _label(cp, layout, pal),
        ],
      ),
    );
    if (layout.scrolls(innerW)) {
      body = SingleChildScrollView(scrollDirection: Axis.horizontal, child: body);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: pal.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pal.border, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 20, child: _header(pal)),
          const SizedBox(height: 2),
          body,
        ],
      ),
    );
  }

  Widget _header(NumberLinePalette pal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          data.isSystem ? 'INTERSECCIÓN EN LA RECTA REAL' : 'RECTA REAL DE SIGNOS',
          style: TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            color: pal.title,
          ),
        ),
        if (data.solutionLatex.isNotEmpty)
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SafeMath.tex(
                CasioLcdScreen.sanitizeForMathTex(data.solutionLatex),
                textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: pal.ink),
              ),
            ),
          ),
      ],
    );
  }

  Widget _label(CriticalPoint cp, NumberLineLayout layout, NumberLinePalette pal) {
    final w = layout.step;
    return Positioned(
      left: layout.x(cp.value) - w / 2,
      top: NumberLineBands.top + NumberLineBands.mid + 2,
      width: w,
      height: NumberLineBands.bottom - 4,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SafeMath.tex(
            CasioLcdScreen.sanitizeForMathTex(cp.label),
            textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: pal.ink),
          ),
        ),
      ),
    );
  }
}
