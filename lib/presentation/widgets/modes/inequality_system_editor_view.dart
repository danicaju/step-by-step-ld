import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../domain/math_engine/parser/expression_parser.dart';

class IneqSysUnknownsSelectorView extends StatelessWidget {
  final bool isOledDark;
  final int ineqSysUnknowns;
  final ValueChanged<int> onSelectUnknowns;

  const IneqSysUnknownsSelectorView({
    super.key,
    required this.isOledDark,
    required this.ineqSysUnknowns,
    required this.onSelectUnknowns,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF101815);
    final unselectedBg =
        isOledDark ? const Color(0xFF1E293B) : const Color(0xFFC8D6CD);
    final unselectedBorder =
        isOledDark ? const Color(0xFF334155) : const Color(0xFF7A8C80);
    final selectedBg = const Color(0xFF1A2530);
    const selectedBorder = Color(0xFF1A2530);

    return LayoutBuilder(
      builder: (context, constraints) {
        final safeWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 320.0;
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: safeWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Selecciona incógnitas del sistema:',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          key: const Key('ineq_sys_sel_unk_1'),
                          onTap: () => onSelectUnknowns(1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: ineqSysUnknowns == 1
                                  ? selectedBg
                                  : unselectedBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: ineqSysUnknowns == 1
                                    ? selectedBorder
                                    : unselectedBorder,
                                width: ineqSysUnknowns == 1 ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '1: Una Incógnita (x)',
                                  style: TextStyle(
                                    color: ineqSysUnknowns == 1
                                        ? Colors.white
                                        : textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Recta Real 1D',
                                  style: TextStyle(
                                    color: (ineqSysUnknowns == 1
                                            ? Colors.white
                                            : textColor)
                                        .withValues(alpha: 0.7),
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          key: const Key('ineq_sys_sel_unk_2'),
                          onTap: () => onSelectUnknowns(2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: ineqSysUnknowns == 2
                                  ? selectedBg
                                  : unselectedBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: ineqSysUnknowns == 2
                                    ? selectedBorder
                                    : unselectedBorder,
                                width: ineqSysUnknowns == 2 ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '2: Dos Incógnitas (x, y)',
                                  style: TextStyle(
                                    color: ineqSysUnknowns == 2
                                        ? Colors.white
                                        : textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Plano 2D / Región Sf',
                                  style: TextStyle(
                                    color: (ineqSysUnknowns == 2
                                            ? Colors.white
                                            : textColor)
                                        .withValues(alpha: 0.7),
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
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
}

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
    final rowBg =
        isOledDark ? const Color(0xFF1E293B) : const Color(0xFFC8D6CD);
    final activeRowBg =
        isOledDark ? const Color(0xFF0F172A) : const Color(0xFFD4E2D9);
    final activeBorder =
        isOledDark ? const Color(0xFF1A2530) : const Color(0xFF1A2530);
    final inactiveBorder =
        isOledDark ? const Color(0xFF334155) : const Color(0xFF7A8C80);

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
                          GestureDetector(
                            key: Key('ineq_sys_row_$i'),
                            onTap: () => onSelectRow(i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: ineqSysActiveRow == i ? activeRowBg : rowBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: ineqSysActiveRow == i
                                      ? activeBorder
                                      : inactiveBorder,
                                  width: ineqSysActiveRow == i ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
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
                                    child: Builder(
                                      builder: (context) {
                                        final raw = ineqSysRowInputs[i];
                                        final isActive = ineqSysActiveRow == i;
                                        final cursor = isActive
                                            ? ineqSysRowCursors[i]
                                            : null;
                                        final String rowTex;
                                        if (raw.isEmpty) {
                                          rowTex = isActive
                                              ? r'\textcolor{#2E86DE}{\blacksquare}'
                                              : (ineqSysUnknowns == 1
                                                  ? r'2x - 3 \le 5'
                                                  : r'x + y \le 4');
                                        } else {
                                          rowTex = ExpressionParser.rawToLiveLatex(
                                            raw,
                                            cursorPos: cursor,
                                          );
                                        }
                                        return FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Math.tex(
                                            rowTex,
                                            textStyle: TextStyle(
                                              color: raw.isEmpty && !isActive
                                                  ? textColor.withValues(
                                                      alpha: 0.38)
                                                  : textColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
}
