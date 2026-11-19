import 'package:flutter/material.dart';

import 'lcd_palette.dart';

/// Títulos de las 8 filas del SETUP (3 páginas de 3).
const List<String> kSetupRowTitles = [
  'Unidad Angular',
  'Formato Número',
  'Fracción Resultado',
  'Separador Decimal',
  'Tema LCD',
  'Salida por Defecto',
  'Separador Dígitos',
  'Inicializar / Reset',
  'Tema Hardware',
  'Sonido Teclas',
];

/// Opciones de cada fila del SETUP.
const List<List<String>> kSetupRowOptions = [
  ['DEG (Grados)', 'RAD (Radianes)', 'GRA (Gradianes)'],
  ['Norm (Normal)', 'Fix (0-9 decimales)', 'Sci (Científica)'],
  ['d/c (Impropia)', 'ab/c (Mixta)'],
  ['Punto (.)', 'Coma (,)'],
  ['Clásica (Oliva)', 'Papel (Alto Contraste)', 'Nocturno'],
  ['MathI/MathO (Exacta)', 'MathI/DecimalO (Decimal)'],
  ['Desactivado', 'Activado (1 234,5)'],
  ['Limpiar Memorias (A-Y, M, ANS)', 'Restaurar Config'],
  ['Predeterminado', 'Rosa Soft-Touch', 'Arena Retro 80s', 'Menta Salvia', 'Blanco Perla'],
  ['Segun tema', 'Original', 'Silicona Suave', 'Retro Mecanico', 'Chiclet', 'Estudio'],
];

/// Menú SETUP de la LCD (SHIFT + MODE): 4 páginas, filas 1-9 y 0 (=10), sub-opciones y dígitos Fix/Sci.
class LcdSetupMenuView extends StatelessWidget {
  final LcdTheme theme;
  final int focusRow;
  final int subCursor; // -1 = lista principal
  final String? digitsPrompt; // 'Fix' o 'Sci' cuando se piden dígitos 0-9
  final List<String> currentValues; // valor actual por fila
  final int currentOption; // opción actual de la fila abierta
  final ValueChanged<int>? onTapRow;
  final ValueChanged<int>? onTapOption;
  final ValueChanged<int>? onTapDigit;

  const LcdSetupMenuView({
    super.key,
    required this.theme,
    required this.focusRow,
    required this.subCursor,
    required this.currentValues,
    required this.currentOption,
    this.digitsPrompt,
    this.onTapRow,
    this.onTapOption,
    this.onTapDigit,
  });

  static const Color _active = Color(0xFF1A2530);
  static const Color _border = Color(0xFF7A8A7E);

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final bool dark = theme == LcdTheme.night;
    final Color idleBg = dark ? const Color(0xFF1A2421) : const Color(0xFFC8D6CD);
    final Color idleFg = pal.formula;
    final int page = focusRow ~/ 3;

    Widget row({
      required Key key,
      required String left,
      required String right,
      required bool focused,
      required bool current,
      VoidCallback? onTap,
    }) {
      return GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 3),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: focused ? _active : idleBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: focused ? _active : _border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: focused ? Colors.white : idleFg,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (right.isNotEmpty)
                Text(
                  current ? '✓ $right' : right,
                  style: TextStyle(
                    color: focused ? Colors.white : idleFg,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final List<Widget> body;
    String title = 'SETUP  ${page + 1}/4';
    String hint = '▲▼ mover · 1-9, 0 o = elegir · AC salir';
    if (digitsPrompt != null) {
      title = '$digitsPrompt  (0-9)';
      hint = 'Pulsa 0-9 · AC volver';
      body = [
        Wrap(
          spacing: 4,
          runSpacing: 3,
          children: [
            for (int d = 0; d <= 9; d++)
              SizedBox(
                width: 34,
                child: row(
                  key: Key('setup_digit_$d'),
                  left: '$d',
                  right: '',
                  focused: false,
                  current: false,
                  onTap: () => onTapDigit?.call(d),
                ),
              ),
          ],
        ),
      ];
    } else if (subCursor >= 0) {
      final opts = kSetupRowOptions[focusRow];
      title = '${focusRow + 1}: ${kSetupRowTitles[focusRow]}';
      hint = '▲▼ mover · 1-${opts.length} o = elegir · AC volver';
      body = [
        for (int i = 0; i < opts.length; i++)
          row(
            key: Key('setup_opt_${focusRow}_$i'),
            left: '${i + 1}: ${opts[i]}',
            right: '',
            focused: subCursor == i,
            current: focusRow != 7 && currentOption == i,
            onTap: () => onTapOption?.call(i),
          ),
      ];
    } else {
      body = [
        for (int r = page * 3; r < page * 3 + 3 && r < kSetupRowTitles.length; r++)
          row(
            key: Key('setup_row_$r'),
            left: '${r + 1}: ${kSetupRowTitles[r]}',
            right: currentValues[r],
            focused: focusRow == r,
            current: false,
            onTap: () => onTapRow?.call(r),
          ),
      ];
    }

    return Column(
      key: const Key('lcd_setup_menu'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          key: const Key('setup_title'),
          style: TextStyle(color: pal.formula, fontSize: 12, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Expanded(child: SingleChildScrollView(child: Column(children: body))),
        Text(hint, style: TextStyle(color: pal.title, fontSize: 9.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
