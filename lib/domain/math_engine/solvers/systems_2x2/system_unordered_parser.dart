import '../../core/rational.dart';
import '../../models/linear_system_models.dart';

class SystemUnorderedParser {
  /// Parsea cualquier ecuación lineal desordenada (ej: "2y + 3x - 5 = x + 1")
  /// y la agrupa a la forma estándar: a1*x + a2*y + a3*z + a4*w = C.
  static ParsedLinearEquation parse(
    String raw, {
    List<String> vars = const ['x', 'y', 'z', 'w'],
  }) {
    final clean = raw
        .replaceAll('\r', '')
        .replaceAll(' ', '')
        .replaceAll('X', 'x')
        .replaceAll('Y', 'y')
        .replaceAll('Z', 'z')
        .replaceAll('W', 'w')
        .replaceAll('−', '-')
        .replaceAll('·', '*')
        .replaceAll('×', '*')
        .replaceAll(r'\cdot', '*')
        .replaceAll(r'\times', '*');

    final sides = clean.split('=');
    final lhsStr = sides[0].trim();
    final rhsStr = sides.length > 1 ? sides[1].trim() : '0';

    final lhsMap = parseLinearSide(lhsStr, vars);
    final rhsMap = parseLinearSide(rhsStr, vars);

    final finalCoeffs = <String, Rational>{};
    for (final v in vars) {
      final lhsCoeff = lhsMap[v] ?? Rational(0);
      final rhsCoeff = rhsMap[v] ?? Rational(0);
      finalCoeffs[v] = lhsCoeff - rhsCoeff;
    }

    final lhsConst = lhsMap['__const__'] ?? Rational(0);
    final rhsConst = rhsMap['__const__'] ?? Rational(0);
    final finalConst = rhsConst - lhsConst;

    // Construir LaTeX ordenado
    final buffer = StringBuffer();
    bool first = true;
    for (final v in vars) {
      final c = finalCoeffs[v]!;
      if (c.isZero) continue;
      if (first) {
        if (c.isNegative) buffer.write('-');
        final absC = c.abs();
        if (absC != Rational(1)) buffer.write(absC.toLatex());
        buffer.write(v);
        first = false;
      } else {
        buffer.write(c.isNegative ? ' - ' : ' + ');
        final absC = c.abs();
        if (absC != Rational(1)) buffer.write(absC.toLatex());
        buffer.write(v);
      }
    }
    if (first) buffer.write('0');
    buffer.write(' = ${finalConst.toLatex()}');

    return ParsedLinearEquation(
      coefficients: finalCoeffs,
      constant: finalConst,
      originalRaw: raw,
      orderedLatex: buffer.toString(),
    );
  }

  static Map<String, Rational> parseLinearSide(String expr, List<String> vars) {
    final res = <String, Rational>{};
    for (final v in vars) {
      res[v] = Rational(0);
    }
    res['__const__'] = Rational(0);

    if (expr.isEmpty) return res;

    // Expandir paréntesis simples si existen: k*(ax + b)
    var expanded = expr;
    final parenPattern = RegExp(r'([+-]?\d*(?:\.\d+)?)\*?\(([^)]+)\)');
    while (parenPattern.hasMatch(expanded)) {
      final m = parenPattern.firstMatch(expanded)!;
      final kStr = m.group(1)!;
      final k = kStr.isEmpty || kStr == '+' ? 1.0 : (kStr == '-' ? -1.0 : double.parse(kStr));
      final inner = m.group(2)!;
      final innerTokens = splitSignedTokens(inner);
      final expBuf = StringBuffer();
      for (final t in innerTokens) {
        final parsedT = parseSingleToken(t, vars);
        if (parsedT.varName != null) {
          final newCoeff = parsedT.val * k;
          final sign = newCoeff >= 0 ? '+' : '-';
          expBuf.write('$sign${newCoeff.abs()}${parsedT.varName}');
        } else {
          final newConst = parsedT.val * k;
          final sign = newConst >= 0 ? '+' : '-';
          expBuf.write('$sign${newConst.abs()}');
        }
      }
      expanded = expanded.replaceFirst(m.group(0)!, expBuf.toString());
    }

    final tokens = splitSignedTokens(expanded);
    for (final t in tokens) {
      final item = parseSingleToken(t, vars);
      if (item.varName != null) {
        final r = Rational.fromDouble(item.val, 1000);
        res[item.varName!] = res[item.varName!]! + r;
      } else {
        final r = Rational.fromDouble(item.val, 1000);
        res['__const__'] = res['__const__']! + r;
      }
    }
    return res;
  }

  static List<String> splitSignedTokens(String s) {
    final clean = s.replaceAll(' ', '');
    final tokens = <String>[];
    int start = 0;
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && (clean[i] == '+' || clean[i] == '-')) {
        tokens.add(clean.substring(start, i));
        start = i;
      }
    }
    if (start < clean.length) {
      tokens.add(clean.substring(start));
    }
    return tokens;
  }

  static ({double val, String? varName}) parseSingleToken(String tok, List<String> vars) {
    for (final v in vars) {
      if (tok.contains(v)) {
        final coeffStr = tok.replaceAll(v, '').replaceAll('*', '').trim();
        final double coeff;
        if (coeffStr.isEmpty || coeffStr == '+') {
          coeff = 1.0;
        } else if (coeffStr == '-') {
          coeff = -1.0;
        } else if (coeffStr.contains('/')) {
          final parts = coeffStr.split('/');
          coeff = double.parse(parts[0]) / double.parse(parts[1]);
        } else {
          coeff = double.parse(coeffStr);
        }
        return (val: coeff, varName: v);
      }
    }
    final double cVal;
    if (tok.contains('/')) {
      final parts = tok.split('/');
      cVal = double.parse(parts[0]) / double.parse(parts[1]);
    } else {
      cVal = double.tryParse(tok) ?? 0.0;
    }
    return (val: cVal, varName: null);
  }
}
