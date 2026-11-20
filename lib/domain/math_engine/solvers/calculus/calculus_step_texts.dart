import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../exact/ext_expr.dart';
import 'sym_build.dart';
import 'sym_diff.dart';
import 'sym_latex.dart';

/// Pasos "de pizarra" para derivadas e integrales: regla, piezas, formula, simplificacion.
/// Dentro de `\text{}` solo ASCII; las explicaciones con tilde van en `shortTitle`/`pedagogicalNote`.
class CalculusStepTexts {
  const CalculusStepTexts._();

  static String _t(XNode n) => SymLatex.tex(n);

  static MathStep _s(String title, String latex, String note, {String? trick}) =>
      MathStep(index: 0, shortTitle: title, latexExpression: latex, pedagogicalNote: note, warningTrick: trick);

  // ───────────────────────── DERIVADAS ─────────────────────────

  static const _ruleFormulas = <String, String>{
    'lineal': r"\text{Linealidad}:\ (u \pm v)' = u' \pm v',\quad (k \cdot u)' = k \cdot u'",
    'potencia': r"\text{Potencia}:\ (x^{n})' = n \cdot x^{n-1}",
    'producto': r"\text{Producto}:\ (u \cdot v)' = u'v + uv'",
    'cociente': r"\text{Cociente}:\ \left(\frac{u}{v}\right)' = \frac{u'v - uv'}{v^{2}}",
    'cadena': r"\text{Cadena}:\ [f(g(x))]' = f'(g(x)) \cdot g'(x)",
    'exp': r"\text{Exponencial}:\ (e^{u})' = e^{u} \cdot u',\quad (a^{u})' = a^{u} \ln a \cdot u'",
    'ln': r"\text{Logaritmo}:\ (\ln u)' = \frac{u'}{u}",
    'sin': r"\text{Seno}:\ (\sin u)' = \cos u \cdot u'",
    'cos': r"\text{Coseno}:\ (\cos u)' = -\sin u \cdot u'",
    'tan': r"\text{Tangente}:\ (\tan u)' = \frac{u'}{\cos^{2} u}",
    'inv': r"\text{Trig. inversa}:\ (\arcsin u)' = \frac{u'}{\sqrt{1-u^{2}}},\ (\arccos u)' = -\frac{u'}{\sqrt{1-u^{2}}},\ (\arctan u)' = \frac{u'}{1+u^{2}}",
    'raiz': r"\text{Raiz}:\ \left(\sqrt[n]{u}\right)' = \frac{u'}{n \cdot \sqrt[n]{u^{n-1}}}",
    'log': r"\text{Log. en base a}:\ (\log_{a} u)' = \frac{u'}{u \ln a}",
    'hip': r"\text{Hiperbolicas}:\ (\sinh u)' = \cosh u \cdot u',\ (\cosh u)' = \sinh u \cdot u',\ (\tanh u)' = \frac{u'}{\cosh^{2} u}",
  };

  static const _ruleNames = <String, String>{
    'lineal': 'linealidad',
    'potencia': 'potencia',
    'producto': 'producto',
    'cociente': 'cociente',
    'cadena': 'cadena',
    'exp': 'exponencial',
    'ln': 'logaritmo',
    'sin': 'seno',
    'cos': 'coseno',
    'tan': 'tangente',
    'inv': 'trigonométricas inversas',
    'raiz': 'raíz n-ésima',
    'log': 'logaritmo en base a',
    'hip': 'hiperbólicas',
  };

