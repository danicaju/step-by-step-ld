import '../../core/rational.dart';

/// Expresion no soportada por el motor extendido (se delega al motor clasico).
class ExtUnsupported implements Exception {
  final String message;
  const ExtUnsupported(this.message);
  @override
  String toString() => message;
}

/// AST tipado del motor exacto extendido (M1). Nunca se evalua con eval().
sealed class XNode {
  const XNode();

  /// Precedencia para parentizar: 1 suma, 2 producto, 3 unario, 5 atomo.
  int get prec => 5;

  String latex();

  String wrap(int min) =>
      prec < min ? '\\left(${latex()}\\right)' : latex();
}

class XNum extends XNode {
  final Rational value;
  final String? raw;
  const XNum(this.value, [this.raw]);
  @override
  int get prec => value.isNegative ? 3 : 5;
  @override
  String latex() {
    if (raw != null && raw!.contains('.')) return raw!.replaceAll('.', '{,}');
    if (value.denominator == 1) return '${value.numerator}';
    final sign = value.isNegative ? '-' : '';
    return '$sign\\frac{${value.numerator.abs()}}{${value.denominator}}';
  }
}

class XConst extends XNode {
  final String kind; // pi | e
  const XConst(this.kind);
  @override
  String latex() => kind == 'pi' ? '\\pi' : 'e';
}

class XVar extends XNode {
  final String name;
  const XVar(this.name);
  @override
  String latex() => switch (name) {
        'ANS' => '\\text{Ans}',
        'X' => 'x',
        'Y' => 'y',
        'Z' => 'z',
        'W' => 'w',
        _ => name,
      };
}

class XNeg extends XNode {
  final XNode a;
  const XNeg(this.a);
  @override
  int get prec => 3;
  @override
  String latex() => '-${a.wrap(3)}';
}

class XBin extends XNode {
  final XNode l;
  final String op; // + - * /
  final XNode r;
  const XBin(this.l, this.op, this.r);
  @override
  int get prec => switch (op) {
        '+' || '-' => 1,
        '*' => 2,
        _ => 5,
      };
  @override
  String latex() => switch (op) {
        '/' => '\\frac{${l.latex()}}{${r.latex()}}',
        '*' => '${l.wrap(2)} \\cdot ${r.wrap(3)}',
        '-' => '${l.wrap(1)} - ${r.wrap(2)}',
        _ => '${l.wrap(1)} + ${r.wrap(2)}',
      };
}

class XPow extends XNode {
  final XNode base;
  final XNode exp;
  const XPow(this.base, this.exp);
  @override
  int get prec => 4;
  @override
  String latex() {
    final b = base is XBin && (base as XBin).op == '/'
        ? '\\left(${base.latex()}\\right)'
        : base.wrap(5);
    return '$b^{${exp.latex()}}';
  }
}

class XRoot extends XNode {
  final XNode? index;
  final XNode rad;
  const XRoot(this.index, this.rad);
  @override
  String latex() => index == null
      ? '\\sqrt{${rad.latex()}}'
      : '\\sqrt[${index!.latex()}]{${rad.latex()}}';
}

class XAbs extends XNode {
  final XNode a;
  const XAbs(this.a);
  @override
  String latex() => '\\left|${a.latex()}\\right|';
}

class XFact extends XNode {
  final XNode a;
  const XFact(this.a);
  @override
  int get prec => 4;
  @override
  String latex() => '${a.wrap(5)}!';
}

class XComb extends XNode {
  final XNode n;
  final XNode r;
  final bool perm;
  const XComb(this.n, this.r, this.perm);
  @override
  int get prec => 4;
  @override
  String latex() => perm
      ? '{}_{${n.latex()}}P_{${r.latex()}}'
      : '\\binom{${n.latex()}}{${r.latex()}}';
}

/// sin cos tan asin acos atan ln log (con [base] opcional).
class XFn extends XNode {
  final String name;
  final XNode arg;
  final XNode? base;
  const XFn(this.name, this.arg, {this.base});

  static const _inv = {
    'asin': 'arcsin',
    'acos': 'arccos',
    'atan': 'arctan',
    'asinh': 'sinh^{-1}',
    'acosh': 'cosh^{-1}',
    'atanh': 'tanh^{-1}',
  };

  @override
  String latex() {
    final a = arg.latex();
    if (name == 'log') {
      return base == null
          ? '\\log\\left($a\\right)'
          : '\\log_{${base!.latex()}}\\left($a\\right)';
    }
    return '\\${_inv[name] ?? name}\\left($a\\right)';
  }
}
