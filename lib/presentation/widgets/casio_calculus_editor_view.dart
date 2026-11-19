import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../domain/math_engine/parser/expression_parser.dart';
import '../../domain/math_engine/solvers/calculus_solver.dart';
import 'casio_cell_value_text.dart';
import 'casio_lcd_screen.dart';
import 'lcd/lcd_input_box.dart';

/// Editor LCD interactivo para el Modo 11 (Derivadas, Recta Tangente e Integral por Barrow).
class CasioCalculusEditorView extends StatelessWidget {
  final CalculusOperation selectedOperation;
  final String expressionRaw;
  final int expressionCursorPos;
  final String x0Raw;
  final String limitARaw;
  final String limitBRaw;
  final int activeField; // 0 = f(x), 1 = x0 o a, 2 = b
  final bool isOledDark;
  final ValueChanged<int>? onSelectField;
  final ValueChanged<CalculusOperation>? onSelectOperation;

  /// `true` si la operación se elige en el desplegable de la cabecera LCD.
  final bool operationsInHeader;

  const CasioCalculusEditorView({
    super.key,
    required this.selectedOperation,
    required this.expressionRaw,
    required this.expressionCursorPos,
    required this.x0Raw,
    required this.limitARaw,
    required this.limitBRaw,
    required this.activeField,
    this.isOledDark = false,
    this.onSelectField,
    this.onSelectOperation,
    this.operationsInHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF0F172A);
    final mutedColor =
        isOledDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    final prefixLatex = switch (selectedOperation) {
      CalculusOperation.derivative => r'\frac{d}{dx}(',
      CalculusOperation.tangentLine => r'f(x) =',
      CalculusOperation.indefiniteIntegral => r'\int (',
      CalculusOperation.definiteIntegral => r'\int (',
    };
    final suffixLatex = switch (selectedOperation) {
      CalculusOperation.derivative => r')',
      CalculusOperation.tangentLine => '',
      CalculusOperation.indefiniteIntegral => r')\,dx',
      CalculusOperation.definiteIntegral => r')\,dx',
    };

    // Vacia: sin LaTeX (la casilla muestra la barra parpadeante si esta activa, o un 0 tenue).
    final String? bodyLatex = expressionRaw.isEmpty
        ? null
        : ExpressionParser.rawToLiveLatex(
            expressionRaw,
            cursorPos: activeField == 0 ? expressionCursorPos : null,
          );
    // Cabecera y cierre son de solo lectura y van fuera del buffer editable.
    final bodyStyle = TextStyle(fontSize: 19, color: textColor);
    Widget tex(String latex, String fallback) => Math.tex(
          CasioLcdScreen.sanitizeForMathTex(latex),
          textStyle: bodyStyle,
          onErrorFallback: (_) => Text(
            fallback,
            style: TextStyle(
              fontSize: 15,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra superior de acción de Cálculo en la LCD (siempre 100% visible en móvil/desktop)
        if (!operationsInHeader)
        SizedBox(
          height: 24,
          child: Row(
            children: [
              for (int i = 0; i < CalculusOperation.values.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _actionPill(
                    key: Key('calculus_op_${CalculusOperation.values[i].name}'),
                    label: CalculusOperation.values[i].shortLabel,
                    selected: selectedOperation == CalculusOperation.values[i],
                    onTap: () =>
                        onSelectOperation?.call(CalculusOperation.values[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 5),

        // Caja editable de f(x) con Natural Display (100% teclado físico): \int [ f(x) ] dx
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  tex(prefixLatex, 'f(x) ='),
                  const SizedBox(width: 4),
                  LcdInputBox(
                    key: const Key('calculus_expr_box'),
                    active: activeField == 0,
                    dark: isOledDark,
                    latex: bodyLatex,
                    text: '',
                    placeholder: '0',
                    fontSize: 18,
                    minWidth: 150,
                    minHeight: 44,
                    expandable: true,
                    onTap: () => onSelectField?.call(0),
                  ),
                  const SizedBox(width: 4),
                  if (suffixLatex.isNotEmpty) tex(suffixLatex, ')'),
                ],
              ),
            ),
          ),
        ),

        // Fila auxiliar de x₀ (Tangente) o límites [a, b] (Integral definida Barrow)
        if (selectedOperation == CalculusOperation.tangentLine) ...[
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  'Punto de tangencia:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(width: 6),
                _buildAuxCell(
                  key: const Key('calculus_x0_box'),
                  prefix: 'x₀ =',
                  value: x0Raw,
                  isActive: activeField == 1,
                  onTap: () => onSelectField?.call(1),
                ),
              ],
            ),
          ),
        ] else if (selectedOperation == CalculusOperation.definiteIntegral) ...[
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  'Barrow [a, b]:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(width: 6),
                _buildAuxCell(
                  key: const Key('calculus_a_box'),
                  prefix: 'a =',
                  value: limitARaw,
                  isActive: activeField == 1,
                  onTap: () => onSelectField?.call(1),
                ),
                const SizedBox(width: 6),
                _buildAuxCell(
                  key: const Key('calculus_b_box'),
                  prefix: 'b =',
                  value: limitBRaw,
                  isActive: activeField == 2,
                  onTap: () => onSelectField?.call(2),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Usa ALPHA+) para x y x²/x³/xⁿ para potencias',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: mutedColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAuxCell({
    required Key key,
    required String prefix,
    required String value,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final trimmed = value.trim();
    final isFraction = trimmed.contains('/');
    final labelColor = isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF1A2530);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$prefix ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            color: labelColor.withValues(alpha: 0.8),
          ),
        ),
        LcdInputBox(
          key: key,
          active: isActive,
          dark: isOledDark,
          // Los digitos nuevos van siempre a la ultima parte: el cursor esta en el denominador.
          latex: isFraction
              ? CasioCellValueText.fractionTex(trimmed, activePart: isActive ? 1 : null, coloredCursor: true)
              : null,
          text: isFraction ? null : value,
          placeholder: '0',
          fontSize: 15,
          minWidth: 64,
          minHeight: 34,
          expandable: true,
          alignment: Alignment.center,
          onTap: onTap,
        ),
      ],
    );
  }

  Widget _actionPill({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final bg = selected
        ? (isOledDark ? const Color(0xFFE5A93C) : const Color(0xFF181E29))
        : (isOledDark ? const Color(0xFF1A2421) : const Color(0xFFCAD6CE));
    final fg = selected
        ? Colors.white
        : (isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF0F172A));

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : (isOledDark
                    ? const Color(0xFF334155)
                    : const Color(0xFF7D8C82)),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
