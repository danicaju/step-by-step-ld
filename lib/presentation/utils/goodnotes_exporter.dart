import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/math_engine/models/step_resolution.dart';
import '../../domain/math_engine/solvers/function_graph_solver.dart';
import '../widgets/casio_graph_canvas.dart';
import '../widgets/casio_lcd_screen.dart';

/// Canvas dedicado para renderizado de stickers con estética de cuaderno / pizarra
class GoodnotesStickerCanvas extends StatelessWidget {
  final StepByStepResolution resolution;
  final FunctionAnalysisResult? graphAnalysis;

  const GoodnotesStickerCanvas({
    super.key,
    required this.resolution,
    this.graphAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del Sticker
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'CASIO CLASSWIZ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Resolución Paso a Paso',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Expresión inicial
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enunciado: ',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Math.tex(
                      CasioLcdScreen.sanitizeForMathTex(resolution.originalInputLatex),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.bold,
                      ),
                      onErrorFallback: (err) => Text(
                        resolution.originalInputLatex,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Gráfica cartesiana si estamos en modo funciones
          if (graphAnalysis != null) ...[
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: CasioGraphCanvas(
                analysisResult: graphAnalysis!,
                isStickerMode: true,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: graphAnalysis!.notablePoints.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.type == PointType.vertex
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: p.type == PointType.vertex
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  child: Text(
                    '${p.label}: (${p.x % 1 == 0 ? p.x.toInt() : p.x.toStringAsFixed(1)}, ${p.y % 1 == 0 ? p.y.toInt() : p.y.toStringAsFixed(1)})',
                    style: TextStyle(
                      color: p.type == PointType.vertex
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFFB91C1C),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],

          // Lista de pasos
          ...resolution.steps.map((step) => _buildStepCard(step)),

          const SizedBox(height: 10),

          // Resultado final destacado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Resultado: ',
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Math.tex(
                          CasioLcdScreen.sanitizeForMathTex(resolution.exactResultLatex),
                          textStyle: const TextStyle(
                            fontSize: 20,
                            color: Color(0xFF064E3B),
                            fontWeight: FontWeight.bold,
                          ),
                          onErrorFallback: (err) => Text(
                            resolution.exactResultLatex,
                            style: const TextStyle(fontSize: 16, color: Color(0xFF064E3B), fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (resolution.decimalApproxLatex.trim().isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Math.tex(
                            CasioLcdScreen.sanitizeForMathTex(
                              '(\\approx ${resolution.decimalApproxLatex})',
                            ),
                            textStyle: const TextStyle(
                              color: Color(0xFF047857),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            onErrorFallback: (err) => Text(
                              '(≈ ${resolution.decimalApproxLatex})',
                              style: const TextStyle(
                                color: Color(0xFF047857),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(MathStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título del paso con flecha de implicación
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Paso ${step.index}',
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '⇒',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  step.shortTitle,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Expresión LaTeX del paso
          Padding(
            padding: const EdgeInsets.only(left: 14.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Math.tex(
                CasioLcdScreen.sanitizeForMathTex(step.latexExpression),
                textStyle: const TextStyle(
                  fontSize: 17,
                  color: Color(0xFF1E293B),
                ),
                onErrorFallback: (err) => Text(
                  step.latexExpression,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),

          // Explicación pedagógica
          Padding(
            padding: const EdgeInsets.only(left: 14.0),
            child: Text(
              step.pedagogicalNote,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          // Alerta de examen opcional
          if (step.warningTrick != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 14.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFDC2626)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        step.warningTrick!,
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Servicio de exportación a Goodnotes y portapapeles LaTeX
class GoodnotesExporter {
  /// Renderiza el widget GoodnotesStickerCanvas a PNG de alta resolución (pixelRatio: 3.0),
  /// lo guarda en getTemporaryDirectory() como 'resolucion_paso_a_paso.png'
  /// y abre el menú nativo de compartir con Share.shareXFiles.
  static Future<void> captureAndShareSticker(
    GlobalKey repaintKey, {
    required StepByStepResolution resolution,
  }) async {
    try {
      final boundary =
          repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('No se pudo encontrar el render object del sticker.');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Error al codificar imagen PNG.');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/resolucion_paso_a_paso.png';
        final file = File(filePath);
        await file.writeAsBytes(pngBytes);
        await Share.shareXFiles(
          [
            XFile(
              filePath,
              mimeType: 'image/png',
              name: 'resolucion_paso_a_paso.png',
            ),
          ],
          text: 'Resolución paso a paso Casio',
        );
      } else {
        await Share.shareXFiles(
          [
            XFile.fromData(
              pngBytes,
              mimeType: 'image/png',
              name: 'resolucion_paso_a_paso.png',
            ),
          ],
          text: 'Resolución paso a paso Casio',
        );
      }
    } catch (e) {
      debugPrint('Error exportando sticker: $e');
      rethrow;
    }
  }

  /// Formatea la resolución completa en un entorno align* de amsmath
  static String formatAsLatexBlock(StepByStepResolution resolution) {
    final buffer = StringBuffer();
    buffer.writeln(r'\begin{align*}');
    buffer.writeln(
        '  \\text{Expresion inicial:} \\quad & ${resolution.originalInputLatex} \\\\');

    for (int i = 0; i < resolution.steps.length; i++) {
      final step = resolution.steps[i];
      final isLast = i == resolution.steps.length - 1;
      final title = step.shortTitle.replaceAll('&', r'\&');
      final expr = step.latexExpression;

      if (isLast) {
        buffer.writeln(
            '  \\text{$title:} \\quad & $expr = \\mathbf{${resolution.exactResultLatex}} \\\\');
      } else {
        buffer.writeln('  \\text{$title:} \\quad & $expr \\\\');
      }
    }

    buffer.writeln(
        r'  \text{Aproximacion decimal (S $\Leftrightarrow$ D):} \quad & \approx ' +
            resolution.decimalApproxLatex);
    buffer.writeln(r'\end{align*}');
    return buffer.toString();
  }

  /// Copia el bloque LaTeX al portapapeles
  static Future<void> copyLatexBlockToClipboard(
    StepByStepResolution resolution,
  ) async {
    final text = formatAsLatexBlock(resolution);
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Muestra un modal elegante para previsualizar el sticker y exportarlo
  static void showStickerPreviewDialog(
    BuildContext context,
    StepByStepResolution resolution, {
    FunctionAnalysisResult? graphAnalysis,
  }) {
    final GlobalKey repaintKey = GlobalKey();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                // Barra superior de arrastre
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.image_outlined,
                        color: Color(0xFF0D9488),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Exportar Desarrollo a PNG',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),

                // Previsualización sobre fondo simulado de cuaderno
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: RepaintBoundary(
                        key: repaintKey,
                        child: GoodnotesStickerCanvas(
                          resolution: resolution,
                          graphAnalysis: graphAnalysis,
                        ),
                      ),
                    ),
                  ),
                ),

                // Botones de acción inferiores
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text(
                            'Exportar PNG Transparente',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            try {
                              await captureAndShareSticker(
                                repaintKey,
                                resolution: resolution,
                              );
                              if (context.mounted) {
                                Navigator.of(ctx).pop();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error al compartir: $e'),
                                    backgroundColor: const Color(0xFFB91C1C),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 13,
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.content_copy_rounded, size: 18),
                        label: const Text(
                          'LaTeX',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          await copyLatexBlockToClipboard(resolution);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    '¡Bloque LaTeX copiado al portapapeles!'),
                                backgroundColor: Color(0xFF4F46E5),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
