import 'dart:math' as math;
import '../../core/rational.dart';
import '../../core/algebraic_latex_formatter.dart';
import '../../models/inequality_models.dart';
import '../linear_equation_solver.dart';
import 'inequality_sign.dart';

class QuadRoot {
  final String latex;
  final double approx;
  const QuadRoot({required this.latex, required this.approx});
}

class InequalityParsingHelper {
  static ({String lhs, String rhs, InequalitySign sign}) splitByInequalitySign(
    String cleaned, {
    InequalitySign? fallbackSign,
  }) {
    const patterns = [
      '<=',
      '>=',
      '≤',
      '≥',
      r'\leq',
      r'\geq',
      r'\le',
      r'\ge',
      '<',
      '>',
    ];
    for (final pat in patterns) {
      final idx = cleaned.indexOf(pat);
      if (idx != -1) {
        final sign = InequalitySign.tryParse(pat)!;
        final lhs = cleaned.substring(0, idx);
        final rhs = cleaned.substring(idx + pat.length);
        if (lhs.isEmpty) {
          throw const FormatException('Falta el primer miembro de la inecuación.');
        }
        return (
          lhs: lhs,
          rhs: rhs.isEmpty ? '0' : rhs,
          sign: sign,
        );
      }
    }
    if (fallbackSign != null) {
      return (lhs: cleaned, rhs: '0', sign: fallbackSign);
    }
    throw const FormatException('Falta el signo de desigualdad (<, ≤, > o ≥).');
  }

  static List<LinearTerm> parseLinearSide(String raw) {
    final s = replaceLatexFractions(raw);
    if (s.isEmpty) return const [];
    final terms = <LinearTerm>[];

    for (final (:isSubtract, :body) in splitTopLevelAdditive(s)) {
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

      int den = 1;
      String numStr = body;
      if (slashIndex != -1) {
        numStr = body.substring(0, slashIndex);
        final rawDen = unwrapOuterParens(body.substring(slashIndex + 1));
        final parsedDen = int.tryParse(rawDen);
        if (parsedDen == null || parsedDen <= 0) {
          throw FormatException('El denominador debe ser entero positivo: $rawDen');
        }
        den = parsedDen;
      }

      final parsed = parseLinearExpr(numStr);
      terms.add(
        LinearTerm(
          xCoeff: parsed.xCoeff,
          constant: parsed.constant,
          denominator: den,
          isSubtract: isSubtract,
        ),
      );
    }
    return terms;
  }

  static ({int a, int b, int c}) parseQuadraticSide(String raw) {
    final normalized = raw.replaceAll('*x', 'x');
    final unwrapped = unwrapOuterParens(normalized);
    if (unwrapped.isEmpty || unwrapped == '0') {
      return (a: 0, b: 0, c: 0);
    }
    int a = 0;
    int b = 0;
    int c = 0;
    for (final (:isSubtract, :body) in splitTopLevelAdditive(unwrapped)) {
      final sign = isSubtract ? -1 : 1;
      if (body == 'x^2') {
        a += sign;
      } else if (RegExp(r'^(-?\d+)x\^2$').hasMatch(body)) {
        a += sign * int.parse(body.substring(0, body.length - 3));
      } else if (body == 'x') {
        b += sign;
      } else if (RegExp(r'^(-?\d+)x$').hasMatch(body)) {
        b += sign * int.parse(body.substring(0, body.length - 1));
      } else {
        final numVal = int.tryParse(body);
        if (numVal == null) {
          throw FormatException('Término no reconocido en inecuación de 2.º grado: $body');
        }
        c += sign * numVal;
      }
    }
    return (a: a, b: b, c: c);
  }

  static String formatSideFromRawPolyOrFallback(String raw) {
    try {
      final p = parseQuadraticSide(raw);
      return AlgebraicLatexFormatter.quadraticExpression(p.a, p.b, p.c);
    } catch (_) {
      return raw;
    }
  }

  static ({int xCoeff, int constant}) parseLinearExpr(String expr) {
    final unwrapped = unwrapOuterParens(expr);
    if (unwrapped.isEmpty) {
      throw const FormatException('Expresión vacía en inecuación.');
    }
    final addTerms = splitTopLevelAdditive(unwrapped);
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

  static ({int xCoeff, int constant}) parseLinearProduct(String term) {
    final withImplicit = term
        .replaceAllMapped(RegExp(r'(\d)\('), (m) => '${m[1]}*(')
        .replaceAll(')(', ')*(')
        .replaceAllMapped(RegExp(r'\)(\d|x)'), (m) => ')*${m[1]}');

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
        if (part.isEmpty) throw FormatException('Producto inválido: $term');
        factors.add(part);
        start = i + 1;
      }
    }
    final tail = withImplicit.substring(start);
    if (tail.isEmpty) throw FormatException('Producto incompleto: $term');
    factors.add(tail);

