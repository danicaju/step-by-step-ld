import 'package:flutter/material.dart';

import 'casio_cell_value_text.dart';

class CasioCoefficientView extends StatelessWidget {
  final int mode; // 3 (Sist 2x2/3x3), 4 (Ruffini), 5 (Gráficas), 6 (Inecuaciones 2.º)
  final List<String> cellValues;
  final List<String> cellLabels;
  final int activeIndex;
  final bool isOledDark;
  final int notableTypeIndex; // 0: (A+B)², 1: (A-B)², 2: (A+B)(A-B)
  final String inequalitySignSymbol; // '<', '≤', '>', '≥'
  final VoidCallback? onCycleInequalitySign;
  final ValueChanged<int>? onCellTap;

  const CasioCoefficientView({
    super.key,
    required this.mode,
    required this.cellValues,
    required this.cellLabels,
    required this.activeIndex,
    this.isOledDark = false,
    this.notableTypeIndex = 1,
    this.inequalitySignSymbol = '<',
    this.onCycleInequalitySign,
    this.onCellTap,
  });

  Widget _buildCell(int index, {bool compact = false}) {
    final bool isActive = index == activeIndex;
    final String val = index < cellValues.length ? cellValues[index] : '';
    final String label = index < cellLabels.length ? cellLabels[index] : '';

    final Color activeBg = isOledDark ? const Color(0xFF172554) : const Color(0xFF141A17);
    final Color activeText = isOledDark ? const Color(0xFFF8FAFC) : const Color(0xFFFFFBEB);
    final Color inactiveBg = isOledDark ? const Color(0xFF1E2824) : const Color(0xFFC7D3C9);
    final Color inactiveText = isOledDark
        ? (val.isNotEmpty ? const Color(0xFFE8F3EE) : const Color(0xFF64748B))
        : (val.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF64748B));
    final Color inactiveBorderColor =
        isOledDark ? const Color(0xFF3B4D46) : const Color(0xFF88998E);
    final Color activeBorderColor =
        isOledDark ? const Color(0xFF2E86DE) : const Color(0xFFE5A93C);

    final box = AnimatedContainer(
      key: Key('coeff_cell_$index'),
      duration: const Duration(milliseconds: 120),
      constraints: BoxConstraints(
        minWidth: compact ? 26 : 34,
        minHeight: compact ? 22 : 28,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 1 : 2,
      ),
      margin: EdgeInsets.symmetric(horizontal: compact ? 1.5 : 2),
      decoration: BoxDecoration(
        color: isActive ? activeBg : inactiveBg,
        borderRadius: BorderRadius.circular(5.0),
        border: Border.all(
          color: isActive ? activeBorderColor : inactiveBorderColor,
          width: isActive ? 2.2 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF2E86DE).withValues(alpha: 0.45),
                  blurRadius: 6.0,
                  spreadRadius: 0.5,
                ),
                BoxShadow(
                  color: const Color(0xFFE5A93C).withValues(alpha: 0.35),
                  blurRadius: 3.0,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: CasioCellValueText(
        value: val,
        emptyFallback: label,
        style: TextStyle(
          color: isActive ? activeText : inactiveText,
          fontSize: compact ? 13 : 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );

    if (onCellTap == null) return box;
    return GestureDetector(
      onTap: () => onCellTap!(index),
      child: box,
    );
  }

  Widget _mathSymbol(String text, {bool compact = false}) {
    final color = isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF0F172A);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.0),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: compact ? 13.5 : 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (mode == 4) {
      // Modo 4: Polinomio P(x) para Ruffini de grado 2..6 (3..7 coeficientes)
      const supDigits = {
        2: '²',
        3: '³',
        4: '⁴',
        5: '⁵',
        6: '⁶',
      };
      final degree = (cellValues.length - 1).clamp(1, 6);

      List<Widget> buildTermSlice(int start, int end, {bool includePrefix = false}) {
        final widgets = <Widget>[];
        if (includePrefix) {
          widgets.add(_mathSymbol('P(x) = '));
        }
        for (int i = start; i < end; i++) {
          final exp = degree - i;
          widgets.add(_buildCell(i));
          if (exp > 1) {
            widgets.add(_mathSymbol('x${supDigits[exp] ?? '^$exp'} + '));
          } else if (exp == 1) {
            widgets.add(_mathSymbol('x + '));
          }
        }
        return widgets;
      }

      if (degree <= 3) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: buildTermSlice(0, cellValues.length, includePrefix: true),
        );
      }

