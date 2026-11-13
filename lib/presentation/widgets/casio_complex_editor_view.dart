import 'package:flutter/material.dart';

import '../../domain/math_engine/solvers/complex_solver.dart';
import 'casio_cell_value_text.dart';

/// Editor LCD interactivo para el Modo 10 (Números Complejos: Binómica a+bi ⬄ Polar r_α).
class CasioComplexEditorView extends StatelessWidget {
  final ComplexOperation selectedOperation;
  final List<String> cells; // [a1, b1, a2, b2] o [r, alphaDeg] en fromPolar
  final int activeIndex;
  final bool isOledDark;
  final ValueChanged<int>? onCellTap;
  final ValueChanged<ComplexOperation>? onSelectOperation;

  const CasioComplexEditorView({
    super.key,
    required this.selectedOperation,
    required this.cells,
    required this.activeIndex,
    this.isOledDark = false,
    this.onCellTap,
    this.onSelectOperation,
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
        // Subtítulo contextual
        SizedBox(
          height: 18,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                selectedOperation == ComplexOperation.fromPolar
                    ? 'Conversión Polar r_α → Binómica a + bi'
                    : (selectedOperation == ComplexOperation.toPolar
                        ? 'Conversión Binómica a + bi → Polar r_α'
                        : 'Complejos en Forma Binómica (a + bi)'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  color: mutedColor,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Cuerpo de celdas editables
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: selectedOperation == ComplexOperation.fromPolar
                  ? _buildPolarRow(textColor)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBinomialRow(
                          prefix: selectedOperation.needsSecondComplex
                              ? 'z₁ = '
                              : 'z  = ',
                          baseIdx: 0,
                          textColor: textColor,
                        ),
                        if (selectedOperation.needsSecondComplex) ...[
                          const SizedBox(height: 6),
                          _buildBinomialRow(
                            prefix: 'z₂ = ',
                            baseIdx: 2,
                            textColor: textColor,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Barra inferior de acciones rápidas (100% visible en móvil/desktop)
        SizedBox(
          height: 24,
          child: Row(
            children: [
              for (int i = 0; i < ComplexOperation.values.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _lcdActionChip(
                    key: Key('complex_op_${ComplexOperation.values[i].name}'),
                    label: ComplexOperation.values[i].shortLabel,
                    selected: selectedOperation == ComplexOperation.values[i],
                    onTap: () =>
                        onSelectOperation?.call(ComplexOperation.values[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBinomialRow({
    required String prefix,
    required int baseIdx,
    required Color textColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
        _buildNumCell(
          index: baseIdx,
          hint: 'Real (a)',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text(
            '+',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        _buildNumCell(
          index: baseIdx + 1,
          hint: 'Imag (b)',
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'i',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPolarRow(Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'z = ',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            color: textColor,
          ),
        ),
        _buildNumCell(index: 0, hint: 'Mód r'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '∠',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        _buildNumCell(index: 1, hint: 'Áng α°'),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            '°',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumCell({
    required int index,
    required String hint,
  }) {
    final bool isActive = activeIndex == index;
    final String value = index < cells.length ? cells[index] : '';
    final activeBg =
        isOledDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A);
    final activeFg = isOledDark ? Colors.black : Colors.white;
    final idleBg =
        isOledDark ? const Color(0xFF1A2421) : const Color(0xFFCAD6CE);
    final idleFg =
        isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF0F172A);

    return GestureDetector(
      key: Key('complex_cell_$index'),
      onTap: () => onCellTap?.call(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        constraints: const BoxConstraints(minWidth: 52, minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? activeBg : idleBg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isActive
                ? (isOledDark ? Colors.white : const Color(0xFF0F172A))
                : (isOledDark
                    ? const Color(0xFF334155)
                    : const Color(0xFF7D8C82)),
            width: isActive ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CasioCellValueText(
              value: value,
              emptyFallback: '0',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                color: isActive
                    ? activeFg
                    : (value.isEmpty ? idleFg.withValues(alpha: 0.45) : idleFg),
              ),
            ),
            Text(
              hint,
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w700,
                color: (isActive ? activeFg : idleFg).withValues(alpha: 0.65),
              ),
            ),
          ],
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
        ? (isOledDark ? const Color(0xFF7C5CFF) : const Color(0xFF1D4ED8))
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
