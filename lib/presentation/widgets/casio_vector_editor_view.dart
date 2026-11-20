import 'package:flutter/material.dart';

import '../../domain/math_engine/solvers/vector_solver.dart';
import 'casio_cell_value_text.dart';
import 'lcd/lcd_input_box.dart';

/// Editor LCD interactivo para el Modo 9 (Vectores 2D / 3D: Módulo, u·v y Ángulo, u×v y Área).
class CasioVectorEditorView extends StatelessWidget {
  final int dimension; // 2 o 3
  final VectorOperation selectedOperation;
  final List<String> cellsU; // 3 entradas: x, y, z
  final List<String> cellsV; // 3 entradas: x, y, z
  final List<String>? cellsW; // 3 entradas (producto mixto)
  final int activeRow; // 0 = u, 1 = v, 2 = w
  final int activeCol; // 0 = x, 1 = y, 2 = z
  final bool isOledDark;
  final void Function(int row, int col)? onCellTap;
  final ValueChanged<int>? onChangeDimension;
  final ValueChanged<VectorOperation>? onSelectOperation;

  /// `true` si la operación se elige en el desplegable de la cabecera LCD.
  final bool operationsInHeader;

  /// `true` si la fraccion de la celda activa edita el numerador (cursor arriba).
  final bool fractionNumeratorActive;

  const CasioVectorEditorView({
    super.key,
    required this.dimension,
    required this.selectedOperation,
    required this.cellsU,
    required this.cellsV,
    this.cellsW,
    required this.activeRow,
    required this.activeCol,
    this.isOledDark = false,
    this.onCellTap,
    this.onChangeDimension,
    this.onSelectOperation,
    this.operationsInHeader = false,
    this.fractionNumeratorActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF0F172A);
    final mutedColor =
        isOledDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra superior dentro de la LCD: selector [2D] / [3D]
        if (!operationsInHeader)
        SizedBox(
          height: 22,
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    dimension == 2 ? 'Plano ℝ² (x, y)' : 'Espacio ℝ³ (x, y, z)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: mutedColor,
                    ),
                  ),
                ),
              ),
              _lcdPill(
                key: const Key('vector_dim_2'),
                label: '2D',
                selected: dimension == 2,
                onTap: () => onChangeDimension?.call(2),
              ),
              const SizedBox(width: 4),
              _lcdPill(
                key: const Key('vector_dim_3'),
                label: '3D',
                selected: dimension == 3,
                onTap: () => onChangeDimension?.call(3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Cuerpo de componentes de u y v (sin presets: vacías muestran 0 atenuado)
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildVectorRow(
                    prefix: 'u⃗ = (',
                    rowIdx: 0,
                    values: cellsU,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                  if (selectedOperation.needsSecondVector) ...[
                    const SizedBox(height: 6),
                    _buildVectorRow(
                      prefix: 'v⃗ = (',
                      rowIdx: 1,
                      values: cellsV,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                  ],
                  if (selectedOperation.needsThirdVector && cellsW != null) ...[
                    const SizedBox(height: 6),
                    _buildVectorRow(
                      prefix: 'w⃗ = (',
                      rowIdx: 2,
                      values: cellsW!,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Barra inferior de acciones rápidas en LCD (100% visible en móvil/desktop)
        if (!operationsInHeader)
        SizedBox(
          height: 24,
          child: Row(
            children: [
              for (int i = 0; i < VectorOperation.values.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _lcdActionChip(
                    key: Key('vector_op_${VectorOperation.values[i].name}'),
                    label: VectorOperation.values[i].shortLabel,
                    selected: selectedOperation == VectorOperation.values[i],
                    onTap: () =>
                        onSelectOperation?.call(VectorOperation.values[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVectorRow({
    required String prefix,
    required int rowIdx,
    required List<String> values,
    required Color textColor,
    required Color mutedColor,
  }) {
    final compNames = ['x', 'y', 'z'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          prefix,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            color: textColor,
          ),
        ),
        for (int c = 0; c < dimension; c++) ...[
          if (c > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                ',',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          _buildCoordCell(
            key: Key('vector_${const ['u', 'v', 'w'][rowIdx]}_cell_$c'),
            value: values[c],
            hint: compNames[c],
            isActive: activeRow == rowIdx && activeCol == c,
            onTap: () => onCellTap?.call(rowIdx, c),
          ),
        ],
        Text(
          ' )',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCoordCell({
    required Key key,
    required String value,
    required String hint,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final idleFg = isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF1A2530);
    final trimmed = value.trim();
    final isFraction = CasioCellValueText.needsLatex(trimmed);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LcdInputBox(
          key: key,
          active: isActive,
          dark: isOledDark,
          latex: isFraction
              ? CasioCellValueText.fractionTex(trimmed, activePart: isActive ? (fractionNumeratorActive ? 0 : 1) : null, coloredCursor: true)
              : null,
          text: isFraction ? null : value,
          placeholder: '0',
          fontSize: 14,
          minWidth: 46,
          minHeight: 30,
          expandable: true,
          alignment: Alignment.center,
          onTap: onTap,
        ),
        Text(
          hint,
          style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700, color: idleFg.withValues(alpha: 0.65)),
        ),
      ],
    );
  }

  Widget _lcdPill({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final bg = selected
        ? (isOledDark ? const Color(0xFFE5A93C) : const Color(0xFF0F172A))
        : (isOledDark ? const Color(0xFF1A2421) : const Color(0xFFCAD6CE));
    final fg = selected
        ? (isOledDark ? Colors.black : Colors.white)
        : (isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF0F172A));

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isOledDark
                ? const Color(0xFF334155)
                : const Color(0xFF7D8C82),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: fg,
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
        ? const Color(0xFF1A2530)
        : (isOledDark ? const Color(0xFF1A2421) : const Color(0xFFCAD6CE));
    final fg = selected
        ? Colors.white
        : (isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF0F172A));

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
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
