import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../domain/services/class_history_service.dart';
import '../casio_lcd_screen.dart';

class SidePanelSummaryDialog {
  static void show(BuildContext context, {
    required List<ClassHistoryEntry> entries,
    required ClassHistoryService historyService,
  }) {
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay ejercicios en el historial para exportar.'),
          backgroundColor: Color(0xFFB91C1C),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final repaintKey = GlobalKey();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.summarize_rounded, color: Color(0xFFE5A93C), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Exportar Resumen de Clase',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  key: repaintKey,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'STEP-BY-STEP LD',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            Spacer(),
                            Text(
                              'Resumen de Clase',
                              style: TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFFCBD5E1)),
                        for (int i = 0; i < entries.length && i < 6; i++) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${i + 1}. ${entries[i].modeName}',
                                  style: const TextStyle(
                                    color: Color(0xFFE5A93C),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Math.tex(
                                    CasioLcdScreen.sanitizeForMathTex(
                                      '${entries[i].resolution.originalInputLatex} = ${entries[i].resolution.exactResultLatex}',
                                    ),
                                    textStyle: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                    ),
                                    onErrorFallback: (_) => Text(
                                      '${entries[i].resolution.originalInputLatex} = ${entries[i].resolution.exactResultLatex}',
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5A93C),
              foregroundColor: const Color(0xFF1A2530),
            ),
            icon: const Icon(Icons.code_rounded, size: 16),
            label: const Text('Copiar .TEX'),
            onPressed: () async {
              final tex = historyService.generateClassTexSummary(entries);
              await Clipboard.setData(ClipboardData(text: tex));
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Resumen .TEX (${entries.length} ejercicios) copiado al portapapeles.',
                    ),
                  ),
                );
              }
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F5D50),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.image_rounded, size: 16),
            label: const Text('Compartir PNG'),
            onPressed: () async {
              try {
                final boundary = repaintKey.currentContext?.findRenderObject()
                    as RenderRepaintBoundary?;
                if (boundary == null) return;
                final image = await boundary.toImage(pixelRatio: 2.5);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                if (bytes == null) return;
                final pngBytes = bytes.buffer.asUint8List();
                if (!kIsWeb) {
                  final dir = await getTemporaryDirectory();
                  final file = File('${dir.path}/step_by_step_ld_resumen_clase.png');
                  await file.writeAsBytes(pngBytes);
                  await Share.shareXFiles(
                    [
                      XFile(
                        file.path,
                        mimeType: 'image/png',
                        name: 'step_by_step_ld_resumen_clase.png',
                      ),
                    ],
                    text: 'Resumen de Clase - STEP-BY-STEP LD',
                  );
                } else {
                  await Share.shareXFiles(
                    [
                      XFile.fromData(
                        pngBytes,
                        mimeType: 'image/png',
                        name: 'step_by_step_ld_resumen_clase.png',
                      ),
                    ],
                    text: 'Resumen de Clase - STEP-BY-STEP LD',
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No se pudo exportar PNG: $e'),
                      backgroundColor: const Color(0xFFB91C1C),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
