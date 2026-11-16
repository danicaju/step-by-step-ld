import 'package:flutter/material.dart';
import 'lcd_status_bar.dart';

class ClassWizMenuItem {
  final int modeId;
  final String number;
  final String shortTitle;
  final String fullTitle;
  final IconData icon;

  const ClassWizMenuItem({
    required this.modeId,
    required this.number,
    required this.shortTitle,
    required this.fullTitle,
    required this.icon,
  });
}

const List<ClassWizMenuItem> classWizMenuItems = [
  // Página 1
  ClassWizMenuItem(
    modeId: 1,
    number: '1',
    shortTitle: 'Calcular',
    fullTitle: '1:Calcular',
    icon: Icons.calculate_outlined,
  ),
  ClassWizMenuItem(
    modeId: 2,
    number: '2',
    shortTitle: 'Ecuaciones',
    fullTitle: '2:Ecuaciones (1.º y 2.º Grado)',
    icon: Icons.functions_rounded,
  ),
  ClassWizMenuItem(
    modeId: 3,
    number: '3',
    shortTitle: 'Sistemas',
    fullTitle: '3:Sistemas (2x2 / 3x3)',
    icon: Icons.table_rows_rounded,
  ),
  ClassWizMenuItem(
    modeId: 4,
    number: '4',
    shortTitle: 'Polinomios / Ruffini',
    fullTitle: '4:Polinomios / Ruffini',
    icon: Icons.grid_4x4_rounded,
  ),
  // Página 2
  ClassWizMenuItem(
    modeId: 5,
    number: '5',
    shortTitle: 'Gráficas',
    fullTitle: '5:Estudio de Funciones',
    icon: Icons.show_chart_rounded,
  ),
  ClassWizMenuItem(
    modeId: 6,
    number: '6',
    shortTitle: 'Inecuaciones',
    fullTitle: '6:Inecuaciones (<, ≤, >, ≥)',
    icon: Icons.compare_arrows_rounded,
  ),
  ClassWizMenuItem(
    modeId: 7,
    number: '7',
    shortTitle: 'Sistemas Inec.',
    fullTitle: '7:Sistemas de Inecuaciones (1D / 2D)',
    icon: Icons.alt_route_rounded,
  ),
  ClassWizMenuItem(
    modeId: 8,
    number: '8',
    shortTitle: 'Estadística',
    fullTitle: '8:Estadística 1 Variable',
    icon: Icons.bar_chart_rounded,
  ),
  // Página 3
  ClassWizMenuItem(
    modeId: 9,
    number: '9',
    shortTitle: 'Matrices',
    fullTitle: '9:Matrices y Sistemas',
    icon: Icons.grid_on_rounded,
  ),
  ClassWizMenuItem(
    modeId: 10,
    number: '10',
    shortTitle: 'Vectores 3D',
    fullTitle: '10:Vectores 2D / 3D',
    icon: Icons.north_east_rounded,
  ),
  ClassWizMenuItem(
    modeId: 11,
    number: '11',
    shortTitle: 'Complejos',
    fullTitle: '11:Complejos (a+bi ⬄ r_α)',
    icon: Icons.all_inclusive_rounded,
  ),
  ClassWizMenuItem(
    modeId: 12,
    number: '12',
    shortTitle: 'Derivadas e Integrales',
    fullTitle: '12:Derivadas e Integrales',
    icon: Icons.calculate_rounded,
  ),
];


class LcdModeMenu extends StatelessWidget {
  final int menuCursorIndex;
  final ValueChanged<int>? onMenuCursorChanged;
  final ValueChanged<int>? onSelectMenuMode;
  final bool isShiftActive;
  final bool isAlphaActive;
  final bool isMemoryActive;
  final bool isOledDark;
  final Color backgroundColor;
  final Color formulaColor;
  final Color stepTitleColor;

  static const int menuItemsPerPage = 4;
  static const int menuPageCount = 3;

