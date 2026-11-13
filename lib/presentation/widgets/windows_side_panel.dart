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
import '../../domain/services/class_history_service.dart';
import 'casio_graph_canvas.dart';
import 'casio_lcd_screen.dart';

/// Panel lateral acoplado estilo Windows Calculator para pantallas anchas (`>= 760 px`).
/// Incluye pestañas para el Historial de Clase en vivo y el Desglose Paso a Paso / Pizarra.
class WindowsSidePanel extends StatelessWidget {
  final int activeTabIndex;
  final ValueChanged<int> onTabChanged;
  final List<ClassHistoryEntry> historyEntries;
  final ClassHistoryService historyService;
  final ValueChanged<ClassHistoryEntry> onSelectHistoryEntry;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<String> onDeleteHistoryEntry;
  final StepByStepResolution? activeResolution;
  final int activeStepIndex;
  final ValueChanged<int> onSelectStep;
  final FunctionAnalysisResult? graphAnalysis;
  final VoidCallback onExportSticker;
  final VoidCallback onCopyLatex;
  final VoidCallback onOpenAiTutor;

  const WindowsSidePanel({
    super.key,
    required this.activeTabIndex,
    required this.onTabChanged,
    required this.historyEntries,
    required this.historyService,
    required this.onSelectHistoryEntry,
    required this.onToggleFavorite,
    required this.onDeleteHistoryEntry,
    required this.activeResolution,
    required this.activeStepIndex,
    required this.onSelectStep,
    this.graphAnalysis,
    required this.onExportSticker,
    required this.onCopyLatex,
    required this.onOpenAiTutor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16191E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF252830),
          width: 2.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            offset: Offset(0, 12),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra superior de pestañas
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF1E222A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(color: Color(0xFF2C323E), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DockTabButton(
                    label: 'DESGLOSE PASO A PASO',
                    badgeText: activeResolution != null
                        ? '${activeResolution!.steps.length}'
                        : null,
                    selected: activeTabIndex == 1,
                    accentColor: const Color(0xFFE5A93C),
                    onTap: () => onTabChanged(1),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _DockTabButton(
                    label: 'HISTORIAL',
                    badgeText: '${historyEntries.length}',
                    selected: activeTabIndex == 0,
                    accentColor: const Color(0xFF2E86DE),
                    onTap: () => onTabChanged(0),
                  ),
                ),
              ],
            ),
          ),

          // Contenido según pestaña seleccionada
          Expanded(
            child: activeTabIndex == 0
                ? _HistoryTabView(
                    entries: historyEntries,
                    historyService: historyService,
                    onSelectEntry: onSelectHistoryEntry,
                    onToggleFavorite: onToggleFavorite,
                    onDeleteEntry: onDeleteHistoryEntry,
                  )
                : _ChalkboardBreakdownView(
                    resolution: activeResolution,
                    activeStepIndex: activeStepIndex,
                    onSelectStep: onSelectStep,
                    graphAnalysis: graphAnalysis,
                    onExportSticker: onExportSticker,
                    onCopyLatex: onCopyLatex,
                    onOpenAiTutor: onOpenAiTutor,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DockTabButton extends StatelessWidget {
  final String label;
  final String? badgeText;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _DockTabButton({
    required this.label,
    this.badgeText,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF252A34) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accentColor : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? accentColor
                      : const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText!,
                  style: TextStyle(
                    color: selected && accentColor == const Color(0xFFE5A93C)
                        ? Colors.black
                        : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryTabView extends StatelessWidget {
  final List<ClassHistoryEntry> entries;
  final ClassHistoryService historyService;
  final ValueChanged<ClassHistoryEntry> onSelectEntry;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<String> onDeleteEntry;

  const _HistoryTabView({
    required this.entries,
    required this.historyService,
    required this.onSelectEntry,
    required this.onToggleFavorite,
    required this.onDeleteEntry,
  });

  void _openSummaryExportDialog(BuildContext context) {
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
            Icon(Icons.summarize_rounded, color: Color(0xFF38BDF8), size: 22),
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
                                    color: Color(0xFF2563EB),
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
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
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
                    backgroundColor: const Color(0xFF2563EB),
                  ),
                );
              }
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
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
                  final file = File('${dir.path}/resumen_clase_ld.png');
                  await file.writeAsBytes(pngBytes);
                  await Share.shareXFiles(
                    [
                      XFile(
                        file.path,
                        mimeType: 'image/png',
                        name: 'resumen_clase_ld.png',
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
                        name: 'resumen_clase_ld.png',
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabecera de acciones de Historial
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: Text(
                  '${entries.length} ejercicios en sesión',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 15),
                      label: const Text(
                        'Exportar Resumen (.TEX / PNG)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => _openSummaryExportDialog(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF252A34), height: 1),
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_edu_rounded,
                          size: 42,
                          color: Color(0xFF475569),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Tu historial de clase aparecerá aquí automáticamente al pulsar =',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final timeStr =
                        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelectEntry(entry),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D222B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: entry.isFavorite
                                ? const Color(0xFFE5A93C)
                                : const Color(0xFF2D3442),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F766E),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      entry.modeName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(
                                    entry.isFavorite
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: entry.isFavorite
                                        ? const Color(0xFFE5A93C)
                                        : const Color(0xFF64748B),
                                    size: 18,
                                  ),
                                  onPressed: () => onToggleFavorite(entry.id),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFF64748B),
                                    size: 16,
                                  ),
                                  onPressed: () => onDeleteEntry(entry.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Math.tex(
                                CasioLcdScreen.sanitizeForMathTex(
                                  entry.resolution.originalInputLatex,
                                ),
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                onErrorFallback: (_) => Text(
                                  entry.resolution.originalInputLatex,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Text(
                                  '= ',
                                  style: TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Flexible(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Math.tex(
                                      CasioLcdScreen.sanitizeForMathTex(
                                        entry.resolution.exactResultLatex,
                                      ),
                                      textStyle: const TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      onErrorFallback: (_) => Text(
                                        entry.resolution.exactResultLatex,
                                        style: const TextStyle(
                                          color: Color(0xFF38BDF8),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ChalkboardBreakdownView extends StatelessWidget {
  final StepByStepResolution? resolution;
  final int activeStepIndex;
  final ValueChanged<int> onSelectStep;
  final FunctionAnalysisResult? graphAnalysis;
  final VoidCallback onExportSticker;
  final VoidCallback onCopyLatex;
  final VoidCallback onOpenAiTutor;

  const _ChalkboardBreakdownView({
    required this.resolution,
    required this.activeStepIndex,
    required this.onSelectStep,
    this.graphAnalysis,
    required this.onExportSticker,
    required this.onCopyLatex,
    required this.onOpenAiTutor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Botonera directa en pantalla grande
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tooltip(
                message: 'EXPORTAR PNG',
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.image_outlined, size: 15),
                  label: const Text(
                    'EXPORTAR PNG',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: onExportSticker,
                ),
              ),
              Tooltip(
                message: 'COPIAR LaTeX',
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.content_copy_rounded, size: 15),
                  label: const Text(
                    'COPIAR LaTeX',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: onCopyLatex,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF252A34), height: 1),
        Expanded(
          child: resolution == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.developer_board_rounded,
                          size: 42,
                          color: Color(0xFF475569),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Introduce una expresión o coeficientes en la calculadora y pulsa = para desplegar aquí todos los pasos simultáneamente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // Tarjeta de Enunciado
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D222B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2D3442)),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'ENUNCIADO:',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Math.tex(
                                CasioLcdScreen.sanitizeForMathTex(
                                  resolution!.originalInputLatex,
                                ),
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                                onErrorFallback: (_) => Text(
                                  resolution!.originalInputLatex,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Gráfica opcional en Modo 7
                    if (graphAnalysis != null) ...[
                      SizedBox(
                        height: 190,
                        child: CasioGraphCanvas(
                          analysisResult: graphAnalysis!,
                          isStickerMode: false,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Lista vertical simultánea de TODOS los pasos
                    for (int i = 0; i < resolution!.steps.length; i++) ...[
                      _StepBoardTile(
                        step: resolution!.steps[i],
                        isActive: i == activeStepIndex,
                        onTap: () => onSelectStep(i),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Resultado final destacado
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF064E3B).withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF10B981),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF34D399),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Resultado:',
                            style: TextStyle(
                              color: Color(0xFFA7F3D0),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Math.tex(
                                CasioLcdScreen.sanitizeForMathTex(
                                  '${resolution!.exactResultLatex} \\;\\; (\\approx ${resolution!.decimalApproxLatex})',
                                ),
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                onErrorFallback: (_) => Text(
                                  '${resolution!.exactResultLatex} (≈ ${resolution!.decimalApproxLatex})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _StepBoardTile extends StatelessWidget {
  final MathStep step;
  final bool isActive;
  final VoidCallback onTap;

  const _StepBoardTile({
    required this.step,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E293B) : const Color(0xFF1B1F27),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? const Color(0xFF2E86DE)
                : const Color(0xFF2C323E),
            width: isActive ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF2E86DE)
                        : const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PASO ${step.index}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.shortTitle,
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFFE5A93C)
                          : const Color(0xFFE2E8F0),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                CasioLcdScreen.sanitizeForMathTex(step.latexExpression),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                ),
                onErrorFallback: (_) => Text(
                  step.latexExpression,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              step.pedagogicalNote,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            if (step.warningTrick != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF450A0A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDC2626)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        step.warningTrick!,
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
    );
  }
}
