import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/math_engine/models/step_resolution.dart';
import '../../domain/math_engine/solvers/function_graph_solver.dart';
import '../theme/theme_contrast.dart';
import '../theme/theme_controller.dart';
import '../widgets/goodnotes_sticker_canvas.dart';

export '../widgets/goodnotes_sticker_canvas.dart';
/// Servicio de exportación a Goodnotes y portapapeles LaTeX
class GoodnotesExporter {
  /// Renderiza el widget GoodnotesStickerCanvas a PNG de alta resolución (pixelRatio: 3.0),
  /// lo guarda en getTemporaryDirectory() como 'step_by_step_ld_resolucion.png'
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
        final filePath = '${tempDir.path}/step_by_step_ld_resolucion.png';
        final file = File(filePath);
        await file.writeAsBytes(pngBytes);
        await Share.shareXFiles(
          [
            XFile(
              filePath,
              mimeType: 'image/png',
              name: 'step_by_step_ld_resolucion.png',
            ),
          ],
          text: 'Resolución paso a paso - STEP-BY-STEP LD',
        );
      } else {
        await Share.shareXFiles(
          [
            XFile.fromData(
              pngBytes,
              mimeType: 'image/png',
              name: 'step_by_step_ld_resolucion.png',
            ),
          ],
          text: 'Resolución paso a paso - STEP-BY-STEP LD',
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

  /// Muestra un modal para previsualizar el sticker y exportarlo (colores del tema activo).
  static void showStickerPreviewDialog(
    BuildContext context,
    StepByStepResolution resolution, {
    FunctionAnalysisResult? graphAnalysis,
  }) {
    final GlobalKey repaintKey = GlobalKey();
    final hw = ThemeController.current;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: hw.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: hw.panelBorder),
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
                    color: hw.panelMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Icon(Icons.image_outlined, color: hw.panelAccentText),
                      const SizedBox(width: 8),
                      Text(
                        'Exportar Desarrollo a PNG',
                        style: TextStyle(
                          color: hw.panelText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: hw.panelText),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(color: hw.panelBorder),

                // Previsualizacion sobre papel (el PNG exportado es transparente)
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF8F4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: hw.panelBorder),
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

                // Barra inferior de acciones
                Container(
                  decoration: BoxDecoration(
                    color: hw.panelTabBar,
                    border: Border(top: BorderSide(color: hw.panelBorder)),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hw.actionBg,
                            foregroundColor: hw.actionFg,
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
                                  SnackBar(content: Text('Error al compartir: $e')),
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hw.action2Bg,
                          foregroundColor: hw.action2Fg,
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
                                content: Text('Bloque LaTeX copiado al portapapeles'),
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
