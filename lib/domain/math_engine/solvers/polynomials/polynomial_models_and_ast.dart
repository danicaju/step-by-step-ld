import '../../core/algebraic_latex_formatter.dart';
import '../../core/rational.dart';

/// Polinomio exacto con coeficientes racionales ordenado de grado `0` a `N`.
class RationalPoly {
  final List<Rational> coeffs; // coeffs[i] es coeficiente de x^i

  RationalPoly(List<Rational> raw) : coeffs = _trim(raw);

  factory RationalPoly.zero() => RationalPoly(const []);

  factory RationalPoly.constant(Rational c) =>
      c.isZero ? RationalPoly.zero() : RationalPoly([c]);

  factory RationalPoly.x() => RationalPoly([Rational(0), Rational(1)]);

  static List<Rational> _trim(List<Rational> input) {
    int end = input.length;
    while (end > 0 && input[end - 1].isZero) {
      end--;
    }
    return input.sublist(0, end);
  }

  int get degree => coeffs.isEmpty ? 0 : coeffs.length - 1;

  Rational at(int deg) => deg < coeffs.length ? coeffs[deg] : Rational(0);

  bool get isConstant => degree == 0;

  RationalPoly operator +(RationalPoly other) {
    final len = coeffs.length > other.coeffs.length
        ? coeffs.length
        : other.coeffs.length;
    final out = List<Rational>.generate(len, (i) => at(i) + other.at(i));
    return RationalPoly(out);
  }

  RationalPoly operator -(RationalPoly other) {
    final len = coeffs.length > other.coeffs.length
        ? coeffs.length
        : other.coeffs.length;
    final out = List<Rational>.generate(len, (i) => at(i) - other.at(i));
    return RationalPoly(out);
  }

  RationalPoly operator -() =>
      RationalPoly(coeffs.map((c) => -c).toList());

  RationalPoly operator *(RationalPoly other) {
    if (coeffs.isEmpty || other.coeffs.isEmpty) return RationalPoly.zero();
    final out = List<Rational>.filled(
      coeffs.length + other.coeffs.length - 1,
      Rational(0),
    );
    for (int i = 0; i < coeffs.length; i++) {
      if (coeffs[i].isZero) continue;
      for (int j = 0; j < other.coeffs.length; j++) {
        out[i + j] = out[i + j] + (coeffs[i] * other.coeffs[j]);
      }
    }
    return RationalPoly(out);
  }

  RationalPoly scale(Rational k) {
    if (k.isZero || coeffs.isEmpty) return RationalPoly.zero();
    return RationalPoly(coeffs.map((c) => c * k).toList());
  }

  RationalPoly divideByScalar(Rational k) {
    if (k.isZero) {
      throw const FormatException('División por cero en la ecuación.');
    }
    return RationalPoly(coeffs.map((c) => c / k).toList());
  }

  RationalPoly powInt(int exp) {
    if (exp < 0) {
      throw const FormatException(
        'No se admiten exponentes negativos sobre la incógnita.',
      );
    }
    if (exp == 0) return RationalPoly.constant(Rational(1));
    var res = RationalPoly.constant(Rational(1));
    for (int i = 0; i < exp; i++) {
      res = res * this;
    }
    return res;
  }

  /// Devuelve el LaTeX en orden estándar descendente `a x² + b x + c` (solo coeficientes enteros).
  String toLatex({String variable = 'x'}) {
    if (coeffs.isEmpty) return '0';
    final lcmDen = Rational.lcmMany(coeffs.map((c) => c.denominator).toList());
    if (lcmDen == 1) {
      final intCoeffsDesc = <int>[];
      for (int d = degree; d >= 0; d--) {
        intCoeffsDesc.add(at(d).numerator);
      }
      return AlgebraicLatexFormatter.polynomialExpression(
        intCoeffsDesc,
        variable: variable,
      );
    }

    final buf = StringBuffer();
    bool hasWritten = false;
    for (int d = degree; d >= 0; d--) {
      final c = at(d);
      if (c.isZero) continue;
      final isNeg = c.numerator < 0;
      final absC = c.abs();
      if (!hasWritten) {
        if (isNeg) buf.write('-');
      } else {
        buf.write(isNeg ? ' - ' : ' + ');
      }
      if (d == 0) {
        buf.write(absC.toLatex());
      } else {
        if (absC != Rational(1)) {
          buf.write(absC.toLatex());
        }
        buf.write(d == 1 ? variable : '$variable^{$d}');
      }
      hasWritten = true;
    }
    return hasWritten ? buf.toString() : '0';
  }
}

sealed class EqAstNode {
  const EqAstNode();
}

class NumAst extends EqAstNode {
  final Rational value;
  const NumAst(this.value);
}

class VarAst extends EqAstNode {
  const VarAst();
}

class UnaryNegAst extends EqAstNode {
  final EqAstNode inner;
  const UnaryNegAst(this.inner);
}

