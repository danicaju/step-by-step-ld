import '../../../models/step_resolution.dart';
import '../../exact/ext_expr.dart';
import '../inequality_sign.dart';
import 'inequality_family_detector.dart';
import 'numeric_function.dart';

/// Pasos didacticos previos al estudio de signos segun la familia de la inecuacion
/// (radicales, logaritmos, exponenciales, valor absoluto, trigonometricas y mixtas).
abstract final class InequalityFamilySteps {
  static bool _hasX(XNode n) => NumFn.hasX(n);

  static double? _const(XNode n) => _hasX(n) ? null : NumFn.eval(n, 0);

  static String _k(double v) => (v - v.roundToDouble()).abs() < 1e-12 ? '${v.round()}' : '$v';

  static XRoot? _sqrt(XNode n) {
    if (n is! XRoot || !_hasX(n.rad)) return null;
    final idx = n.index;
    if (idx == null) return n;
    return idx is XNum && idx.value.numerator == 2 && idx.value.denominator == 1 ? n : null;
  }

  static List<MathStep> build(InequalityFamily fam, XNode l, XNode r, InequalitySign s) {
    final steps = switch (fam) {
      InequalityFamily.radical => _radical(l, r, s),
      InequalityFamily.logarithmic => _log(l, r, s),
      InequalityFamily.exponential => _exp(l, r, s),
      InequalityFamily.absolute => _abs(l, r, s),
      _ => <MathStep>[],
    };
    return steps;
  }

  static MathStep _st(String title, String latex, String note, [String? warn]) => MathStep(
        index: 0,
        shortTitle: title,
        latexExpression: latex,
        pedagogicalNote: note,
        warningTrick: warn,
      );

  // ---------------------------------------------------------------- radicales
  static List<MathStep> _radical(XNode l, XNode r, InequalitySign s) {
    final sl = _sqrt(l), sr = _sqrt(r);
    if (sl != null && sr != null) {
      final f = sl.rad.latex(), g = sr.rad.latex();
      return [
        _st(
          'Radicales a ambos lados',
          '$f \\ge 0 \\;\\text{y}\\; $g \\ge 0 \\qquad \\sqrt{$f} ${s.latex} \\sqrt{$g} \\iff $f ${s.latex} $g',
          'Primero se exige que los dos radicandos sean mayores o iguales que 0. Como ambos miembros son no negativos, se puede elevar al cuadrado sin cambiar el sentido de la desigualdad.',
          'Elevar al cuadrado sin comprobar el dominio crea soluciones falsas.',
        ),
      ];
    }
    final rootLeft = sl != null;
    final root = sl ?? sr;
    if (root == null) {
      return [
        _st(
          'Aislar la raíz y elevar al cuadrado',
          'f(x) ${s.latex} 0',
          'Con varios radicales se exige el dominio de cada uno, se aísla una raíz y se eleva al cuadrado cuidando el signo de ambos miembros. Aquí se estudia directamente el signo de f(x).',
        ),
      ];
    }
    final other = rootLeft ? r : l;
    final sg = rootLeft ? s : s.flipped();
    final f = root.rad.latex();
    final k = _const(other);
    final head = '\\sqrt{$f} ${sg.latex} ${other.latex()}';
    final domain = _st(
      'Dominio de la raíz',
      '$f \\ge 0',
      'Una raíz cuadrada solo existe si el radicando es mayor o igual que 0. La solución final debe estar dentro de este dominio.',
    );
    if (k != null) {
      final up = sg == InequalitySign.greater || sg == InequalitySign.greaterOrEqual;
      if (k < 0) {
        return [
          domain,
          _st(
            'Una raíz nunca es negativa',
            '$head \\iff ${up ? '\\text{se cumple en todo el dominio}' : '\\text{ningun valor lo cumple}'}',
            up
                ? 'La raíz es siempre mayor o igual que 0, y el segundo miembro es negativo: la desigualdad se cumple en todo el dominio.'
                : 'La raíz es siempre mayor o igual que 0 y no puede ser menor que un número negativo: no hay solución.',
          ),
        ];
      }
      return [
        domain,
        _st(
          'Elevar al cuadrado (ambos miembros no negativos)',
          '$head \\iff $f ${sg.latex} ${_k(k * k)}',
          'Como la raíz y ${_k(k)} no son negativos, elevar al cuadrado conserva el sentido. Después se intersecta con el dominio.',
          'Si el segundo miembro fuera negativo habría que analizar el signo antes de elevar.',
        ),
      ];
    }
    final g = other.latex();
    final up = sg == InequalitySign.greater || sg == InequalitySign.greaterOrEqual;
    final gSign = sg == InequalitySign.lessOrEqual ? '\\ge' : '>';
    return [
      domain,
      _st(
        'Estudiar el signo del segundo miembro',
        up
            ? '\\begin{cases} $g < 0 & \\text{se cumple en todo el dominio} \\\\ $g \\ge 0 & $f ${sg.latex} \\left($g\\right)^{2} \\end{cases}'
            : '\\begin{cases} $f \\ge 0 \\\\ $g $gSign 0 \\\\ $f ${sg.latex} \\left($g\\right)^{2} \\end{cases}',
        up
            ? 'Si el segundo miembro es negativo, la raíz (siempre no negativa) lo supera. Si es no negativo, se eleva al cuadrado. La solución es la unión de ambos casos dentro del dominio.'
            : 'Para que la raíz sea menor que el segundo miembro, este debe ser positivo; entonces se eleva al cuadrado. Se intersectan las tres condiciones.',
        'Elevar al cuadrado solo es válido cuando ambos miembros son no negativos.',
      ),
    ];
  }