  /// Reglas que hay que aplicar a [f], en el orden en que se explican en clase.
  static List<String> rules(XNode f) {
    final k = <String>{};
    void walk(XNode n) {
      switch (n) {
        case XBin(:final l, :final op, :final r):
          if (op == '+' || op == '-') {
            if (Sx.hasX(l) && Sx.hasX(r)) k.add('lineal');
          } else if (op == '*') {
            if (Sx.hasX(l) && Sx.hasX(r)) {
              k.add('producto');
            } else {
              k.add('lineal');
            }
          } else if (Sx.hasX(r)) {
            k.add(Sx.hasX(l) ? 'cociente' : 'potencia');
          } else {
            k.add('lineal');
          }
          walk(l);
          walk(r);
        case XNeg(:final a):
          k.add('lineal');
          walk(a);
        case XPow(:final base, :final exp):
          if (Sx.hasX(exp)) {
            k.add(base is XConst ? 'exp' : 'potencia');
            if (exp is! XVar) k.add('cadena');
          } else {
            k.add('potencia');
            if (base is! XVar) k.add('cadena');
          }
          walk(base);
          walk(exp);
        case XRoot(:final index, :final rad):
          k.add(index == null || Sx.isNum(index, 2) ? 'potencia' : 'raiz');
          if (rad is! XVar) k.add('cadena');
          walk(rad);
        case XFn(:final name, :final arg, :final base):
          k.add(switch (name) {
            'sin' => 'sin',
            'cos' => 'cos',
            'tan' => 'tan',
            'ln' => 'ln',
            'log' => base == null ? 'ln' : 'log',
            'sinh' || 'cosh' || 'tanh' || 'asinh' || 'acosh' || 'atanh' => 'hip',
            _ => 'inv',
          });
          if (arg is! XVar) k.add('cadena');
          walk(arg);
        default:
          break;
      }
    }

    walk(f);
    const order = [
      'lineal', 'potencia', 'raiz', 'producto', 'cociente', 'cadena', 'exp', 'ln', 'log', 'sin', 'cos', 'tan', 'inv', 'hip',
    ];
    final out = [for (final o in order) if (k.contains(o)) o];
    return out.isEmpty ? const ['potencia'] : out;
  }

  /// Paso 1: que regla se aplica, con su formula.
  static MathStep identifyRule(XNode f) {
    final rs = rules(f);
    return _s(
      '1. Identificar la regla de derivación',
      // Una regla por linea: en una sola fila la LCD la reduciria a letra ilegible.
      "\\begin{array}{l} f(x) = ${_t(f)} \\\\[4pt] ${rs.map((r) => _ruleFormulas[r]!).join(r' \\ ')} \\end{array}",
      'Miramos la estructura de f(x) y elegimos la regla: ${rs.map((r) => _ruleNames[r]).join(', ')}. '
          'Siempre derivamos de fuera hacia dentro.',
    );
  }

  static List<(bool, XNode)> _terms(XNode n, [bool positive = true]) {
    if (n is XBin && (n.op == '+' || n.op == '-')) {
      return [..._terms(n.l, positive), ..._terms(n.r, n.op == '+' ? positive : !positive)];
    }
    if (n is XNeg) return _terms(n.a, !positive);
    return [(positive, n)];
  }

  static XNode _d(XNode n) => const SymDiff().d(n);

  /// Paso 2: desglose de piezas (u, u', v, v' o g, g') antes de sustituir.
  static MathStep pieces(XNode f) {
    final terms = _terms(f);
    if (terms.length > 1) {
      final rows = [
        for (var i = 0; i < terms.length; i++)
          'u_{${i + 1}} = ${_t(terms[i].$2)} \\;\\Rightarrow\\; u_{${i + 1}}\' = ${_t(_d(terms[i].$2))}',
      ];
      return _s(
        '2. Desglose de piezas: derivar término a término',
        rows.join(r',\quad '),
        'Por linealidad, la derivada de una suma es la suma de las derivadas. Calculamos cada u y su u\' por separado.',
      );
    }
    final g = terms.first.$2;
    if (g is XBin && g.op == '*' && Sx.hasX(g.l) && Sx.hasX(g.r) || g is XBin && g.op == '/' && Sx.hasX(g.l) && Sx.hasX(g.r)) {
      final b = g;
      return _s(
        '2. Desglose de piezas: u, u\', v, v\'',
        "u = ${_t(b.l)},\\quad u' = ${_t(_d(b.l))},\\quad v = ${_t(b.r)},\\quad v' = ${_t(_d(b.r))}",
        'Antes de sustituir en la fórmula, calculamos por separado u, v y sus derivadas.',
      );
    }
    final inner = switch (g) {
      XFn(:final arg) when arg is! XVar => arg,
      XPow(:final base, :final exp) when !Sx.hasX(exp) && base is! XVar => base,
      XPow(:final base, :final exp) when Sx.hasX(exp) && base is XConst => exp,
      XRoot(:final rad) when rad is! XVar => rad,
      _ => null,
    };
    if (inner != null) {
      return _s(
        '2. Desglose de piezas: función exterior e interior',
        "g(x) = ${_t(inner)},\\quad g'(x) = ${_t(_d(inner))}",
        'La función interior es g(x); la exterior se deriva sin tocar g y después se multiplica por g\'(x).',
      );
    }
    return _s(
      '2. Desglose de piezas',
      "u = ${_t(g)} \\;\\Rightarrow\\; u' = ${_t(_d(g))}",
      'La expresión es una pieza elemental: aplicamos directamente la derivada de la tabla.',
    );
  }

