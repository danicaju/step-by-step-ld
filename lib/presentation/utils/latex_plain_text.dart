/// Convierte fragmentos LaTeX incrustados en notas pedagógicas (que se pintan
/// con `Text` nativo) a texto plano legible: `\frac{1}{2}` -> `1/2`,
/// `\sqrt{14}` -> `√(14)`, `\cdot` -> `·`, matrices `array` -> `[a b; c d]`.
class LatexPlainText {
  LatexPlainText._();

  static final RegExp _frac = RegExp(r'\\d?frac\{([^{}]*)\}\{([^{}]*)\}');
  static final RegExp _sqrtN = RegExp(r'\\sqrt\[([^\]]*)\]\{([^{}]*)\}');
  static final RegExp _sqrt = RegExp(r'\\sqrt\{([^{}]*)\}');
  static final RegExp _array =
      RegExp(r'\\begin\{array\}\{[^}]*\}(.*?)\\end\{array\}', dotAll: true);
  static final RegExp _wrapper = RegExp(r'\\(?:text|mathrm|textbf|mathbf|boxed)\{([^{}]*)\}');
  static final RegExp _color = RegExp(r'\\textcolor\{[^{}]*\}\{([^{}]*)\}');
  static final RegExp _simple = RegExp(r'^[\w.,\-]+$');

  static const Map<String, String> _symbols = {
    r'\cdot': '·',
    r'\times': '×',
    r'\pm': '±',
    r'\leq': '≤',
    r'\le': '≤',
    r'\geq': '≥',
    r'\ge': '≥',
    r'\neq': '≠',
    r'\approx': '≈',
    r'\infty': '∞',
    r'\implies': '⇒',
    r'\Rightarrow': '⇒',
    r'\pi': 'π',
    r'\alpha': 'α',
    r'\Delta': 'Δ',
    r'\sigma': 'σ',
    r'\circ': '°',
    r'\left': '',
    r'\right': '',
    r'\,': ' ',
    r'\;': ' ',
    r'\!': '',
    r'\ ': ' ',
  };

  static String _group(String s) => _simple.hasMatch(s) ? s : '($s)';

  static String toPlain(String input) {
    if (!input.contains(r'\') && !input.contains('{')) return input;
    var s = input.replaceAll('\r', '');
    s = s.replaceAllMapped(_array, (m) {
      final rows = m.group(1)!.split(r'\\').map((r) => r.trim()).where((r) => r.isNotEmpty);
      final cells = rows.map((r) => r.split('&').map((c) => c.trim()).join(' '));
      return '[${cells.join('; ')}]';
    });
    s = s.replaceAllMapped(_color, (m) => m.group(1)!);
    for (var i = 0; i < 6; i++) {
      final before = s;
      s = s.replaceAllMapped(_wrapper, (m) => m.group(1)!);
      s = s.replaceAllMapped(_sqrtN, (m) => '${m.group(1)}√(${m.group(2)})');
      s = s.replaceAllMapped(_sqrt, (m) => '√(${m.group(1)})');
      s = s.replaceAllMapped(_frac, (m) => '${_group(m.group(1)!)}/${_group(m.group(2)!)}');
      if (s == before) break;
    }
    final keys = _symbols.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      s = s.replaceAll(k, _symbols[k]!);
    }
    s = s.replaceAll('{,}', ',').replaceAll('{', '').replaceAll('}', '');
    return s.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
  }
}