      final splitIdx = (cellValues.length + 1) ~/ 2;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: buildTermSlice(0, splitIdx, includePrefix: true),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: buildTermSlice(splitIdx, cellValues.length),
          ),
        ],
      );
    }

    if (mode == 3 && cellValues.length < 12) {
      // Modo 3: Sistemas 2x2
      // [ a1 ]x + [ b1 ]y = [ c1 ]
      // [ a2 ]x + [ b2 ]y = [ c2 ]
      final color = isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF0F172A);
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '{',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w200,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCell(0),
                  _mathSymbol('x + '),
                  _buildCell(1),
                  _mathSymbol('y = '),
                  _buildCell(2),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCell(3),
                  _mathSymbol('x + '),
                  _buildCell(4),
                  _mathSymbol('y = '),
                  _buildCell(5),
                ],
              ),
            ],
          ),
        ],
      );
    }

    if (mode == 5) {
      // Modo 5: Gráficas y = [ a ]x² + [ b ]x + [ c ]
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _mathSymbol('y = '),
          _buildCell(0),
          _mathSymbol('x² + '),
          _buildCell(1),
          _mathSymbol('x + '),
          _buildCell(2),
        ],
      );
    }

    if (mode == 6) {
      // Modo 6 (Inecuaciones 2.º grado): [ a ]x² + [ b ]x + [ c ] [ ≶ ] 0
      final bool isSignActive = activeIndex == 3;
      final Color signBg = isSignActive
          ? (isOledDark ? const Color(0xFF1E3A8A) : const Color(0xFF1E40AF))
          : (isOledDark ? const Color(0xFF253042) : const Color(0xFFCBD5CE));
      final Color signBorder = isSignActive
          ? const Color(0xFFE5A93C)
          : (isOledDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6));
      final Color signText = isSignActive || isOledDark
          ? Colors.white
          : const Color(0xFF1E3A8A);

      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCell(0),
          _mathSymbol('x² + '),
          _buildCell(1),
          _mathSymbol('x + '),
          _buildCell(2),
          const SizedBox(width: 4),
          GestureDetector(
            key: const Key('ineq_quad_sign_cell'),
            onTap: () {
              onCellTap?.call(3);
              onCycleInequalitySign?.call();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: signBg,
                borderRadius: BorderRadius.circular(5.0),
                border: Border.all(
                  color: signBorder,
                  width: isSignActive ? 2.2 : 1.4,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                inequalitySignSymbol,
                style: TextStyle(
                  color: signText,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          _mathSymbol(' 0'),
        ],
      );
    }

    if (mode == 3 && cellValues.length == 12) {
      // Modo 3: Sistemas 3x3 (12 celdas: a_r x + b_r y + c_r z = d_r)
      final color = isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF0F172A);
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '{',
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w200,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(3, (r) {
              final base = r * 4;
              return Padding(
                padding: EdgeInsets.only(bottom: r < 2 ? 4 : 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCell(base, compact: true),
                    _mathSymbol('x+', compact: true),
                    _buildCell(base + 1, compact: true),
                    _mathSymbol('y+', compact: true),
                    _buildCell(base + 2, compact: true),
                    _mathSymbol('z=', compact: true),
                    _buildCell(base + 3, compact: true),
                  ],
                ),
              );
            }),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