  /// Paso 3 cuando SymDiff no registro ninguna regla compuesta (suma/potencia/elemental).
  static MathStep? apply(XNode f, XNode derivative) {
    final terms = _terms(f);
    if (terms.length > 1) {
      final sym = StringBuffer();
      final val = StringBuffer();
      for (var i = 0; i < terms.length; i++) {
        final pos = terms[i].$1;
        if (i == 0) {
          sym.write(pos ? '' : '-');
          val.write(pos ? '' : '-');
        } else {
          sym.write(pos ? ' + ' : ' - ');
          val.write(pos ? ' + ' : ' - ');
        }
        sym.write("u_{${i + 1}}'");
        val.write('\\left(${_t(_d(terms[i].$2))}\\right)');
      }
      return _s('3. Aplicar la fórmula sin simplificar', "f'(x) = $sym = $val",
          'Escribimos la derivada de la suma con cada u\' ya calculada, sin simplificar todavía.');
    }
    return _s('3. Aplicar la fórmula sin simplificar', "\\left(${_t(f)}\\right)' = ${_t(derivative)}",
        'Sustituimos en la fórmula de la tabla (n · x^(n-1), cos u · u\', ...) sin simplificar todavía.');
  }

  // ───────────────────────── INTEGRALES ─────────────────────────

  /// Reescribe raices y denominadores como potencias de x (x^{1/2}, x^{-n}).
  static XNode asPowers(XNode n) {
    switch (n) {
      case XRoot(:final index, :final rad):
        final k = index == null ? Rational(2) : Sx.numVal(index);
        if (k == null || k.isZero) return n;
        return Sx.powR(asPowers(rad), Rational(1) / k);
      case XNeg(:final a):
        return Sx.neg(asPowers(a));
      case XPow(:final base, :final exp):
        return Sx.pow(asPowers(base), exp);
      case XBin(:final l, :final op, :final r):
        final a = asPowers(l);
        if (op == '/' && Sx.hasX(r)) {
          final den = asPowers(r);
          if (den is XVar) return Sx.mul(a, Sx.powR(den, Rational(-1)));
          if (den is XPow && den.base is XVar && Sx.numVal(den.exp) != null) {
            return Sx.mul(a, Sx.powR(den.base, -Sx.numVal(den.exp)!));
          }
          return XBin(a, '/', den);
        }
        final b = asPowers(r);
        return switch (op) {
          '+' => Sx.add(a, b),
          '-' => Sx.sub(a, b),
          '*' => Sx.mul(a, b),
          _ => Sx.div(a, b),
        };
      default:
        return n;
    }
  }

  static bool _needsRewrite(XNode n) => switch (n) {
        XRoot() => true,
        XBin(:final l, :final op, :final r) => (op == '/' && Sx.hasX(r)) || _needsRewrite(l) || _needsRewrite(r),
        XNeg(:final a) => _needsRewrite(a),
        XPow(:final base) => _needsRewrite(base),
        _ => false,
      };

