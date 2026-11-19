import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/theme_contrast.dart';
import '../../theme/theme_controller.dart';
import '../../theme/calculator_themes.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../domain/services/class_history_service.dart';
import '../casio_lcd_screen.dart';
import '../safe_math.dart';

class SidePanelSummaryDialog {
  static void show(BuildContext context, {
    required List<ClassHistoryEntry> entries,
    required ClassHistoryService historyService,
  }) {
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay ejercicios en el historial para exportar.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final repaintKey = GlobalKey();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _pnl.panelBg,
        title: Row(
          children: [
            Icon(Icons.summarize_rounded, color: _pnl.panelAccentText, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Exportar Resumen de Clase',
                style: TextStyle(color: _pnl.panelText, fontSize: 16),
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
                      color: _paper,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'STEP-BY-STEP LD',
                              style: TextStyle(
                                color: _paperInk,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            Spacer(),
                            Text(
                              'Resumen de Clase',
                              style: TextStyle(
                                color: _paperMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Divider(color: _paperLine),
                        for (int i = 0; i < entries.length && i < 6; i++) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${i + 1}. ${entries[i].modeName}',
                                  style: TextStyle(
                                    color: _pnl.inkOnPaper,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SafeMath.tex(
                                    CasioLcdScreen.sanitizeForMathTex(
                                      '${entries[i].resolution.originalInputLatex} = ${entries[i].resolution.exactResultLatex}',
                                    ),
                                    textStyle: TextStyle(
                                      color: _paperInk,
                                      fontSize: 13,
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
            child: Text(
              'Cerrar',
              style: TextStyle(color: _pnl.panelText),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _pnl.action2Bg,
              foregroundColor: _pnl.action2Fg,
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
              backgroundColor: _pnl.actionBg,
              foregroundColor: _pnl.actionFg,
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

CalculatorHardwareTheme get _pnl => ThemeController.current;

// Hoja de papel del resumen exportado (PNG): neutra y independiente del tema.
const Color _paper = Color(0xFFFAF8F4);
const Color _paperInk = Color(0xFF1F2328);
const Color _paperMuted = Color(0xFF5A5F66);
const Color _paperLine = Color(0xFFD9D5CB);
