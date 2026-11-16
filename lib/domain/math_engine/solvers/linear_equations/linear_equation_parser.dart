import '../linear_equation_solver.dart';

class LinearEquationParser {
  static String normalizeEquationInput(String raw) {
    var s = raw
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('\u2212', '-')
        .replaceAll(r'\cdot', '*')
        .replaceAll('·', '*')
        .replaceAll('×', '*')
        .replaceAll(r'\left(', '(')
        .replaceAll(r'\right)', ')')
        .replaceAll('X', 'x');
    return replaceLatexFractions(s);
  }

  static String replaceLatexFractions(String input) {
    var s = input;
    while (true) {
      final idx = s.indexOf(r'\frac{');
      if (idx == -1) break;
      final numEnd = findMatchingBrace(s, idx + 5);
      if (numEnd == -1 || numEnd + 1 >= s.length || s[numEnd + 1] != '{') {
        break;
      }
      final denEnd = findMatchingBrace(s, numEnd + 1);
      if (denEnd == -1) break;
      final numContent = s.substring(idx + 6, numEnd);
      final denContent = s.substring(numEnd + 2, denEnd);
      s = '${s.substring(0, idx)}($numContent)/($denContent)${s.substring(denEnd + 1)}';
    }
    return s;
  }

  static int findMatchingBrace(String s, int openIdx) {
    int depth = 0;
    for (int i = openIdx; i < s.length; i++) {
      if (s[i] == '{') depth++;
      if (s[i] == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  static void checkBalancedParens(String s) {
    int depth = 0;
    for (int i = 0; i < s.length; i++) {
      if (s[i] == '(') depth++;
      if (s[i] == ')') depth--;
      if (depth < 0) {
        throw const FormatException('Paréntesis desbalanceados en la ecuación');
      }
    }
    if (depth != 0) {
      throw const FormatException('Falta cerrar un paréntesis en la ecuación');
    }
  }

  static List<({bool isSubtract, String body})> splitTopLevelAdditive(
    String s,
  ) {
    final result = <({bool isSubtract, String body})>[];
    if (s.isEmpty) return result;

    int depth = 0;
    int start = 0;
    bool isSub = false;
    int scanStart = 0;
    if (s[0] == '+' || s[0] == '-') {
      isSub = s[0] == '-';
      start = 1;
      scanStart = 1;
    }

    for (int i = scanStart; i < s.length; i++) {
      final ch = s[i];
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
      } else if (depth == 0 &&
          (ch == '+' || ch == '-') &&
          i > start &&
          s[i - 1] != '*' &&
          s[i - 1] != '/') {
        final body = s.substring(start, i);
        if (body.isEmpty) {
          throw const FormatException('Operador consecutivo inválido');
        }
        result.add((isSubtract: isSub, body: body));
        isSub = ch == '-';
        start = i + 1;
      }
    }

    final tail = s.substring(start);
    if (tail.isEmpty) {
      throw const FormatException('Falta término tras signo en la ecuación');
    }
    result.add((isSubtract: isSub, body: tail));
    return result;
  }

  static List<LinearTerm> parseLinearTerms(String sideStr) {
    final List<LinearTerm> terms = [];
    if (sideStr.isEmpty) return terms;

    for (final (:isSubtract, :body) in splitTopLevelAdditive(sideStr)) {
      int depth = 0;
      int slashIndex = -1;
      for (int i = 0; i < body.length; i++) {
        if (body[i] == '(') {
          depth++;
        } else if (body[i] == ')') {
          depth--;
        } else if (depth == 0 && body[i] == '/') {
          if (slashIndex != -1) {
            throw FormatException('División múltiple no soportada: $body');
          }
          slashIndex = i;
        }
      }

      int denominator = 1;
      String numeratorStr = body;
      if (slashIndex != -1) {
        numeratorStr = body.substring(0, slashIndex);
        final rawDen = unwrapOuterParens(body.substring(slashIndex + 1));
        final parsedDen = int.tryParse(rawDen);
        if (parsedDen == null || parsedDen <= 0) {
          throw FormatException(
            'El denominador debe ser un entero positivo: $rawDen',
          );
        }
        denominator = parsedDen;
      }

      final parsed = parseLinearExpr(numeratorStr);
      terms.add(
        LinearTerm(
          xCoeff: parsed.xCoeff,
          constant: parsed.constant,
          denominator: denominator,
          isSubtract: isSubtract,
        ),
      );
    }

    return terms;
  }

  static String unwrapOuterParens(String s) {
    var cur = s;
    while (cur.length >= 2 && cur.startsWith('(') && cur.endsWith(')')) {
      int depth = 0;
      bool enclosesWhole = true;
      for (int i = 0; i < cur.length; i++) {
        if (cur[i] == '(') depth++;
        if (cur[i] == ')') depth--;
        if (depth == 0 && i < cur.length - 1) {
          enclosesWhole = false;
          break;
        }
      }
      if (!enclosesWhole) break;
      cur = cur.substring(1, cur.length - 1);
    }
    return cur;
  }

  static ({int xCoeff, int constant}) parseLinearExpr(String expr) {
    final unwrapped = unwrapOuterParens(expr);
    if (unwrapped.isEmpty) {
      throw const FormatException('Expresión vacía');
    }

    final addTerms = splitTopLevelAdditive(unwrapped);
    if (addTerms.length > 1 || addTerms.first.isSubtract) {
      int totalX = 0;
      int totalConst = 0;
      for (final (:isSubtract, :body) in addTerms) {
        final sub = parseLinearProduct(body);
        final sign = isSubtract ? -1 : 1;
        totalX += sign * sub.xCoeff;
        totalConst += sign * sub.constant;
      }
      return (xCoeff: totalX, constant: totalConst);
    }

    return parseLinearProduct(addTerms.first.body);
  }

  static ({int xCoeff, int constant}) parseLinearProduct(String term) {
    final withImplicit = term
        .replaceAllMapped(RegExp(r'(\d)\('), (m) => '${m[1]}*(')
        .replaceAll(')(', ')*(')
        .replaceAllMapped(RegExp(r'\)(\d|[xX])'), (m) => ')*${m[1]}');

    final factors = <String>[];
    int depth = 0;
    int start = 0;
    for (int i = 0; i < withImplicit.length; i++) {
      final ch = withImplicit[i];
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
      } else if (depth == 0 && ch == '*') {
        final part = withImplicit.substring(start, i);
        if (part.isEmpty) {
          throw FormatException('Producto inválido en: $term');
        }
        factors.add(part);
        start = i + 1;
      }
    }
    final last = withImplicit.substring(start);
    if (last.isEmpty) {
      throw FormatException('Producto incompleto en: $term');
    }
    factors.add(last);

    var acc = (xCoeff: 0, constant: 1);
    for (final factor in factors) {
      final parsed = factor.startsWith('(')
          ? parseLinearExpr(factor)
          : parseSingleMonomial(factor);
      if (acc.xCoeff != 0 && parsed.xCoeff != 0) {
        throw const FormatException(
          'No es una ecuación de 1.º grado (contiene producto de x)',
        );
      }
      final nextX = acc.xCoeff * parsed.constant + acc.constant * parsed.xCoeff;
      final nextConst = acc.constant * parsed.constant;
      acc = (xCoeff: nextX, constant: nextConst);
    }
    return acc;
  }

  static ({int xCoeff, int constant}) parseSingleMonomial(String token) {
    if (token == 'x') {
      return (xCoeff: 1, constant: 0);
    }
    if (token == '-x') {
      return (xCoeff: -1, constant: 0);
    }
    final xMatch = RegExp(r'^(-?\d+)x$').firstMatch(token);
    if (xMatch != null) {
      return (xCoeff: int.parse(xMatch.group(1)!), constant: 0);
    }
    final numVal = int.tryParse(token);
    if (numVal != null) {
      return (xCoeff: 0, constant: numVal);
    }
    throw FormatException('Término no reconocido en ecuación lineal: $token');
  }
}