  /// LaTeX que conserva las potencias racionales/negativas (SymLatex las pasa a raices/fracciones).
  static String _ptex(XNode n) {
    switch (n) {
      case XPow(:final base, :final exp):
        final ve = Sx.numVal(exp);
        if (ve != null && (ve.isNegative || ve.denominator != 1)) {
          final b = base is XVar ? _t(base) : '\\left(${_ptex(base)}\\right)';
          return '$b^{${ve.toLatex()}}';
        }
        return _t(n);
      case XNeg(:final a):
        return '-${_ptex(a)}';
      case XBin(:final l, :final op, :final r) when op != '/':
        final sep = op == '*' ? (l is XNum ? '' : r'\cdot ') : ' $op ';
        return '${_ptex(l)}$sep${_ptex(r)}';
      default:
        return _t(n);
    }
  }

  /// Paso 1: preparacion y linealidad.
  static MathStep prepare(XNode f) {
    final rewrite = _needsRewrite(f);
    final p = rewrite ? asPowers(f) : f;
    final terms = _terms(p);
    var body = '\\int ${_t(f)}\\,dx';
    final notes = <String>[];
    if (rewrite) {
      body += ' = \\int ${_ptex(p)}\\,dx';
      notes.add('Reescribimos raíces y denominadores como potencias (√x = x^(1/2), 1/xⁿ = x^(-n))');
    }
    if (terms.length > 1) {
      final parts = [
        for (var i = 0; i < terms.length; i++)
          '${i == 0 ? (terms[i].$1 ? '' : '-') : (terms[i].$1 ? '+' : '-')}\\int ${_ptex(terms[i].$2)}\\,dx',
      ];
      body += ' = ${parts.join(' ')}';
      notes.add('Separamos la suma en integrales más sencillas (linealidad)');
    } else if (p is XBin && p.op == '*' && !Sx.hasX(p.l)) {
      body += ' = ${_t(p.l)} \\int ${_ptex(p.r)}\\,dx';
      notes.add('Sacamos la constante fuera de la integral: ∫k·f(x)dx = k·∫f(x)dx');
    }
    if (notes.isEmpty) notes.add('La integral ya está lista: no hace falta separar ni reescribir nada');
    return _s('1. Preparación y linealidad', body, '${notes.join('. ')}.');
  }

  /// Paso 2: eleccion del metodo segun lo que registro el integrador.
  static MathStep method(XNode f, List<MathStep> logged) {
    final titles = logged.map((s) => s.shortTitle.toLowerCase()).join('|');
    if (titles.contains('partes')) {
      return _s(
        '2. Elección del método: integración por partes',
        r'\int u\,dv = u \cdot v - \int v\,du',
        'El integrando es un producto que no se resuelve de forma inmediata. Elegimos u (la que se simplifica al derivar, regla LIATE) y dv (lo que sabemos integrar), y calculamos du y v.',
      );
    }
    if (titles.contains('cambio') || titles.contains('sustituci')) {
      return _s(
        '2. Elección del método: ajuste de la derivada del interior',
        r'\int f^{\prime}(x)\,[f(x)]^{n}dx = \frac{[f(x)]^{n+1}}{n+1} \quad;\quad \int \frac{f^{\prime}(x)}{f(x)}dx = \ln|f(x)|',
        'Aparece una función y su derivada (salvo una constante). Multiplicamos y dividimos por la constante que falta para que la derivada del interior quede completa y aplicamos la fórmula.',
      );
    }
    return _s(
      '2. Elección del método: integral inmediata',
      r'\int x^{n}dx = \frac{x^{n+1}}{n+1}+C \quad;\quad \int \frac{1}{x}dx=\ln|x|+C \quad;\quad \int e^{x}dx=e^{x}+C',
      'Cada término es de la tabla de integrales inmediatas: usamos directamente la fórmula correspondiente.',
    );
  }
}
