import 'package:flutter/material.dart';
import '../../../core/editor/lcd_cursor_tokens.dart';
import '../../../domain/math_engine/parser/expression_parser.dart';
import '../lcd/lcd_input_box.dart';

class InequalitySystemEditorView extends StatelessWidget {
  final bool isOledDark;
  final int ineqSysUnknowns;
  final int ineqSysRows;
  final int ineqSysActiveRow;
  final List<String> ineqSysRowInputs;
  final List<int> ineqSysRowCursors;
  final VoidCallback? onToggleUnknowns;
  final ValueChanged<int>? onChangeRows;
  final ValueChanged<int> onSelectRow;

  const InequalitySystemEditorView({
    super.key,
    required this.isOledDark,
    required this.ineqSysUnknowns,
    required this.ineqSysRows,
    required this.ineqSysActiveRow,
    required this.ineqSysRowInputs,
    required this.ineqSysRowCursors,
    this.onToggleUnknowns,
    this.onChangeRows,
    required this.onSelectRow,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF101815);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          // FittedBox: en LCD baja (apaisado 900x500) todo el bloque escala en vez de desbordar.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: (constraints.maxWidth - 20).clamp(0.0, double.infinity),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '{',
                    style: TextStyle(
                      color: textColor,
                      fontSize: ineqSysRows == 4 ? 76 : (ineqSysRows == 3 ? 64 : 52),
                      fontWeight: FontWeight.w200,
                      fontFamily: 'serif',
                      height: 0.95,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < ineqSysRows; i++) ...[
                          if (i > 0) const SizedBox(height: 5),
                          _row(i, textColor),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
            ),
          ),
        );
      },
    );
  }

  /// Una fila `(i) [casilla]`: la casilla es un `LcdInputBox` con cursor parpadeante real
  /// (tambien con la fila vacia) tanto en LCD claro como oscuro.
  Widget _row(int i, Color textColor) {
    final raw = ineqSysRowInputs[i];
    final isActive = ineqSysActiveRow == i;
    final String? rowTex = raw.isEmpty
        ? (isActive ? LcdCursor.box : null)
        : ExpressionParser.rawToLiveLatex(raw, cursorPos: isActive ? ineqSysRowCursors[i] : null);
    return Row(
      children: [
        Text(
          '(${i + 1}) ',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.65),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: LcdInputBox(
            key: Key('ineq_sys_row_$i'),
            active: isActive,
            dark: isOledDark,
            latex: rowTex,
            placeholder: ineqSysUnknowns == 1 ? '2x - 3 ≤ 5' : 'x + y ≤ 4',
            minWidth: 60,
            minHeight: 32,
            onTap: () => onSelectRow(i),
          ),
        ),
      ],
    );
  }
}
