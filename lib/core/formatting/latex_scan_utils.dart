// Utilidades de escaneo de LaTeX compartidas por el divisor de lineas y el medidor visual.

bool latexIsLetter(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 65 && u <= 90) || (u >= 97 && u <= 122);
}

int latexSkipDelim(String s, int i) {
  if (i >= s.length) return i;
  if (s[i] != r'\') return i + 1;
  if (i + 1 >= s.length) return s.length;
  if (!latexIsLetter(s[i + 1])) return i + 2;
  var j = i + 1;
  while (j < s.length && latexIsLetter(s[j])) {
    j++;
  }
  return j;
}

int latexSkipGroup(String s, int i) {
  if (i >= s.length || s[i] != '{') return i;
  var depth = 0;
  for (var j = i; j < s.length; j++) {
    if (s[j] == '{') depth++;
    if (s[j] == '}') {
      depth--;
      if (depth == 0) return j + 1;
    }
  }
  return s.length;
}
