import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/services/class_history_service.dart';
import 'casio_lcd_screen.dart';

class ClassHistorySheet extends StatefulWidget {
  final ClassHistoryService historyService;
  final ValueChanged<ClassHistoryEntry> onSelectEntry;

  const ClassHistorySheet({
    super.key,
    required this.historyService,
    required this.onSelectEntry,
  });

  static Future<void> show(
    BuildContext context, {
    required ClassHistoryService historyService,
    required ValueChanged<ClassHistoryEntry> onSelectEntry,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClassHistorySheet(
        historyService: historyService,
        onSelectEntry: onSelectEntry,
      ),
    );
  }

  @override
  State<ClassHistorySheet> createState() => _ClassHistorySheetState();
}

class _ClassHistorySheetState extends State<ClassHistorySheet> {
  List<ClassHistoryEntry> _entries = [];
  bool _isLoading = true;
  String _selectedFilter = 'Todos'; // 'Todos', 'Favoritos ⭐', '1.º-2.º ESO', '3.º-4.º ESO'
  int _todayCount = 0;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await widget.historyService.getEntries();
    final todayCount = await widget.historyService.getTodayEntriesCount();
    if (mounted) {
      setState(() {
        _entries = entries;
        _todayCount = todayCount;
        _isLoading = false;
      });
    }
  }

  List<ClassHistoryEntry> get _filteredEntries {
    if (_selectedFilter == 'Favoritos ⭐') {
      return _entries.where((e) => e.isFavorite).toList();
    }
    if (_selectedFilter == '1.º-2.º ESO') {
      return _entries.where((e) => e.studentTag.contains('1.º') || e.studentTag.contains('2.º')).toList();
    }
    if (_selectedFilter == '3.º-4.º ESO') {
      return _entries.where((e) => e.studentTag.contains('3.º') || e.studentTag.contains('4.º')).toList();
    }
    return _entries;
  }

  void _exportTexSummary() {
    final entriesToExport = _filteredEntries.isNotEmpty ? _filteredEntries : _entries;
    if (entriesToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay ejercicios en el historial para exportar.'),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      return;
    }

    final tex = widget.historyService.generateClassTexSummary(entriesToExport);
    Clipboard.setData(ClipboardData(text: tex));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('¡Resumen LaTeX de ${entriesToExport.length} ejercicios copiado al portapapeles!'),
        backgroundColor: const Color(0xFF2563EB),
        action: SnackBarAction(
          label: 'Compartir',
          textColor: Colors.white,
          onPressed: () {
            Share.share(tex, subject: 'Resumen de Clase de Matemáticas - Casio Tutor');
          },
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('¿Borrar historial de clase?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Se eliminarán todos los ejercicios resueltos de la memoria permanente.',
          style: TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar Todo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.historyService.clearHistory();
      await _loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
          ),
          child: Column(
            children: [
              // Barra de arrastre superior
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Cabecera con título, contador de hoy y botones de acción
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.history_edu_rounded, color: Color(0xFF60A5FA), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Historial de Sesión de Clase',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$_todayCount ejercicios resueltos hoy',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Exportar Resumen .TEX',
                      icon: const Icon(Icons.download_rounded, color: Color(0xFF38BDF8)),
                      onPressed: _exportTexSummary,
                    ),
                    IconButton(
                      tooltip: 'Limpiar Historial',
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                      onPressed: _entries.isEmpty ? null : _confirmClearHistory,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Chips de filtrado
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    for (final filter in ['Todos', 'Favoritos ⭐', '1.º-2.º ESO', '3.º-4.º ESO'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: _selectedFilter == filter,
                          selectedColor: const Color(0xFF2563EB),
                          backgroundColor: const Color(0xFF1E293B),
                          labelStyle: TextStyle(
                            color: _selectedFilter == filter ? Colors.white : const Color(0xFFCBD5E1),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFF1E293B), height: 20),

              // Lista de ejercicios
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                    : _filteredEntries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.menu_book_rounded, size: 48, color: const Color(0xFF475569)),
                                const SizedBox(height: 12),
                                const Text(
                                  'No hay ejercicios en esta categoría',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Cada vez que pulses = se guardará aquí el ejercicio.',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            itemCount: _filteredEntries.length,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                            itemBuilder: (ctx, index) {
                              final entry = _filteredEntries[index];
                              final timeStr =
                                  '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';

                              return InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onSelectEntry(entry);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: entry.isFavorite
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF334155),
                                      width: entry.isFavorite ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Fila superior con modo, hora y botón favorito
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F766E),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              entry.modeName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF334155),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              entry.studentTag,
                                              style: const TextStyle(
                                                color: Color(0xFFCBD5E1),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            timeStr,
                                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: Icon(
                                              entry.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                                              color: entry.isFavorite
                                                  ? const Color(0xFFF59E0B)
                                                  : const Color(0xFF64748B),
                                              size: 20,
                                            ),
                                            onPressed: () async {
                                              await widget.historyService.toggleFavorite(entry.id);
                                              await _loadEntries();
                                            },
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              color: Color(0xFF64748B),
                                              size: 18,
                                            ),
                                            onPressed: () async {
                                              await widget.historyService.deleteEntry(entry.id);
                                              await _loadEntries();
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Expresión original
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Math.tex(
                                          CasioLcdScreen.sanitizeForMathTex(entry.resolution.originalInputLatex),
                                          textStyle: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          onErrorFallback: (err) => Text(
                                            entry.resolution.originalInputLatex,
                                            style: const TextStyle(color: Colors.white, fontSize: 13),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      // Resultado y número de pasos
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Text(
                                                      '= ',
                                                      style: TextStyle(
                                                        color: Color(0xFF38BDF8),
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    Math.tex(
                                                      CasioLcdScreen.sanitizeForMathTex(entry.resolution.exactResultLatex),
                                                      textStyle: const TextStyle(
                                                        color: Color(0xFF38BDF8),
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      onErrorFallback: (err) => Text(
                                                        entry.resolution.exactResultLatex,
                                                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${entry.resolution.steps.length} pasos pedagógicos ▶',
                                            style: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 11,
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
          ),
        );
      },
    );
  }
}
