import 'package:flutter/material.dart';

import '../../domain/math_engine/solvers/matrix_solver.dart';
import 'casio_cell_value_text.dart';

/// Cuadrícula matricial editable integrada dentro de la LCD Casio ClassWiz
/// para el Modo 8 (Matrices 2x2 y 3x3: Sarrus, Inversa, Adjunta, A·B, A+B).
class CasioMatrixEditorView extends StatelessWidget {
  final int dimension; // 2 o 3
  final int activeMatrixTarget; // 0 = MatA, 1 = MatB, 2 = escalar k
  final MatrixOperation selectedOperation;
  final List<String> cellsA; // 9 entradas row-major (3x3; para 2x2 se usan 0,1,3,4 o [r*3+c])
  final List<String> cellsB;
  final String scalarK;
  final int activeRow;
  final int activeCol;
  final bool isOledDark;
  final void Function(int row, int col)? onCellTap;
  final ValueChanged<int>? onSwitchMatrixTarget;
  final ValueChanged<int>? onChangeDimension;
  final ValueChanged<MatrixOperation>? onSelectOperation;

  const CasioMatrixEditorView({
    super.key,
    required this.dimension,
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
    this.onChangeDimension,
    this.onSelectOperation,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEditingB = activeMatrixTarget == 1;
    final bool isEditingK = activeMatrixTarget == 2;
    final List<String> activeCells = isEditingB ? cellsB : cellsA;
    final String activeId = isEditingB ? 'B' : 'A';

    final Color textColor =
        isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF0F172A);
    final Color bracketColor =
        isOledDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra superior dentro de la LCD: selector MatA/MatB + [2x2] / [3x3]
        SizedBox(
          height: 22,
          child: Row(
            children: [
              _lcdPill(
                key: const Key('matrix_tab_A'),
                label: 'MatA',
                selected: activeMatrixTarget == 0,
                onTap: () => onSwitchMatrixTarget?.call(0),
              ),
              const SizedBox(width: 4),
              _lcdPill(
                key: const Key('matrix_tab_B'),
                label: 'MatB',
                selected: activeMatrixTarget == 1,
                accentColor: selectedOperation.needsMatrixB
                    ? const Color(0xFF0EA5E9)
                    : null,
                onTap: () => onSwitchMatrixTarget?.call(1),
              ),
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
              _lcdPill(
                key: const Key('matrix_size_2'),
                label: '2×2',
                selected: dimension == 2,
                onTap: () => onChangeDimension?.call(2),
              ),
              const SizedBox(width: 3),
              _lcdPill(
                key: const Key('matrix_size_3'),
                label: '3×3',
                selected: dimension == 3,
                onTap: () => onChangeDimension?.call(3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),

        // Matriz editable central con paréntesis adaptativos y auto-escalado
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
                          height: dimension == 2 ? 52 : 76,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(dimension, (r) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: r < dimension - 1 ? 3 : 0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(dimension, (c) {
                                    final rawIdx = r * 3 + c;
                                    final value = activeCells[rawIdx];
                                    final isSelected = !isEditingK &&
                                        r == activeRow &&
                                        c == activeCol;
                                    return _buildCell(
                                      key: Key('matrix_${activeId}_cell_${r}_$c'),
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
                          height: dimension == 2 ? 52 : 76,
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

        // Tira de botones rápidos en la LCD: |A| (Sarrus), A⁻¹ (Inversa), Adj(A), A·B, A+B...
        SizedBox(
          height: 22,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final op in MatrixOperation.values) ...[
                  _lcdActionChip(
                    key: Key('matrix_op_${op.name}'),
                    label: op == MatrixOperation.determinant && dimension == 2
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
        ? (value.isNotEmpty ? const Color(0xFFE8F3EE) : const Color(0xFF64748B))
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
    final bg = selected
        ? (isOledDark ? const Color(0xFF1E40AF) : const Color(0xFF0F172A))
        : (isOledDark ? const Color(0xFF1F2925) : const Color(0xFFC5D0C8));
    final border = selected
        ? (accentColor ?? const Color(0xFFE5A93C))
        : (accentColor ?? (isOledDark ? const Color(0xFF374151) : const Color(0xFF8C9B91)));
    final fg = selected
        ? Colors.white
        : (isOledDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B));

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border, width: selected ? 1.4 : 0.9),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
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
    final bg = selected
        ? (isOledDark ? const Color(0xFF0284C7) : const Color(0xFF1E3A8A))
        : (isOledDark ? const Color(0xFF1A2220) : const Color(0xFFCBD5CE));
    final fg = selected
        ? Colors.white
        : (isOledDark ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A));
    final border = selected
        ? const Color(0xFF38BDF8)
        : (isOledDark ? const Color(0xFF334155) : const Color(0xFF94A39B));

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border, width: 1.0),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
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
        width: 2.0,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        color: color,
      );
    }

    return SizedBox(
      width: 6,
      height: height,
      child: CustomPaint(
        painter: _ParenPainter(isLeft: isLeft, color: color),
      ),
    );
  }
}

class _ParenPainter extends CustomPainter {
  final bool isLeft;
  final Color color;

  const _ParenPainter({required this.isLeft, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (isLeft) {
      path.moveTo(size.width - 1, 2);
      path.quadraticBezierTo(0, size.height / 2, size.width - 1, size.height - 2);
    } else {
      path.moveTo(1, 2);
      path.quadraticBezierTo(size.width, size.height / 2, 1, size.height - 2);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ParenPainter oldDelegate) =>
      oldDelegate.isLeft != isLeft || oldDelegate.color != color;
}
