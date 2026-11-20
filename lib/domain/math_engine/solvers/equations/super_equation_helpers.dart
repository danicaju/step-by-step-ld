/// Expresión lineal auxiliar de la forma m·x + n
class LinearExpression {
  final double m;
  final double n;
  const LinearExpression(this.m, this.n);

  static LinearExpression parse(String s, {String varName = 'x'}) {
    var str = s.replaceAll(' ', '');
    // Insertar espacios delante de los signos para separar tokens
    var formatted = '';
    for (int i = 0; i < str.length; i++) {
      final ch = str[i];
      if ((ch == '+' || ch == '-') && i > 0 && str[i - 1] != '(' && str[i - 1] != '^') {
        formatted += ' $ch';
      } else {
        formatted += ch;
      }
    }

    final tokens = formatted.split(' ').where((t) => t.isNotEmpty).toList();
    double slope = 0;
    double intercept = 0;

    for (final tok in tokens) {
      final cleanTok = tok.replaceAll('(', '').replaceAll(')', '');
      if (cleanTok.contains(varName)) {
        var coeff = cleanTok.replaceAll(varName, '');
        if (coeff.isEmpty || coeff == '+') {
          slope += 1.0;
        } else if (coeff == '-') {
          slope -= 1.0;
        } else {
          slope += double.tryParse(coeff) ?? 1.0;
        }
      } else {
        intercept += double.tryParse(cleanTok) ?? 0.0;
      }
    }
    return LinearExpression(slope, intercept);
  }
}

class SuperEquationHelpers {
  static String preClean(String raw) {
    return raw
        .replaceAll('\r', '')
        .replaceAll(' ', '')
        .replaceAll('·', '*')
        .replaceAll('×', '*')
        .replaceAll(r'\cdot', '*')
        .replaceAll(r'\times', '*')
        .replaceAll('²', '^2')
        .replaceAll(RegExp('³(?!√)'), '^3')
        // `x^(4)` (plantilla de exponente del editor) -> `x^4` para reconocer las bicuadradas.
        .replaceAllMapped(RegExp(r'\^\((\d+)\)'), (m) => '^${m[1]}')
        .replaceAll('X', 'x');
  }

  static double evalSolutionVal(String s) {
    final clean = s.replaceAll(r'\sqrt', '').replaceAll('{', '').replaceAll('}', '');
    return double.tryParse(clean) ?? 0.0;
  }

  static Map<int, double> parseCoeffs2(String expr, String varName) {
    double a = 0, b = 0, c = 0;
    var str = expr.replaceAll(' ', '');
    var formatted = '';
    for (int i = 0; i < str.length; i++) {
      final ch = str[i];
      if ((ch == '+' || ch == '-') && i > 0 && str[i - 1] != '(' && str[i - 1] != '^') {
        formatted += ' $ch';
      } else {
        formatted += ch;
      }
    }
    final tokens = formatted.split(' ').where((t) => t.isNotEmpty).toList();

    for (final tok in tokens) {
      if (tok.contains('$varName^2') || tok.contains('$varName^{2}') || tok.contains('$varName²')) {
        final coeffStr = tok
            .replaceAll('$varName^2', '')
            .replaceAll('$varName^{2}', '')
            .replaceAll('$varName²', '');
        a += parseCoeff(coeffStr);
      } else if (tok.contains(varName)) {
        final coeffStr = tok.replaceAll(varName, '');
        b += parseCoeff(coeffStr);
      } else {
        c += double.tryParse(tok) ?? 0.0;
      }
    }
    return {2: a, 1: b, 0: c};
  }

  static double parseCoeff(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s == '+') return 1.0;
    if (s == '-') return -1.0;
    return double.tryParse(s) ?? 1.0;
  }
}
