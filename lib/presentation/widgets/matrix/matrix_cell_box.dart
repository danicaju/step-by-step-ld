import 'package:flutter/material.dart';

import '../casio_cell_value_text.dart';
import '../lcd/lcd_input_box.dart';

/// Celda de matriz (M9): [LcdInputBox] grande (68 x 46) con fraccion vertical en LaTeX
/// y cursor parpadeante. Al activarse se desplaza a la vista dentro del scroll bidireccional.
class MatrixCellBox extends StatefulWidget {
  final String value;
  final bool active;

  /// Celda activa con fraccion: `true` = cursor en el numerador, `false` = denominador.
  final bool numeratorActive;
  final bool dark;
  final VoidCallback? onTap;

  const MatrixCellBox({
    super.key,
    required this.value,
    required this.active,
    this.numeratorActive = false,
    this.dark = false,
    this.onTap,
  });

  static const double minWidth = 68;
  static const double minHeight = 46;
  static const double fontSize = 17;

  @override
  State<MatrixCellBox> createState() => _MatrixCellBoxState();
}

class _MatrixCellBoxState extends State<MatrixCellBox> {
  @override
  void initState() {
    super.initState();
    if (widget.active) _reveal();
  }

  @override
  void didUpdateWidget(MatrixCellBox old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _reveal();
  }

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 90),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value.trim();
    final isFraction = v.contains('/');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: LcdInputBox(
        active: widget.active,
        dark: widget.dark,
        latex: isFraction
            ? CasioCellValueText.fractionTex(
                v,
                activePart: widget.active ? (widget.numeratorActive ? 0 : 1) : null,
                coloredCursor: true,
              )
            : null,
        text: isFraction ? null : widget.value,
        placeholder: '0',
        fontSize: MatrixCellBox.fontSize,
        minWidth: MatrixCellBox.minWidth,
        minHeight: MatrixCellBox.minHeight,
        expandable: true,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        onTap: widget.onTap,
      ),
    );
  }
}
