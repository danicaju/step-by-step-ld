/// Salto inteligente de linea para LaTeX largo (resultados, primitivas, sumas de terminos).
///
/// Solo parte en operadores de nivel superior (`=`, `\approx`, `+`, `-` binarios a
/// profundidad 0): nunca dentro de `(...)`, `[...]`, `{...}`, `\left...\right`,
/// `\frac`, `\sqrt`, `|...|` ni `\begin{...}...\end{...}`. El operador queda al
/// principio de la linea nueva (estilo libro de texto) y cada linea devuelta esta
/// balanceada; si algo no cuadra se devuelve la formula original intacta.
library;

import 'latex_scan_utils.dart';
import 'latex_visual_length.dart';

export 'latex_visual_length.dart' show visualLength;

const Set<String> _opCommands = {
  'cdot', 'times', 'div', 'pm', 'mp', 'approx', 'Rightarrow', 'Leftrightarrow', 'to', 'le',
  'ge', 'leq', 'geq', 'neq', 'ne', 'in', 'int', 'sum', 'prod', 'lim', 'rightarrow', 'mapsto',
  'ast', 'circ', 'cup', 'cap', 'wedge', 'vee', 'lt', 'gt', 'sim', 'equiv', 'oint',
};

const Set<String> _transparent = {'quad', 'qquad', 'displaystyle', 'textstyle'};

class _Analysis {
  final bool balanced;
  final bool rowBreak;
  final List<int> cuts;
  const _Analysis(this.balanced, this.rowBreak, this.cuts);
}

_Analysis _analyze(String s) {
  var depth = 0;
  var abs = false;
  var bad = false;
  var rowBreak = false;
  var prevOperand = false;
  final cuts = <int>[];
  bool canCut(int at) => depth == 0 && !abs && s.substring(0, at).trim().isNotEmpty;
  var i = 0;
  while (i < s.length && !bad) {
    final c = s[i];
    if (c == r'\') {
      if (i + 1 >= s.length) {
        bad = true;
        break;
      }
      final n = s[i + 1];
      if (!latexIsLetter(n)) {
        if (n == r'\') {
          if (depth == 0 && !abs) rowBreak = true;
          prevOperand = false;
        } else if (n == '{') {
          prevOperand = false;
        } else if (n == '}' || n == '|') {
          prevOperand = true;
        }
        i += 2;
        continue;
      }
      final start = i;
      var j = i + 1;
      while (j < s.length && latexIsLetter(s[j])) {
        j++;
      }
      final name = s.substring(i + 1, j);
      i = j;
      switch (name) {
        case 'left':
          depth++;
          i = latexSkipDelim(s, i);
          prevOperand = false;
        case 'right':
          depth--;
          i = latexSkipDelim(s, i);
          prevOperand = true;
        case 'begin':
          depth++;
          i = latexSkipGroup(s, i);
          prevOperand = false;
        case 'end':
          depth--;
          i = latexSkipGroup(s, i);
          prevOperand = true;
        case 'approx':
          if (canCut(start)) cuts.add(start);
          prevOperand = false;
        default:
          if (!_transparent.contains(name)) prevOperand = !_opCommands.contains(name);
      }
      if (depth < 0) bad = true;
      continue;
    }
    switch (c) {
      case '{' || '(' || '[':
        depth++;
        prevOperand = false;
      case '}' || ')' || ']':
        depth--;
        prevOperand = true;
        if (depth < 0) bad = true;
      case '|':
        abs = !abs;
        prevOperand = !abs;
      case '=':
        if (canCut(i)) cuts.add(i);
        prevOperand = false;
      case '+' || '-':
        if (prevOperand && canCut(i)) cuts.add(i);
        prevOperand = false;
      case '^' || '_' || ',' || '&':
        prevOperand = false;
      case ' ' || '\n' || '\t':
        break;
      default:
        prevOperand = true;
    }
    i++;
  }
  return _Analysis(!bad && depth == 0 && !abs, rowBreak, cuts);
}

/// `true` si [latex] tiene llaves, parentesis, `\left/\right` y `\begin/\end` balanceados.
bool isLatexBalanced(String latex) => _analyze(latex).balanced;
/// Parte [latex] en lineas de a lo sumo ~[maxVisualCharsPerLine] caracteres visuales,
/// solo en operadores de nivel superior. Una formula corta se devuelve intacta.
List<String> splitLongLatex(String latex, {required int maxVisualCharsPerLine}) {
  final s = latex.trim();
  if (s.isEmpty || visualLength(s) <= maxVisualCharsPerLine) return [latex];
  final a = _analyze(s);
  if (!a.balanced || a.rowBreak || a.cuts.isEmpty) return [latex];
  final bounds = [0, ...a.cuts, s.length];
  final lines = <String>[];
  var cur = '';
  var curW = 0.0;
  for (var k = 0; k < bounds.length - 1; k++) {
    final seg = s.substring(bounds[k], bounds[k + 1]);
    final w = visualLength(seg);
    if (cur.isNotEmpty && curW + w > maxVisualCharsPerLine) {
      lines.add(cur.trim());
      cur = seg;
      curW = w;
    } else {
      cur += seg;
      curW += w;
    }
  }
  if (cur.trim().isNotEmpty) lines.add(cur.trim());
  if (lines.length < 2 || lines.any((l) => !isLatexBalanced(l))) return [latex];
  return lines;
}

/// Filas de un `\begin{array}{l} ... \end{array}` simple (sin entornos anidados): cada fila se
/// puede escalar o partir por separado. `null` si no es ese formato.
List<String>? splitArrayRows(String latex) {
  final m = RegExp(r'^\\begin\{array\}\{[lcr]+\}\s*([\s\S]*?)\s*\\end\{array\}$').firstMatch(latex.trim());
  if (m == null) return null;
  final inner = m.group(1)!;
  if (inner.contains(r'\begin')) return null;
  final rows = [
    for (final r in inner.split(RegExp(r'\s*\\\\\s*')))
      if (r.trim().isNotEmpty) r.trim(),
  ];
  if (rows.length < 2 || rows.any((r) => !isLatexBalanced(r))) return null;
  return rows;
}

/// Si [stepLatex] empieza repitiendo el enunciado ([originalLatex]) seguido de `=`,
/// devuelve solo `= ...` (la LCD ya muestra el enunciado arriba). Si no, lo deja igual.
String stripLeadingStatement(String stepLatex, String originalLatex) {
  final o = originalLatex.trim();
  final s = stepLatex.trim();
  // Bloque de filas cuya primera fila ya es el enunciado: se omite esa fila.
  final rows = splitArrayRows(s);
  if (o.length >= 3 && rows != null && rows.first == o) {
    final rest = rows.sublist(1);
    return rest.length == 1 ? rest.first : '\\begin{array}{l} ${rest.join(' \\\\ ')} \\end{array}';
  }
  if (o.length < 3 || !s.startsWith(o)) return stepLatex;
  final rest = s.substring(o.length).trimLeft();
  if (rest.startsWith('=') && !rest.startsWith('==')) return rest;
  return stepLatex;
}
