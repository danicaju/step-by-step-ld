import 'package:flutter/material.dart';

import '../../domain/math_engine/solvers/matrix_solver.dart';
import 'casio_cell_value_text.dart';

/// Cuadrícula matricial editable integrada dentro de la LCD Casio ClassWiz
/// con selector libre de dimensiones (1..4 Filas × 1..4 Columnas) independiente para MatA y MatB.
class CasioMatrixEditorView extends StatelessWidget {
  final int rowsA;
  final int colsA;
  final int rowsB;
  final int colsB;
  final int activeMatrixTarget; // 0 = MatA, 1 = MatB, 2 = escalar k
  final MatrixOperation selectedOperation;
  final List<String> cellsA; // 25 entradas (5x5 stride)
  final List<String> cellsB;
  final String scalarK;
  final int activeRow;
  final int activeCol;
  final bool isOledDark;
  final void Function(int row, int col)? onCellTap;
  final ValueChanged<int>? onSwitchMatrixTarget;
  final void Function(int target, int rows, int cols)? onUpdateDimensions;
  final ValueChanged<MatrixOperation>? onSelectOperation;

  const CasioMatrixEditorView({
    super.key,
    required this.rowsA,
    required this.colsA,
    required this.rowsB,
    required this.colsB,
    required this.activeMatrixTarget,
    required this.selectedOperation,
    required this.cellsA,
    required this.cellsB,
    required this.scalarK,
    required this.activeRow,
    required this.activeCol,
    this.isOledDark = false,
    this.onCellTap,
    this.onSwitchMatrixTarget,
    this.onUpdateDimensions,
    this.onSelectOperation,
  });

  bool get _isSquareOnlyOp =>
      selectedOperation == MatrixOperation.determinant ||
      selectedOperation == MatrixOperation.inverse ||
      selectedOperation == MatrixOperation.adjoint;

