import 'package:flutter/material.dart';

/// Tabla editable estilo Casio ClassWiz Iberia (2 columnas `xᵢ` | `fᵢ`)
/// para el Modo 9 (Estadística 1-Variable).
class CasioStatTableView extends StatefulWidget {
  final List<({String xi, String fi})> rows;
  final int activeRow;
  final int activeCol; // 0 = x_i, 1 = f_i
  final bool isOledDark;
  final void Function(int row, int col)? onCellTap;

  const CasioStatTableView({
    super.key,
    required this.rows,
    required this.activeRow,
    required this.activeCol,
    this.isOledDark = false,
    this.onCellTap,
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
                      'fᵢ (Freq)',
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
              itemCount: widget.rows.length,
              itemBuilder: (context, index) {
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
                          placeholder: row.xi.trim().isNotEmpty ? '1' : '',
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

  Widget _buildCell({
    required Key key,
    required String value,
    required String placeholder,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final activeBg = widget.isOledDark
        ? const Color(0xFF172554)
        : const Color(0xFF141A17);
    final activeText = widget.isOledDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFFFFFBEB);
    final idleBg = widget.isOledDark
        ? const Color(0xFF111615)
        : const Color(0xFFD5DFD8);
    final idleText = widget.isOledDark
        ? const Color(0xFFE8F3EE)
        : const Color(0xFF0F172A);
    final hintText = widget.isOledDark
        ? const Color(0xFF64748B)
        : const Color(0xFF64748B);
    final activeBorder = widget.isOledDark
        ? const Color(0xFF2E86DE)
        : const Color(0xFFE5A93C);

    final bool hasValue = value.isNotEmpty;
    final String display = hasValue ? value : placeholder;

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: isActive ? activeBg : idleBg,
          border: isActive ? Border.all(color: activeBorder, width: 1.8) : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            display,
            style: TextStyle(
              color: hasValue
                  ? (isActive ? activeText : idleText)
                  : (isActive ? activeText.withValues(alpha: 0.7) : hintText),
              fontSize: 14,
              fontWeight: hasValue ? FontWeight.bold : FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}
