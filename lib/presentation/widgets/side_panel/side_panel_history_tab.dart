import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../domain/services/class_history_service.dart';
import '../casio_lcd_screen.dart';
import 'side_panel_summary_dialog.dart';

class SidePanelHistoryTab extends StatelessWidget {
  final List<ClassHistoryEntry> entries;
  final ClassHistoryService historyService;
  final ValueChanged<ClassHistoryEntry> onSelectEntry;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<String> onDeleteEntry;

  const SidePanelHistoryTab({
    super.key,
    required this.entries,
    required this.historyService,
    required this.onSelectEntry,
    required this.onToggleFavorite,
    required this.onDeleteEntry,
  });

  void _openSummaryExportDialog(BuildContext context) {
    SidePanelSummaryDialog.show(
      context,
      entries: entries,
      historyService: historyService,
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