    var acc = (xCoeff: 0, constant: 1);
    for (final f in factors) {
      final parsed = f.startsWith('(')
          ? parseLinearExpr(f)
          : parseSingleMonomial(f);
      if (acc.xCoeff != 0 && parsed.xCoeff != 0) {
        throw const FormatException('Producto de x detectado fuera de modo 2.º grado.');
      }
      acc = (
        xCoeff: acc.xCoeff * parsed.constant + acc.constant * parsed.xCoeff,
        constant: acc.constant * parsed.constant,
      );
    }
    return acc;
  }

  static ({int xCoeff, int constant}) parseSingleMonomial(String token) {
    if (token == 'x') return (xCoeff: 1, constant: 0);
    if (token == '-x') return (xCoeff: -1, constant: 0);
    final xMatch = RegExp(r'^(-?\d+)x$').firstMatch(token);
    if (xMatch != null) {
      return (xCoeff: int.parse(xMatch.group(1)!), constant: 0);
    }
    final numVal = int.tryParse(token);
    if (numVal != null) {
      return (xCoeff: 0, constant: numVal);
    }
    throw FormatException('Término no reconocido en inecuación: $token');
  }

  static List<({bool isSubtract, String body})> splitTopLevelAdditive(String s) {
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
          throw const FormatException('Operador consecutivo inválido.');
        }
        result.add((isSubtract: isSub, body: body));
        isSub = ch == '-';
        start = i + 1;
      }
    }
    final tail = s.substring(start);
    if (tail.isEmpty) {
      throw const FormatException('Falta término tras signo.');
    }
    result.add((isSubtract: isSub, body: tail));
    return result;
  }

  static String replaceLatexFractions(String input) {
    var s = input;
    while (true) {
      final idx = s.indexOf(r'\frac{');
      if (idx == -1) break;
      final numEnd = findMatchingBrace(s, idx + 5);
      if (numEnd == -1 || numEnd + 1 >= s.length || s[numEnd + 1] != '{') break;
      final denEnd = findMatchingBrace(s, numEnd + 1);
      if (denEnd == -1) break;
      final n = s.substring(idx + 6, numEnd);
      final d = s.substring(numEnd + 2, denEnd);
      s = '${s.substring(0, idx)}($n)/($d)${s.substring(denEnd + 1)}';
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

  static String unwrapOuterParens(String s) {
    var cur = s;
    while (cur.length >= 2 && cur.startsWith('(') && cur.endsWith(')')) {
      int depth = 0;
      bool whole = true;
      for (int i = 0; i < cur.length; i++) {
        if (cur[i] == '(') depth++;
        if (cur[i] == ')') depth--;
        if (depth == 0 && i < cur.length - 1) {
          whole = false;
          break;
        }
      }
      if (!whole) break;
      cur = cur.substring(1, cur.length - 1);
    }
    return cur;
  }

  static String formatLinearSideLatex(List<LinearTerm> terms) {
    if (terms.isEmpty) return '0';
    final buffer = StringBuffer();
    for (int i = 0; i < terms.length; i++) {
      String part = terms[i].toLatex().trim();
      if (i == 0) {
        if (part.startsWith('+ ')) part = part.substring(2).trimLeft();
        buffer.write(part);
      } else {
        if (!part.startsWith('+') && !part.startsWith('-')) {
          buffer.write(' + $part');
        } else if (part.startsWith('-') && !part.startsWith('- ')) {
          buffer.write(' - ${part.substring(1)}');
        } else {
          buffer.write(' $part');
        }
      }
    }
    return buffer.toString();
  }

  static String formatHalfLineInterval({
    required String boundaryLatex,
    required InequalitySign sign,
  }) =>
      switch (sign) {
        InequalitySign.less => '(-\\infty, $boundaryLatex)',
        InequalitySign.lessOrEqual => '(-\\infty, $boundaryLatex]',
        InequalitySign.greater => '($boundaryLatex, +\\infty)',
        InequalitySign.greaterOrEqual => '[$boundaryLatex, +\\infty)',
      };

  static int gcd(int a, int b) {
    a = a.abs();
    b = b.abs();
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a == 0 ? 1 : a;
  }

  static int lcm(int a, int b) => (a.abs() ~/ gcd(a, b)) * b.abs();

  static Rational evalPolyAt(int a, int b, int c, Rational x) =>
      Rational(a) * x * x + Rational(b) * x + Rational(c);

  static Rational pickTestPoint({double? low, double? high}) {
    if (low == null && high == null) return Rational(0);
    if (low == null) {
      if (0 < high!) return Rational(0);
      return Rational(high.ceil() - 1);
    }
    if (high == null) {
      if (0 > low) return Rational(0);
      return Rational(low.floor() + 1);
    }
    if (low < 0 && 0 < high) return Rational(0);
    final intFirst = low.floor() + 1;
    if (intFirst < high) {
      final intLast = high.ceil() - 1;
      if (intLast >= intFirst) {
        int best = intFirst;
        for (int v = intFirst; v <= intLast; v++) {
          if (v.abs() < best.abs()) best = v;
        }
        return Rational(best);
      }
    }
    final midDouble = (low + high) / 2.0;
    for (final den in [2, 4, 8, 10]) {
      final candidateNum = (midDouble * den).round();
      final candidateVal = candidateNum / den;
      if (candidateVal > low && candidateVal < high) {
        return Rational.raw(candidateNum, den).simplify();
      }
    }
    return Rational.fromDecimalString(midDouble.toStringAsFixed(2));
  }

  static (QuadRoot, QuadRoot) computeOrderedQuadraticRoots(
    int a,
    int b,
    int discriminant,
  ) {
    final sqrtD = math.sqrt(discriminant);
    final sqrtInt = sqrtD.round();
    if (sqrtInt * sqrtInt == discriminant) {
      final q1 = Rational.raw(-b - sqrtInt, 2 * a).simplify();
      final q2 = Rational.raw(-b + sqrtInt, 2 * a).simplify();
      final list = [
        QuadRoot(latex: q1.toLatex(), approx: q1.toDouble()),
        QuadRoot(latex: q2.toLatex(), approx: q2.toDouble()),
      ]..sort((x, y) => x.approx.compareTo(y.approx));
      return (list[0], list[1]);
    }

    int outFactor = 1;
    int rad = discriminant;
    for (int f = math.sqrt(discriminant).toInt(); f >= 2; f--) {
      if (discriminant % (f * f) == 0) {
        outFactor = f;
        rad = discriminant ~/ (f * f);
        break;
      }
    }

    final int common = gcd(gcd(b.abs(), outFactor), (2 * a).abs());
    final int numB = -b ~/ common;
    final int k = outFactor ~/ common;
    final int den = (2 * a) ~/ common;

    final int normB = den < 0 ? -numB : numB;
    final int normDen = den.abs();

    String formatRoot(int signSqrt) {
      final radicalTerm = k == 1 ? r'\sqrt{' '$rad}' : '$k' r'\sqrt{' '$rad}';
      final top = normB == 0
          ? (signSqrt < 0 ? '-$radicalTerm' : radicalTerm)
          : '$normB ${signSqrt > 0 ? '+' : '-'} $radicalTerm';
      return normDen == 1 ? top : r'\frac{' '$top}{$normDen}';
    }

    final v1 = (-b - sqrtD) / (2 * a);
    final v2 = (-b + sqrtD) / (2 * a);
    if (2 * a > 0) {
      return (
        QuadRoot(latex: formatRoot(-1), approx: v1),
        QuadRoot(latex: formatRoot(1), approx: v2),
      );
    }
    return (
      QuadRoot(latex: formatRoot(-1), approx: v2),
      QuadRoot(latex: formatRoot(1), approx: v1),
    );
  }

  static String fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  static List<InequalityInterval> intersectIntervalLists(
    List<InequalityInterval> list1,
    List<InequalityInterval> list2,
  ) {
    if (list1.isEmpty || list2.isEmpty) return const [];
    final result = <InequalityInterval>[];

    for (final i1 in list1) {
      for (final i2 in list2) {
        final start = math.max(i1.start, i2.start);
        final end = math.min(i1.end, i2.end);

        if (start < end) {
          final incStart = (start == i1.start ? i1.includeStart : true) &&
              (start == i2.start ? i2.includeStart : true);
          final incEnd = (end == i1.end ? i1.includeEnd : true) &&
              (end == i2.end ? i2.includeEnd : true);

          final sLabel = start == i1.start ? i1.startLabel : i2.startLabel;
          final eLabel = end == i1.end ? i1.endLabel : i2.endLabel;

          result.add(
            InequalityInterval(
              start: start,
              end: end,
              includeStart: incStart,
              includeEnd: incEnd,
              startLabel: sLabel,
              endLabel: eLabel,
            ),
          );
        } else if (start == end) {
          final incBoth = (start == i1.start ? i1.includeStart : i1.includeEnd) &&
              (start == i2.start ? i2.includeStart : i2.includeEnd);
          if (incBoth) {
            result.add(
              InequalityInterval(
                start: start,
                end: end,
                includeStart: true,
                includeEnd: true,
                startLabel: fmt(start),
                endLabel: fmt(end),
              ),
            );
          }
        }
      }
    }
    return result;
  }
}
