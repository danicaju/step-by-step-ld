import 'package:flutter/material.dart';

import 'lcd_palette.dart';

/// Orden fijo de las memorias en el visor (3 columnas).
const List<String> kMemoryNames = ['A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'M'];

/// Visor de variables y memorias dentro de la LCD (OPTN / CALC en Modo 1).
class LcdMemoryViewer extends StatelessWidget {
  final LcdTheme theme;
  final List<String> values; // mismo orden que [kMemoryNames]
  final String ansText;
  final int focus;
  final ValueChanged<int>? onTapCell;
  final VoidCallback? onClearAll;
  final VoidCallback? onClose;

  const LcdMemoryViewer({
    super.key,
    required this.theme,
    required this.values,
    required this.ansText,
    required this.focus,
    this.onTapCell,
    this.onClearAll,
    this.onClose,
  });

  static const Color _active = Color(0xFF1A2530);
  static const Color _border = Color(0xFF7A8A7E);

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final bool dark = theme == LcdTheme.night;
    final Color idleBg = dark ? const Color(0xFF1A2421) : const Color(0xFFBDCEBE);

    Widget cell(int i) {
      final focused = focus == i;
      return Expanded(
        child: GestureDetector(
          key: Key('mem_cell_${kMemoryNames[i]}'),
          onTap: () => onTapCell?.call(i),
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: focused ? _active : idleBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: focused ? _active : _border),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${kMemoryNames[i]}=${values[i]}',
                style: TextStyle(
                  color: focused ? Colors.white : pal.formula,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      key: const Key('lcd_memory_viewer'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: pal.background,
        borderRadius: BorderRadius.circular(8.5),
        border: Border.all(color: _border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'MEMORIAS',
                style: TextStyle(color: pal.formula, fontSize: 12, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                'ANS=$ansText',
                key: const Key('mem_ans'),
                style: TextStyle(
                  color: pal.title,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Column(
              children: [
                for (int r = 0; r < 3; r++)
                  Expanded(
                    child: Row(children: [for (int c = 0; c < 3; c++) cell(r * 3 + c)]),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '= guardar ANS · +/- M · DEL poner 0 · AC volver',
                  style: TextStyle(color: pal.title, fontSize: 9, fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                key: const Key('mem_clear_all'),
                onTap: onClearAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: idleBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _border),
                  ),
                  child: Text(
                    'Limpiar',
                    style: TextStyle(color: pal.formula, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
