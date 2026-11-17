import 'package:flutter/material.dart';

import 'lcd_palette.dart';

/// Elemento de un menu de lista de la LCD (OPTN, CONST, CONV).
class LcdListItem {
  final String id;
  final String label;
  final String? detail;

  const LcdListItem(this.id, this.label, {this.detail});
}

/// Menu de lista paginado (4 por pagina) dentro de la LCD ClassWiz.
///
/// Las teclas `1-4` eligen dentro de la pagina visible; `▲▼` mueven el cursor,
/// `◀▶` cambian de pagina, `=` confirma y `AC` cierra o sube de nivel.
class LcdListMenu extends StatelessWidget {
  static const int perPage = 4;

  final LcdTheme theme;
  final String title;
  final List<LcdListItem> items;
  final int cursor;
  final ValueChanged<int>? onTapItem;

  const LcdListMenu({
    super.key,
    required this.theme,
    required this.title,
    required this.items,
    required this.cursor,
    this.onTapItem,
  });

  static const Color _active = Color(0xFF1A2530);
  static const Color _border = Color(0xFF7A8A7E);

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final bool dark = theme == LcdTheme.night;
    final Color idleBg = dark ? const Color(0xFF1A2421) : const Color(0xFFBDCEBE);
    final int pages = (items.length + perPage - 1) ~/ perPage;
    final int page = cursor ~/ perPage;
    final int start = page * perPage;
    final int end = (start + perPage).clamp(0, items.length);

    return Container(
      key: const Key('lcd_list_menu'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: pal.background,
        borderRadius: BorderRadius.circular(8.5),
        border: Border.all(color: _border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  key: const Key('list_title'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: pal.formula, fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${page + 1}/$pages',
                key: const Key('list_page'),
                style: TextStyle(color: pal.title, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Column(
              children: [
                for (int i = start; i < end; i++)
                  Expanded(
                    child: GestureDetector(
                      key: Key('list_item_$i'),
                      onTap: () => onTapItem?.call(i),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: cursor == i ? _active : idleBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: cursor == i ? _active : _border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${i - start + 1}: ${items[i].label}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cursor == i ? Colors.white : pal.formula,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (items[i].detail != null)
                              Text(
                                items[i].detail!,
                                maxLines: 1,
                                style: TextStyle(
                                  color: cursor == i ? Colors.white : pal.title,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '1-4 elegir · ▲▼ mover · ◀▶ página · = · AC',
            style: TextStyle(color: pal.title, fontSize: 9, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