  // ------------------------------------------------------------- logaritmos
  static double? _logBase(XFn f) {
    if (f.name == 'ln') return 2.718281828459045;
    if (f.base == null) return 10;
    return _const(f.base!);
  }

  static List<MathStep> _log(XNode l, XNode r, InequalitySign s) {
    final fl = l is XFn && (l.name == 'ln' || l.name == 'log') && _hasX(l.arg) ? l : null;
    final fr = r is XFn && (r.name == 'ln' || r.name == 'log') && _hasX(r.arg) ? r : null;
    final main = fl ?? fr;
    if (main == null) {
      return [
        _st(
          'Dominio estricto de los logaritmos',
          'f(x) ${s.latex} 0',
          'Cada argumento de un logaritmo debe ser estrictamente mayor que 0. Se estudia el signo de f(x) dentro de ese dominio.',
        ),
      ];
    }
    final a = _logBase(main);
    final reverse = a != null && a > 0 && a < 1;
    final name = main.name == 'ln' ? '\\ln' : (main.base == null ? '\\log' : '\\log_{${main.base!.latex()}}');
    final baseLatex = main.name == 'ln' ? 'e' : (main.base == null ? '10' : main.base!.latex());
    final dom = _st(
      'Dominio estricto',
      [
        if (fl != null) '${fl.arg.latex()} > 0',
        if (fr != null) '${fr.arg.latex()} > 0',
      ].join(r' \;\text{y}\; '),
      'El argumento de un logaritmo debe ser estrictamente mayor que 0: aquí el signo igual no vale nunca.',
    );
    final note = reverse
        ? 'La base está entre 0 y 1, así que el logaritmo es decreciente: al quitar el logaritmo se invierte el sentido de la desigualdad.'
        : 'La base es mayor que 1, así que el logaritmo es creciente: al quitarlo se conserva el sentido de la desigualdad.';
    final warn = 'Después de resolver hay que intersectar con el dominio.';
    if (fl != null && fr != null) {
      final sg = reverse ? s.flipped() : s;
      return [
        dom,
        _st('Quitar los logaritmos', '$name\\left(${fl.arg.latex()}\\right) ${s.latex} $name\\left(${fr.arg.latex()}\\right) \\iff ${fl.arg.latex()} ${sg.latex} ${fr.arg.latex()}', note, warn),
      ];
    }
    final other = fl != null ? r : l;
    final sg0 = fl != null ? s : s.flipped();
    final k = _const(other);
    final sg = reverse ? sg0.flipped() : sg0;
    if (k == null) {
      return [dom, _st('Propiedades de los logaritmos', 'f(x) ${s.latex} 0', 'Se agrupan los logaritmos con sus propiedades y se estudia el signo de f(x) en el dominio.', warn)];
    }
    return [
      dom,
      _st(
        'Pasar a forma exponencial',
        '$name\\left(${main.arg.latex()}\\right) ${sg0.latex} ${_k(k)} \\iff ${main.arg.latex()} ${sg.latex} $baseLatex^{${_k(k)}}',
        note,
        warn,
      ),
    ];
  }

  // ----------------------------------------------------------- exponenciales
  static XPow? _expPow(XNode n) => n is XPow && _hasX(n.exp) && !_hasX(n.base) ? n : null;

