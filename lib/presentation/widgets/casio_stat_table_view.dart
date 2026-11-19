import 'package:flutter/material.dart';

import 'casio_cell_value_text.dart';
import 'lcd/lcd_input_box.dart';

/// Tabla editable estilo Casio ClassWiz Iberia (2 columnas `xᵢ` | `fᵢ`)
/// para el Modo 9 (Estadística 1-Variable).
class CasioStatTableView extends StatefulWidget {
  final List<({String xi, String fi})> rows;
  final int activeRow;
  final int activeCol; // 0 = x_i, 1 = f_i
  final bool isOledDark;
  final void Function(int row, int col)? onCellTap;

  /// Acciones inline bajo la ultima fila: `+ Añadir fila` y `− Quitar fila` (solo con mas de 2).
  final VoidCallback? onAddRow;
  final VoidCallback? onRemoveRow;

  /// 2 variables (regresion): la segunda columna es `yᵢ` (sin frecuencia por defecto).
  final bool twoVar;

  const CasioStatTableView({
    super.key,
    required this.rows,
    required this.activeRow,
    required this.activeCol,
    this.isOledDark = false,
    this.onCellTap,
    this.onAddRow,
    this.onRemoveRow,
    this.twoVar = false,
  });

  @override
  State<CasioStatTableView> createState() => _CasioStatTableViewState();
}

class _CasioStatTableViewState extends State<CasioStatTableView> {
  final ScrollController _scrollController = ScrollController();
  static const double _rowExtent = 30.0;

  @override
  void didUpdateWidget(covariant CasioStatTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeRow != widget.activeRow && _scrollController.hasClients) {
      final targetOffset = widget.activeRow * _rowExtent;
      final viewport = _scrollController.position.viewportDimension;
      final current = _scrollController.offset;
      if (targetOffset < current) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      } else if (targetOffset + _rowExtent > current + viewport) {
        _scrollController.animateTo(
          (targetOffset + _rowExtent - viewport).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final headerBg = widget.isOledDark
        ? const Color(0xFF1E2925)
        : const Color(0xFFBAC8BF);
    final headerText = widget.isOledDark
        ? const Color(0xFFE8F3EE)
        : const Color(0xFF0F172A);
    final borderColor = widget.isOledDark
        ? const Color(0xFF33413E)
        : const Color(0xFF88998E);
    final indexBg = widget.isOledDark
        ? const Color(0xFF17201D)
        : const Color(0xFFC5D3CA);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Cabecera de tabla ClassWiz: # | x_i | f_i
          Container(
            height: 22,
            color: headerBg,
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Center(
                    child: Text(
                      '#',
                      style: TextStyle(
                        color: headerText,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: borderColor),
                Expanded(
                  child: Center(
                    child: Text(
                      'xᵢ',
                      style: TextStyle(
                        color: headerText,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: borderColor),
                Expanded(
                  child: Center(
                    child: Text(
                      widget.twoVar ? 'yᵢ' : 'fᵢ (Freq)',
                      style: TextStyle(
                        color: headerText,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: borderColor),

          // Filas desplazables
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemExtent: _rowExtent,
              itemCount: widget.rows.length + (widget.onAddRow != null ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == widget.rows.length) return _buildFooter(borderColor);
                final row = widget.rows[index];
                final isXiActive =
                    index == widget.activeRow && widget.activeCol == 0;
                final isFiActive =
                    index == widget.activeRow && widget.activeCol == 1;

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: borderColor.withValues(alpha: 0.45),
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 30,
                        color: indexBg,
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: headerText.withValues(alpha: 0.78),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      VerticalDivider(width: 1, thickness: 1, color: borderColor),
                      Expanded(
                        child: _buildCell(
                          key: Key('stat_cell_${index}_0'),
                          value: row.xi,
                          placeholder: isXiActive ? '?' : '',
                          isActive: isXiActive,
                          onTap: () => widget.onCellTap?.call(index, 0),
                        ),
                      ),
                      VerticalDivider(width: 1, thickness: 1, color: borderColor),
                      Expanded(
                        child: _buildCell(
                          key: Key('stat_cell_${index}_1'),
                          value: row.fi,
                          placeholder: !widget.twoVar && row.xi.trim().isNotEmpty ? '1' : '',
                          isActive: isFiActive,
                          onTap: () => widget.onCellTap?.call(index, 1),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Pie de la tabla: acciones discretas para anadir o quitar filas sin menus.
  Widget _buildFooter(Color borderColor) {
    final ink = widget.isOledDark ? const Color(0xFFE8F3EE) : const Color(0xFF1A2530);
    final fill = widget.isOledDark ? const Color(0xFF111615) : const Color(0xFFBDCEBE);
    Widget action(Key key, String label, VoidCallback onTap, {bool amber = false}) => Expanded(
          child: GestureDetector(
            key: key,
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: amber ? const Color(0xFFE5A93C) : const Color(0xFF7A8A7E), width: 1.5),
              ),
              child: Text(
                label,
                style: TextStyle(color: ink, fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        );
    return Row(
      key: const Key('stat_table_footer'),
      children: [
        action(const Key('stat_add_row_inline'), '+ Añadir fila', widget.onAddRow!, amber: true),
        if (widget.rows.length > 2 && widget.onRemoveRow != null)
          action(const Key('stat_remove_row_inline'), '− Quitar fila', widget.onRemoveRow!),
      ],
    );
  }

  Widget _buildCell({
    required Key key,
    required String value,
    required String placeholder,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final trimmed = value.trim();
    final isFraction = trimmed.contains('/');
    return LcdInputBox(
      key: key,
      active: isActive,
      dark: widget.isOledDark,
      latex: isFraction
          ? CasioCellValueText.fractionTex(trimmed, activePart: isActive ? 1 : null, coloredCursor: true)
          : null,
      text: isFraction ? null : value,
      placeholder: placeholder,
      fontSize: 14,
      minWidth: 0,
      minHeight: 0,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      onTap: onTap,
    );
  }
}
