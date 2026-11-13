import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/math_engine/solvers/function_graph_solver.dart';

class CasioGraphCanvas extends StatefulWidget {
  final FunctionAnalysisResult analysisResult;
  final bool isStickerMode;
  final NotablePoint? selectedPoint;
  final ValueChanged<NotablePoint?>? onPointSelected;

  const CasioGraphCanvas({
    super.key,
    required this.analysisResult,
    this.isStickerMode = false,
    this.selectedPoint,
    this.onPointSelected,
  });

  @override
  State<CasioGraphCanvas> createState() => _CasioGraphCanvasState();
}

class _CasioGraphCanvasState extends State<CasioGraphCanvas> {
  double _scale = 28.0; // Píxeles por unidad matemática
  Offset _panOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _centerOnVertexOrOrigin();
  }

  @override
  void didUpdateWidget(covariant CasioGraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.analysisResult != widget.analysisResult) {
      _centerOnVertexOrOrigin();
    }
  }

  void _centerOnVertexOrOrigin() {
    if (widget.analysisResult.isQuadratic &&
        widget.analysisResult.vertexX != null &&
        widget.analysisResult.vertexY != null) {
      _panOffset = Offset(
        -widget.analysisResult.vertexX! * _scale,
        widget.analysisResult.vertexY! * _scale,
      );
    } else {
      _panOffset = Offset.zero;
    }
  }

  void _zoomIn() {
    setState(() {
      _scale = (_scale * 1.25).clamp(10.0, 80.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _scale = (_scale / 1.25).clamp(10.0, 80.0);
    });
  }

  void _handleTapUp(TapUpDetails details, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + _panOffset;
    NotablePoint? closest;
    double minDistance = 24.0; // Radio de detección táctil en píxeles

    for (final point in widget.analysisResult.notablePoints) {
      final px = center.dx + point.x * _scale;
      final py = center.dy - point.y * _scale;
      final dist = (details.localPosition - Offset(px, py)).distance;
      if (dist < minDistance) {
        minDistance = dist;
        closest = point;
      }
    }

    widget.onPointSelected?.call(closest);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isStickerMode
        ? Colors.transparent
        : const Color(0xFFDDE6DF);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.isStickerMode ? 0 : 8.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _panOffset += details.delta;
                  });
                },
                onTapUp: (details) => _handleTapUp(details, size),
                child: CustomPaint(
                  size: size,
                  painter: CasioGraphPainter(
                    analysisResult: widget.analysisResult,
                    scale: _scale,
                    panOffset: _panOffset,
                    isStickerMode: widget.isStickerMode,
                    selectedPoint: widget.selectedPoint,
                  ),
                ),
              );
            },
          ),

          // Botones de control de Zoom y Centrado en pantalla Casio
          if (!widget.isStickerMode)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xCC141A17),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniGraphButton(
                      icon: Icons.add,
                      tooltip: 'Zoom +',
                      onPressed: _zoomIn,
                    ),
                    const SizedBox(width: 4),
                    _MiniGraphButton(
                      icon: Icons.remove,
                      tooltip: 'Zoom -',
                      onPressed: _zoomOut,
                    ),
                    const SizedBox(width: 4),
                    _MiniGraphButton(
                      icon: Icons.filter_center_focus,
                      tooltip: 'Centrar',
                      onPressed: () {
                        setState(() {
                          _centerOnVertexOrOrigin();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniGraphButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MiniGraphButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}

class CasioGraphPainter extends CustomPainter {
  final FunctionAnalysisResult analysisResult;
  final double scale;
  final Offset panOffset;
  final bool isStickerMode;
  final NotablePoint? selectedPoint;

  CasioGraphPainter({
    required this.analysisResult,
    required this.scale,
    required this.panOffset,
    required this.isStickerMode,
    this.selectedPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + panOffset;

    // Paleta de colores según el modo
    final gridColor = isStickerMode
        ? const Color(0x3364748B)
        : const Color(0xFFBAC7BE);
    final axesColor = isStickerMode
        ? const Color(0xFF1E293B)
        : const Color(0xFF141A17);
    final curveColor = isStickerMode
        ? const Color(0xFF2563EB)
        : const Color(0xFF0F766E);
    final symmetryColor = isStickerMode
        ? const Color(0x883B82F6)
        : const Color(0x88000000);

    // 1. Dibujar Rejilla Cartesiana Milimetrada
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    final xMin = -((center.dx) / scale).ceil() - 1;
    final xMax = ((size.width - center.dx) / scale).ceil() + 1;
    final yMin = -((size.height - center.dy) / scale).ceil() - 1;
    final yMax = ((center.dy) / scale).ceil() + 1;

    for (int x = xMin; x <= xMax; x++) {
      final px = center.dx + x * scale;
      canvas.drawLine(Offset(px, 0), Offset(px, size.height), gridPaint);
    }
    for (int y = yMin; y <= yMax; y++) {
      final py = center.dy - y * scale;
      canvas.drawLine(Offset(0, py), Offset(size.width, py), gridPaint);
    }

    // 2. Dibujar Ejes de Coordenadas (X e Y) con flechas
    final axesPaint = Paint()
      ..color = axesColor
      ..strokeWidth = 2.0;

    // Eje X
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      axesPaint,
    );
    // Flecha Eje X
    final xArrow = Path()
      ..moveTo(size.width, center.dy)
      ..lineTo(size.width - 8, center.dy - 4)
      ..lineTo(size.width - 8, center.dy + 4)
      ..close();
    canvas.drawPath(xArrow, Paint()..color = axesColor);

    // Eje Y
    canvas.drawLine(
      Offset(center.dx, size.height),
      Offset(center.dx, 0),
      axesPaint,
    );
    // Flecha Eje Y
    final yArrow = Path()
      ..moveTo(center.dx, 0)
      ..lineTo(center.dx - 4, 8)
      ..lineTo(center.dx + 4, 8)
      ..close();
    canvas.drawPath(yArrow, Paint()..color = axesColor);

    // Etiquetas numéricas en los ejes
    final textStyle = TextStyle(
      color: axesColor.withValues(alpha: 0.85),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    for (int x = xMin; x <= xMax; x++) {
      if (x == 0) continue;
      final px = center.dx + x * scale;
      final textSpan = TextSpan(text: '$x', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(px - textPainter.width / 2, center.dy + 3));
    }

    for (int y = yMin; y <= yMax; y++) {
      if (y == 0) continue;
      final py = center.dy - y * scale;
      final textSpan = TextSpan(text: '$y', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(center.dx - textPainter.width - 4, py - textPainter.height / 2));
    }

    // 3. Eje de simetría (si es parábola)
    if (analysisResult.isQuadratic && analysisResult.vertexX != null) {
      final symX = center.dx + analysisResult.vertexX! * scale;
      final dashPaint = Paint()
        ..color = symmetryColor
        ..strokeWidth = 1.5;

      double startY = 0;
      while (startY < size.height) {
        canvas.drawLine(
          Offset(symX, startY),
          Offset(symX, math.min(startY + 5, size.height)),
          dashPaint,
        );
        startY += 9;
      }
    }

    // 4. Curva de la Función Continua
    final curvePaint = Paint()
      ..color = curveColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final curvePath = Path();
    bool firstPoint = true;

    const double stepPx = 1.5;
    for (double px = 0; px <= size.width; px += stepPx) {
      final double xMath = (px - center.dx) / scale;
      final double yMath = analysisResult.evaluate(xMath);
      final double py = center.dy - yMath * scale;

      // Limitar coordenadas fuera de pantalla para evitar desbordes infinitos
      if (py < -size.height * 2 || py > size.height * 3) {
        firstPoint = true;
        continue;
      }

      if (firstPoint) {
        curvePath.moveTo(px, py);
        firstPoint = false;
      } else {
        curvePath.lineTo(px, py);
      }
    }
    canvas.drawPath(curvePath, curvePaint);

    // 5. Puntos Notables (Vértice, Cortes con los ejes)
    for (final point in analysisResult.notablePoints) {
      final px = center.dx + point.x * scale;
      final py = center.dy - point.y * scale;

      if (px < -20 || px > size.width + 20 || py < -20 || py > size.height + 20) {
        continue;
      }

      final isSelected = selectedPoint == point;
      final isVertex = point.type == PointType.vertex;

      final pointColor = isVertex
          ? const Color(0xFF2563EB) // Azul Vértice
          : (point.type == PointType.xIntercept
              ? const Color(0xFFDC2626) // Rojo Corte X
              : const Color(0xFFD97706)); // Naranja Corte Y

      // Círculo exterior destacado si está seleccionado
      if (isSelected) {
        canvas.drawCircle(
          Offset(px, py),
          10.0,
          Paint()..color = pointColor.withValues(alpha: 0.35),
        );
      }

      // Punto central
      canvas.drawCircle(
        Offset(px, py),
        isVertex ? 5.5 : 4.5,
        Paint()..color = pointColor,
      );
      canvas.drawCircle(
        Offset(px, py),
        isVertex ? 5.5 : 4.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Etiqueta flotante con el nombre del punto y coordenadas
      final labelSpan = TextSpan(
        text: '${point.label} (${point.x % 1 == 0 ? point.x.toInt() : point.x.toStringAsFixed(1)}, ${point.y % 1 == 0 ? point.y.toInt() : point.y.toStringAsFixed(1)})',
        style: TextStyle(
          color: isStickerMode ? const Color(0xFF0F172A) : const Color(0xFF141A17),
          fontSize: 9.5,
          fontWeight: isSelected || isVertex ? FontWeight.bold : FontWeight.w600,
          backgroundColor: isStickerMode ? Colors.white.withValues(alpha: 0.7) : const Color(0xCCCBD5CE),
        ),
      );

      final labelPainter = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final labelOffset = Offset(
        px + 6,
        isVertex && analysisResult.a > 0 ? py + 4 : py - labelPainter.height - 4,
      );
      labelPainter.paint(canvas, labelOffset);
    }
  }

  @override
  bool shouldRepaint(covariant CasioGraphPainter oldDelegate) {
    return oldDelegate.analysisResult != analysisResult ||
        oldDelegate.scale != scale ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.isStickerMode != isStickerMode ||
        oldDelegate.selectedPoint != selectedPoint;
  }
}