  @override
  Widget build(BuildContext context) {
    final bool isEditingB = activeMatrixTarget == 1;
    final bool isEditingK = activeMatrixTarget == 2;
    final List<String> activeCells = isEditingB ? cellsB : cellsA;
    final String activeId = isEditingB ? 'B' : 'A';

    final int currentRows = isEditingB ? rowsB : rowsA;
    final int currentCols = isEditingB ? colsB : colsA;

    final Color textColor =
        isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF0F172A);
    final Color bracketColor =
        isOledDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);

    const int stride = 5;
    final double bracketH = currentRows == 1
        ? 34
        : (currentRows == 2 ? 52 : (currentRows == 3 ? 72 : 88));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Barra superior dentro de la LCD: Pestañas MatA/MatB + Selector m × n libre
        SizedBox(
          height: 24,
          child: Row(
            children: [
              _lcdPill(
                key: const Key('matrix_tab_A'),
                label: 'MatA',
                selected: activeMatrixTarget == 0,
                onTap: () => onSwitchMatrixTarget?.call(0),
              ),
              if (selectedOperation.needsMatrixB) ...[
                const SizedBox(width: 4),
                _lcdPill(
                  key: const Key('matrix_tab_B'),
                  label: 'MatB',
                  selected: activeMatrixTarget == 1,
                  accentColor: const Color(0xFF0EA5E9),
                  onTap: () => onSwitchMatrixTarget?.call(1),
                ),
              ],
              if (selectedOperation == MatrixOperation.scalarMultiply) ...[
                const SizedBox(width: 4),
                _lcdPill(
                  key: const Key('matrix_scalar_cell'),
                  label: 'k=${scalarK.isEmpty ? '?' : scalarK}',
                  selected: isEditingK,
                  accentColor: const Color(0xFFE5A93C),
                  onTap: () => onSwitchMatrixTarget?.call(2),
                ),
              ],
              const Spacer(),

              // Selector de dimensiones: cuadradas (2..4) si es determinante/inversa/adjunta,
              // o selector libre F x C (1..4) si es rectangular/Gauss/operaciones
              if (_isSquareOnlyOp) ...[
                Text(
                  'Dim:',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.75),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 3),
                for (final dim in [2, 3, 4]) ...[
                  if (dim > 2) const SizedBox(width: 2),
                  _lcdDimPill(
                    key: Key('matrix_size_$dim'),
                    label: '$dim×$dim',
                    selected: currentRows == dim && currentCols == dim,
                    onTap: () {
                      final target = isEditingB ? 1 : 0;
                      onUpdateDimensions?.call(target, dim, dim);
                    },
                  ),
                ],
              ] else ...[
                // Selector interactivo libre F: 1..4 x C: 1..4
                Text(
                  'F:',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 1),
                for (int r = 1; r <= 4; r++) ...[
                  _lcdDimPill(
                    key: Key('matrix_${activeId}_rows_$r'),
                    label: '$r',
                    selected: currentRows == r,
                    onTap: () {
                      final target = isEditingB ? 1 : 0;
                      onUpdateDimensions?.call(target, r, currentCols);
                    },
                  ),
                  if (r < 4) const SizedBox(width: 1.5),
                ],
                const SizedBox(width: 3),
                Text(
                  '×',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  'C:',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 1),
                for (int c = 1; c <= 4; c++) ...[
                  _lcdDimPill(
                    key: Key('matrix_${activeId}_cols_$c'),
                    label: '$c',
                    selected: currentCols == c,
                    onTap: () {
                      final target = isEditingB ? 1 : 0;
                      onUpdateDimensions?.call(target, currentRows, c);
                    },
                  ),
                  if (c < 4) const SizedBox(width: 1.5),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 3),

        // 2. Matriz editable central con corchetes adaptativos y auto-escalado
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth,
                    maxHeight: constraints.maxHeight,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          selectedOperation == MatrixOperation.determinant &&
                                  !isEditingB
                              ? '|A| ='
                              : (isEditingB ? 'B =' : 'A ='),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 5),
                        _MatrixBracket(
                          isLeft: true,
                          isDeterminant: selectedOperation ==
                                  MatrixOperation.determinant &&
                              !isEditingB,
                          color: bracketColor,
                          height: bracketH,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(currentRows, (r) {
                              return Padding(
                                padding: EdgeInsets.only(
                                    bottom: r < currentRows - 1 ? 3 : 0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(currentCols, (c) {
                                    final rawIdx = r * stride + c;
                                    final value = rawIdx < activeCells.length
                                        ? activeCells[rawIdx]
                                        : '';
                                    final isSelected = !isEditingK &&
                                        r == activeRow &&
                                        c == activeCol;
                                    return _buildCell(
                                      key: Key(
                                          'matrix_${activeId}_cell_${r}_$c'),
                                      value: value,
                                      isActive: isSelected,
                                      onTap: () => onCellTap?.call(r, c),
                                    );
                                  }),
                                ),
                              );
                            }),
                          ),
                        ),
                        _MatrixBracket(
                          isLeft: false,
                          isDeterminant: selectedOperation ==
                                  MatrixOperation.determinant &&
                              !isEditingB,
                          color: bracketColor,
                          height: bracketH,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 3),

        // 3. Tira de operaciones rápidas dentro de la LCD
        SizedBox(
          height: 22,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final op in MatrixOperation.values) ...[
                  _lcdActionChip(
                    key: Key('matrix_op_${op.name}'),
                    label: op == MatrixOperation.determinant &&
                            currentRows == 2 &&
                            currentCols == 2
                        ? '|A| (2×2)'
                        : op.shortLabel,
                    selected: selectedOperation == op,
                    onTap: () => onSelectOperation?.call(op),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCell({
    required Key key,
    required String value,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final Color activeBg =
        isOledDark ? const Color(0xFF172554) : const Color(0xFF141A17);
    final Color activeText =
        isOledDark ? const Color(0xFFF8FAFC) : const Color(0xFFFFFBEB);
    final Color idleBg =
        isOledDark ? const Color(0xFF1E2824) : const Color(0xFFC7D3C9);
    final Color idleText = isOledDark
        ? (value.isNotEmpty
            ? const Color(0xFFE8F3EE)
            : const Color(0xFF64748B))
        : (value.isNotEmpty
            ? const Color(0xFF0F172A)
            : const Color(0xFF64748B));
    final Color activeBorder =
        isOledDark ? const Color(0xFF2E86DE) : const Color(0xFFE5A93C);
    final Color idleBorder =
        isOledDark ? const Color(0xFF3B4D46) : const Color(0xFF88998E);

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        constraints: const BoxConstraints(minWidth: 34, minHeight: 22),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: isActive ? activeBg : idleBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? activeBorder : idleBorder,
            width: isActive ? 1.8 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: CasioCellValueText(
          value: value,
          emptyFallback: '0',
          style: TextStyle(
            color: isActive ? activeText : idleText,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _lcdPill({
    required Key key,
    required String label,
    required bool selected,
    Color? accentColor,
    required VoidCallback onTap,
  }) {
    final Color baseSelected = accentColor ?? const Color(0xFF2563EB);
    final Color bg = selected
        ? baseSelected
        : (isOledDark ? const Color(0xFF1E293B) : const Color(0xFFBAC7BE));
    final Color fg = selected
        ? Colors.white
        : (isOledDark ? const Color(0xFF94A3B8) : const Color(0xFF334155));

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: selected ? 1.0 : 0.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _lcdDimPill({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final Color bg = selected
        ? const Color(0xFF2563EB)
        : (isOledDark ? const Color(0xFF1E293B) : const Color(0xFFC7D3C9));
    final Color fg = selected
        ? Colors.white
        : (isOledDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155));

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: selected ? Colors.cyanAccent : Colors.transparent,
            width: selected ? 1.0 : 0.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _lcdActionChip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final Color bg = selected
        ? (isOledDark ? const Color(0xFF2563EB) : const Color(0xFF1E3A5F))
        : (isOledDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1));
    final Color fg = selected
        ? Colors.white
        : (isOledDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155));

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected
                ? const Color(0xFF60A5FA)
                : (isOledDark
                    ? const Color(0xFF334155)
                    : const Color(0xFF94A3B8)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _MatrixBracket extends StatelessWidget {
  final bool isLeft;
  final bool isDeterminant;
  final Color color;
  final double height;

  const _MatrixBracket({
    required this.isLeft,
    required this.isDeterminant,
    required this.color,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (isDeterminant) {
      return Container(
        width: 2.2,
        height: height,
        color: color,
        margin: const EdgeInsets.symmetric(horizontal: 2),
      );
    }
    return CustomPaint(
      size: Size(6, height),
      painter: _BracketPainter(isLeft: isLeft, color: color),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final bool isLeft;
  final Color color;

  _BracketPainter({required this.isLeft, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isLeft) {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter oldDelegate) {
    return oldDelegate.isLeft != isLeft || oldDelegate.color != color;
  }
}