class ParenAst extends EqAstNode {
  final EqAstNode inner;
  const ParenAst(this.inner);
}

class BinAst extends EqAstNode {
  final String op; // +, -, *, /, ^
  final EqAstNode left;
  final EqAstNode right;
  const BinAst(this.op, this.left, this.right);
}

class EqSideParser {
  final List<EqToken> _tokens;
  int _pos = 0;

  EqSideParser(String input) : _tokens = _tokenize(input);

  static List<EqToken> _tokenize(String src) {
    final cleaned = src.replaceAll(' ', '');
    final rawTokens = <EqToken>[];
    int i = 0;
    while (i < cleaned.length) {
      final ch = cleaned[i];
      if (ch == 'x' || ch == 'X') {
        rawTokens.add(const EqToken(EqTokenType.variable, 'x'));
        i++;
      } else if (RegExp(r'[0-9.]').hasMatch(ch)) {
        final start = i;
        while (i < cleaned.length && RegExp(r'[0-9.]').hasMatch(cleaned[i])) {
          i++;
        }
        rawTokens.add(EqToken(EqTokenType.number, cleaned.substring(start, i)));
      } else if ('+-*/^()'.contains(ch)) {
        rawTokens.add(EqToken(EqTokenType.op, ch));
        i++;
      } else {
        throw FormatException('Símbolo no válido en ecuación: "$ch"');
      }
    }

    // Insertar multiplicación implícita `*` entre:
    // - número seguido de `x` o `(`
    // - `x` seguido de `x`, número o `(`
    // - `)` seguido de número, `x` o `(`
    final out = <EqToken>[];
    for (int j = 0; j < rawTokens.length; j++) {
      final cur = rawTokens[j];
      if (out.isNotEmpty) {
        final prev = out.last;
        final prevEndsOperand = prev.type == EqTokenType.number ||
            prev.type == EqTokenType.variable ||
            prev.value == ')';
        final curStartsOperand = cur.type == EqTokenType.number ||
            cur.type == EqTokenType.variable ||
            cur.value == '(';
        if (prevEndsOperand && curStartsOperand) {
          out.add(const EqToken(EqTokenType.op, '*'));
        }
      }
      out.add(cur);
    }
    return out;
  }

  EqToken? get _cur => _pos < _tokens.length ? _tokens[_pos] : null;

  EqAstNode parse() {
    if (_tokens.isEmpty) {
      throw const FormatException('Miembro de la ecuación vacío.');
    }
    final node = _parseAddSub();
    if (_pos < _tokens.length) {
      throw const FormatException(
        'Expresión incompleta o paréntesis sin cerrar.',
      );
    }
    return node;
  }

  EqAstNode _parseAddSub() {
    var node = _parseMulDiv();
    while (_cur?.value == '+' || _cur?.value == '-') {
      final op = _tokens[_pos++].value;
      final right = _parseMulDiv();
      node = BinAst(op, node, right);
    }
    return node;
  }

  EqAstNode _parseMulDiv() {
    var node = _parseUnary();
    while (_cur?.value == '*' || _cur?.value == '/') {
      final op = _tokens[_pos++].value;
      final right = _parseUnary();
      node = BinAst(op, node, right);
    }
    return node;
  }

  EqAstNode _parseUnary() {
    if (_cur?.value == '-') {
      _pos++;
      return UnaryNegAst(_parseUnary());
    }
    if (_cur?.value == '+') {
      _pos++;
      return _parseUnary();
    }
    return _parsePower();
  }

  EqAstNode _parsePower() {
    var base = _parsePrimary();
    if (_cur?.value == '^') {
      _pos++;
      final exp = _parseUnary();
      return BinAst('^', base, exp);
    }
    return base;
  }

  EqAstNode _parsePrimary() {
    final tok = _cur;
    if (tok == null) {
      throw const FormatException('Se esperaba un número, "x" o paréntesis.');
    }
    if (tok.type == EqTokenType.number) {
      _pos++;
      final raw = tok.value;
      if (raw == '.') {
        throw const FormatException('Número decimal incompleto.');
      }
      final r = raw.contains('.')
          ? Rational.fromDecimalString(raw)
          : Rational(int.parse(raw));
      return NumAst(r);
    }
    if (tok.type == EqTokenType.variable) {
      _pos++;
      return const VarAst();
    }
    if (tok.value == '(') {
      _pos++;
      final inner = _parseAddSub();
      if (_cur?.value != ')') {
        throw const FormatException('Falta cerrar un paréntesis ")".');
      }
      _pos++;
      return ParenAst(inner);
    }
    throw FormatException('Token inesperado: "${tok.value}"');
  }
}

enum EqTokenType { number, variable, op }

class EqToken {
  final EqTokenType type;
  final String value;
  const EqToken(this.type, this.value);
}