  static List<MathStep> _exp(XNode l, XNode r, InequalitySign s) {
    final pl = _expPow(l), pr = _expPow(r);
    final main = pl ?? pr;
    if (main == null) {
      return [_st('Estudio de la función exponencial', 'f(x) ${s.latex} 0', 'Se estudia el signo de f(x) con sus ceros.')];
    }
    final a = _const(main.base);
    final reverse = a != null && a > 0 && a < 1;
    final aLatex = main.base.latex();
    final note = reverse
        ? 'La base está entre 0 y 1: la exponencial es decreciente y al comparar exponentes se invierte el sentido de la desigualdad.'
        : 'La base es mayor que 1: la exponencial es creciente y al comparar exponentes se conserva el sentido de la desigualdad.';
    if (pl != null && pr != null && _const(pl.base) == _const(pr.base)) {
      final sg = reverse ? s.flipped() : s;
      return [_st('Igualar las bases', '$aLatex^{${pl.exp.latex()}} ${s.latex} $aLatex^{${pr.exp.latex()}} \\iff ${pl.exp.latex()} ${sg.latex} ${pr.exp.latex()}', note)];
    }
    final other = pl != null ? r : l;
    final sg0 = pl != null ? s : s.flipped();
    final k = _const(other);
    if (k == null) {
      return [
        _st(
          'Cambio de variable o estudio de signos',
          'f(x) ${s.latex} 0',
          'Si aparece a elevado a x y a elevado a 2x se hace t = a^x con t > 0 y se resuelve la cuadrática en t. Aquí se estudia el signo de f(x) y sus ceros.',
          'Una exponencial siempre es positiva: t = a^x nunca puede valer 0 ni ser negativo.',
        ),
      ];
    }
    if (k <= 0) {
      final up = sg0 == InequalitySign.greater || sg0 == InequalitySign.greaterOrEqual;
      return [
        _st(
          'Una exponencial es siempre positiva',
          '$aLatex^{${main.exp.latex()}} > 0 \\ge ${_k(k)}',
          up ? 'Como a^f(x) siempre es positivo, es mayor que un número negativo o cero: se cumple para todo x del dominio.' : 'Como a^f(x) siempre es positivo, nunca puede ser menor o igual que un número negativo o cero: no hay solución.',
        ),
      ];
    }
    final sg = reverse ? sg0.flipped() : sg0;
    return [
      _st(
        'Aplicar logaritmos',
        '$aLatex^{${main.exp.latex()}} ${sg0.latex} ${_k(k)} \\iff ${main.exp.latex()} ${sg.latex} \\log_{$aLatex}\\left(${_k(k)}\\right)',
        note,
        'Si el segundo miembro es 0 o negativo, no se pueden tomar logaritmos: analiza el signo antes.',
      ),
    ];
  }

  // ---------------------------------------------------------- valor absoluto
  static List<MathStep> _abs(XNode l, XNode r, InequalitySign s) {
    final al = l is XAbs && _hasX(l.a) ? l : null;
    final ar = r is XAbs && _hasX(r.a) ? r : null;
    if (al != null && ar != null) {
      return [
        _st(
          'Dos valores absolutos',
          '\\left|${al.a.latex()}\\right| ${s.latex} \\left|${ar.a.latex()}\\right| \\iff \\left(${al.a.latex()}\\right)^{2} ${s.latex} \\left(${ar.a.latex()}\\right)^{2}',
          'Con valores absolutos a ambos lados se elevan al cuadrado los dos miembros, porque los dos son no negativos.',
        ),
      ];
    }
    final main = al ?? ar;
    if (main == null) {
      return [_st('Desdoblar por casos', 'f(x) ${s.latex} 0', 'Cada valor absoluto cambia de expresión en sus ceros: se estudia el signo en cada intervalo.')];
    }
    final other = al != null ? r : l;
    final sg = al != null ? s : s.flipped();
    final f = main.a.latex(), g = other.latex();
    final low = sg == InequalitySign.less || sg == InequalitySign.lessOrEqual;
    final e = sg == InequalitySign.lessOrEqual || sg == InequalitySign.greaterOrEqual;
    final cmp = e ? '\\le' : '<';
    final cmpUp = e ? '\\ge' : '>';
    return [
      _st(
        'Desdoblar el valor absoluto',
        low
            ? '\\left|$f\\right| ${sg.latex} $g \\iff -\\left($g\\right) $cmp $f $cmp $g'
            : '\\left|$f\\right| ${sg.latex} $g \\iff $f $cmpUp $g \\;\\text{o}\\; $f ${e ? '\\le' : '<'} -\\left($g\\right)',
        low
            ? 'Un valor absoluto es menor que g cuando la expresión de dentro queda entre -g y g. Si g es negativo no hay solución.'
            : 'Un valor absoluto es mayor que g cuando la expresión de dentro supera g o es menor que -g. Si g es negativo se cumple siempre.',
        'Comprueba siempre el signo de g: con g negativo el resultado es distinto.',
      ),
    ];
  }
}