  const LcdModeMenu({
    super.key,
    required this.menuCursorIndex,
    this.onMenuCursorChanged,
    this.onSelectMenuMode,
    this.isShiftActive = false,
    this.isAlphaActive = false,
    this.isMemoryActive = false,
    this.isOledDark = false,
    required this.backgroundColor,
    required this.formulaColor,
    required this.stepTitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final safeCursor = menuCursorIndex.clamp(0, classWizMenuItems.length - 1);
    final selectedItem = classWizMenuItems[safeCursor];
    final int currentPage = safeCursor ~/ menuItemsPerPage;
    final int totalPages = menuPageCount;
    final int pageStart = currentPage * menuItemsPerPage;

    void goToPage(int delta) {
      final nextPage = (currentPage + delta + totalPages) % totalPages;
      onMenuCursorChanged?.call(nextPage * menuItemsPerPage);
    }

    return LayoutBuilder(
      builder: (context, menuConstraints) {
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra de estado superior del menú con paginador PÁGINA X/3 ◀ ▶
            Row(
              children: [
                StatusBadge(
                  label: 'S',
                  active: isShiftActive,
                  activeColor: const Color(0xFFD99B26),
                  isOledDark: isOledDark,
                ),
                const SizedBox(width: 4),
                StatusBadge(
                  label: 'A',
                  active: isAlphaActive,
                  activeColor: const Color(0xFFD64545),
                  isOledDark: isOledDark,
                ),
                const SizedBox(width: 4),
                StatusBadge(
                  label: 'M',
                  active: isMemoryActive,
                  activeColor: const Color(0xFF10B981),
                  isOledDark: isOledDark,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isOledDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'MENU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  key: const Key('menu_page_prev'),
                  onTap: () => goToPage(-1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      '◀',
                      style: TextStyle(
                        color: formulaColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Text(
                  'PÁGINA ${currentPage + 1}/$totalPages',
                  key: const Key('menu_page_indicator'),
                  style: TextStyle(
                    color: formulaColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  key: const Key('menu_page_next'),
                  onTap: () => goToPage(1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      '▶',
                      style: TextStyle(
                        color: formulaColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Cuadrícula 2×2 espaciosa y legible (4 módulos por página)
            Expanded(
              child: Column(
                children: [
                  for (int row = 0; row < 2; row++) ...[
                    if (row > 0) const SizedBox(height: 6),
                    Expanded(
                      child: Row(
                        children: [
                          for (int col = 0; col < 2; col++) ...[
                            if (col > 0) const SizedBox(width: 6),
                            Expanded(
                              child: (pageStart + row * 2 + col) < classWizMenuItems.length
                                  ? _buildMenuTile(pageStart + row * 2 + col, formulaColor)
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Barra inferior con el nombre del modo seleccionado y ayuda de navegación
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isOledDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5CE),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isOledDark ? const Color(0xFF334155) : const Color(0xFF94A39B),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        selectedItem.fullTitle,
                        style: TextStyle(
                          color: formulaColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '[◄►] o [1-12, =]',
                    style: TextStyle(
                      color: formulaColor.withValues(alpha: 0.72),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        if (menuConstraints.maxHeight < 140) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: menuConstraints.maxWidth,
              height: 140,
              child: content,
            ),
          );
        }
        return content;
      },
    );
  }

  Widget _buildMenuTile(int index, Color formulaColor) {
    final item = classWizMenuItems[index];
    final bool isSelected = index == menuCursorIndex;
    final Color fg = isSelected
        ? (isOledDark ? Colors.black : Colors.white)
        : formulaColor;

    return InkWell(
      key: Key('menu_mode_${item.modeId}'),
      onTap: () => onSelectMenuMode?.call(item.modeId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isOledDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A))
              : (isOledDark
                  ? const Color(0xFF1A2220)
                  : const Color(0xFFCBD5CE).withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? (isOledDark ? Colors.white : const Color(0xFF0F172A))
                : (isOledDark ? const Color(0xFF27322E) : const Color(0xFF94A39B)),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.number,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: fg,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      item.icon,
                      size: 24,
                      color: fg,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.shortTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}