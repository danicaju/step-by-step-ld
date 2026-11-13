import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../parser/expression_parser.dart';
import 'quadratic_solver.dart';

/// Polinomio exacto con coeficientes racionales ordenado de grado `0` a `N`.
class _RationalPoly {
  final List<Rational> coeffs; // coeffs[i] es coeficiente de x^i

  _RationalPoly(List<Rational> raw) : coeffs = _trim(raw);

  factory _RationalPoly.zero() => _RationalPoly(const []);

  factory _RationalPoly.constant(Rational c) =>
      c.isZero ? _RationalPoly.zero() : _RationalPoly([c]);

  factory _RationalPoly.x() => _RationalPoly([Rational(0), Rational(1)]);

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

  _RationalPoly operator +(_RationalPoly other) {
    final len = coeffs.length > other.coeffs.length
        ? coeffs.length
        : other.coeffs.length;
    final out = List<Rational>.generate(len, (i) => at(i) + other.at(i));
    return _RationalPoly(out);
  }

  _RationalPoly operator -(_RationalPoly other) {
    final len = coeffs.length > other.coeffs.length
        ? coeffs.length
        : other.coeffs.length;
    final out = List<Rational>.generate(len, (i) => at(i) - other.at(i));
    return _RationalPoly(out);
  }

  _RationalPoly operator -() =>
      _RationalPoly(coeffs.map((c) => -c).toList());

  _RationalPoly operator *(_RationalPoly other) {
    if (coeffs.isEmpty || other.coeffs.isEmpty) return _RationalPoly.zero();
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
    return _RationalPoly(out);
  }

  _RationalPoly scale(Rational k) {
    if (k.isZero || coeffs.isEmpty) return _RationalPoly.zero();
    return _RationalPoly(coeffs.map((c) => c * k).toList());
  }

  _RationalPoly divideByScalar(Rational k) {
    if (k.isZero) {
      throw const FormatException('División por cero en la ecuación.');
    }
    return _RationalPoly(coeffs.map((c) => c / k).toList());
  }

  _RationalPoly powInt(int exp) {
    if (exp < 0) {
      throw const FormatException(
        'No se admiten exponentes negativos sobre la incógnita.',
      );
    }
    if (exp == 0) return _RationalPoly.constant(Rational(1));
    var res = _RationalPoly.constant(Rational(1));
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

sealed class _EqAstNode {
  const _EqAstNode();
}

class _NumAst extends _EqAstNode {
  final Rational value;
  const _NumAst(this.value);
}

class _VarAst extends _EqAstNode {
  const _VarAst();
}

class _UnaryNegAst extends _EqAstNode {
  final _EqAstNode inner;
  const _UnaryNegAst(this.inner);
}

class _ParenAst extends _EqAstNode {
  final _EqAstNode inner;
  const _ParenAst(this.inner);
}

class _BinAst extends _EqAstNode {
  final String op; // +, -, *, /, ^
  final _EqAstNode left;
  final _EqAstNode right;
  const _BinAst(this.op, this.left, this.right);
}

/// Motor unificado de resolución paso a paso para ecuaciones polinómicas
/// de **1.º y 2.º grado** en forma libre o desordenada (Modo 2).
///
/// Soporta fracciones algebraicas (`(x-1)/2 + 3 = x`), paréntesis anidados,
/// identidades y potencias (`(x+1)^2 = 2x+5`), y términos desordenados en
/// ambos miembros (`2x^2 - 4x = x^2 - 3`, `5x = 2x^2`).
///
/// Flujo algebraico exacto:
/// 1. Limpieza de denominadores multiplicando por el `m.c.m.`.
/// 2. Desarrollo de paréntesis, distributiva y potencias.
/// 3. Reducción de términos semejantes y transposición al primer miembro (`= 0`).
/// 4. Clasificación automática del grado resultante:
///    - Si $A = 0$: resuelve limpiamente como ecuación de 1.º grado (`sin 0x` ni `1x`).
///    - Si $A \ne 0$: delega en [QuadraticEquationSolver] conservando los pasos previos.
class PolynomialEquationSolver {
  /// Resuelve cualquier ecuación de 1.º o 2.º grado escrita libremente como texto.
  static StepByStepResolution solveEquationString(String rawEquation) {
    final normalized = _normalizeInput(rawEquation);
    final eqParts = normalized.split('=');
    if (eqParts.length != 2 ||
        eqParts[0].trim().isEmpty ||
        eqParts[1].trim().isEmpty) {
      throw const FormatException(
        'La ecuación debe tener exactamente dos miembros separados por "=" '
        '(ej. 2x^2 - 4x = x^2 - 3 o (x-1)/2 + 3 = x).',
      );
    }

    final leftRaw = eqParts[0].trim();
    final rightRaw = eqParts[1].trim();
    final originalLatex =
        '${ExpressionParser.rawToLiveLatex(leftRaw)} = ${ExpressionParser.rawToLiveLatex(rightRaw)}';

    final leftAst = _EqSideParser(leftRaw).parse();
    final rightAst = _EqSideParser(rightRaw).parse();

    final denominators = <int>[];
    bool hasParensOrPowers = _containsParensOrPowers(leftAst) ||
        _containsParensOrPowers(rightAst);
    bool hasMinusBeforeFraction = _containsMinusBeforeFraction(leftAst) ||
        _containsMinusBeforeFraction(rightAst);

    _collectConstantDenominators(leftAst, denominators);
    _collectConstantDenominators(rightAst, denominators);

    final steps = <MathStep>[];
    String lastEquationLatex = originalLatex;

    void addStepIfNew({
      required String shortTitle,
      required String latexExpression,
      required String pedagogicalNote,
      String? warningTrick,
    }) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: shortTitle,
          latexExpression: latexExpression,
          pedagogicalNote: pedagogicalNote,
          warningTrick: warningTrick,
        ),
      );
      lastEquationLatex = latexExpression;
    }

    _RationalPoly leftPoly = _evalAst(leftAst);
    _RationalPoly rightPoly = _evalAst(rightAst);

    // 1. Eliminar denominadores mediante el m.c.m. si existen fracciones numéricas
    final uniqueDenoms = denominators.where((d) => d > 1).toSet().toList();
    if (uniqueDenoms.isNotEmpty) {
      final lcm = Rational.lcmMany(uniqueDenoms);
      final leftClearedLatex = _formatClearedSide(leftAst, lcm);
      final rightClearedLatex = _formatClearedSide(rightAst, lcm);
      final clearedLatex = '$leftClearedLatex = $rightClearedLatex';
      final lcmStr = uniqueDenoms.length == 1
          ? '$lcm'
          : 'm.c.m.(${uniqueDenoms.join(', ')}) = $lcm';

      addStepIfNew(
        shortTitle: 'Eliminar denominadores ($lcmStr)',
        latexExpression: clearedLatex,
        pedagogicalNote:
            'Multiplicamos todos los términos de ambos miembros por $lcmStr para eliminar las fracciones.',
        warningTrick: hasMinusBeforeFraction
            ? 'El signo menos delante de la fracción afecta a todos los términos del numerador al quitar el denominador.'
            : null,
      );

      leftPoly = leftPoly.scale(Rational(lcm));
      rightPoly = rightPoly.scale(Rational(lcm));
    }

    // 2. Desarrollar paréntesis, distributiva y potencias (si cambia la expresión)
    final leftExpandedLatex = leftPoly.toLatex();
    final rightExpandedLatex = rightPoly.toLatex();
    final expandedLatex = '$leftExpandedLatex = $rightExpandedLatex';
    if (hasParensOrPowers && expandedLatex != lastEquationLatex) {
      addStepIfNew(
        shortTitle: 'Desarrollar paréntesis y potencias',
        latexExpression: expandedLatex,
        pedagogicalNote:
            'Aplicamos las identidades notables / propiedad distributiva y reducimos términos en cada miembro.',
      );
    }

    // 3. Diferencia LHS - RHS para determinar el grado real
    _RationalPoly diff = leftPoly - rightPoly;

    if (diff.degree > 2) {
      throw const FormatException(
        'Solo se admiten ecuaciones polinómicas de 1.º o 2.º grado (grado máximo x²).',
      );
    }

    // Escalar por el m.c.m. de coeficientes racionales si hubiera decimales (ej. 0.5x = 2)
    final residualDens =
        diff.coeffs.map((c) => c.denominator).where((d) => d > 1).toList();
    if (residualDens.isNotEmpty) {
      final scale = Rational.lcmMany(residualDens);
      diff = diff.scale(Rational(scale));
    }

    final int a = diff.at(2).numerator;
    final int b = diff.at(1).numerator;
    final int c = diff.at(0).numerator;

    // 4. Rama automática: A == 0 -> Ecuación de 1.º grado
    if (a == 0) {
      return _solveLinearFromCoeffs(
        b: b,
        c: c,
        originalLatex: originalLatex,
        prefixSteps: steps,
        lastEquationLatex: lastEquationLatex,
      );
    }

    // 5. Rama automática: A != 0 -> Ecuación de 2.º grado
    final bool needsFlip = a < 0;
    final int aNorm = needsFlip ? -a : a;
    final int bNorm = needsFlip ? -b : b;
    final int cNorm = needsFlip ? -c : c;

    final canonicalLeft =
        AlgebraicLatexFormatter.quadraticExpression(aNorm, bNorm, cNorm);
    final canonicalEqLatex = '$canonicalLeft = 0';

    if (canonicalEqLatex != lastEquationLatex || steps.isEmpty) {
      addStepIfNew(
        shortTitle: 'Transponer al primer miembro e igualar a cero',
        latexExpression: canonicalEqLatex,
        pedagogicalNote: needsFlip
            ? 'Pasamos todos los términos a un lado agrupando x², x y números, y cambiamos de signo para dejar positivo el coeficiente principal a = $aNorm.'
            : 'Pasamos todos los términos al primer miembro reduciendo términos semejantes para obtener la forma general Ax² + Bx + C = 0.',
      );
    }

    final quadRes = QuadraticEquationSolver.solve(
      a: aNorm,
      b: bNorm,
      c: cNorm,
    );

    final mergedSteps = <MathStep>[...steps];
    for (final qStep in quadRes.steps) {
      mergedSteps.add(
        MathStep(
          index: mergedSteps.length + 1,
          shortTitle: qStep.shortTitle,
          latexExpression: qStep.latexExpression,
          pedagogicalNote: qStep.pedagogicalNote,
          warningTrick: qStep.warningTrick,
        ),
      );
    }

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: mergedSteps,
      exactResultLatex: quadRes.exactResultLatex,
      decimalApproxLatex: quadRes.decimalApproxLatex,
    );
  }

  static StepByStepResolution _solveLinearFromCoeffs({
    required int b,
    required int c,
    required String originalLatex,
    required List<MathStep> prefixSteps,
    required String lastEquationLatex,
  }) {
    final steps = <MathStep>[...prefixSteps];

    if (b == 0) {
      final isIdentity = c == 0;
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle:
              isIdentity ? 'Identidad (infinitas soluciones)' : 'Ecuación incompatible',
          latexExpression: isIdentity
              ? '0 = 0 \\implies x \\in \\mathbb{R}'
              : '0 = ${-c} \\implies \\text{Sin solucion}',
          pedagogicalNote: isIdentity
              ? 'Al simplificar se anulan todas las incógnitas y queda 0 = 0: cualquier valor real de x cumple la igualdad.'
              : 'Al simplificar se anulan las x y queda una igualdad falsa (0 = ${-c}): no existe solución.',
        ),
      );
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: isIdentity
            ? r'x \in \mathbb{R} \; (\text{Infinitas soluciones})'
            : r'\text{Sin solucion}',
        decimalApproxLatex: isIdentity ? r'x \in \mathbb{R}' : r'\nexists x',
      );
    }

    // b*x = -c (sin escribir 1x ni 0x)
    final rhsInt = -c;
    final leftTermLatex = AlgebraicLatexFormatter.monomialTerm(
      b,
      'x',
      isFirst: true,
    );
    final groupedLatex = '$leftTermLatex = $rhsInt';
    final alreadyGrouped = groupedLatex == lastEquationLatex;
    final sol = Rational(rhsInt, b);

    if (b == 1 && alreadyGrouped && steps.isEmpty) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Solución directa',
          latexExpression: groupedLatex,
          pedagogicalNote:
              'La incógnita x ya está despejada directamente en el primer miembro.',
        ),
      );
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: 'x = ${sol.toLatex()}',
        decimalApproxLatex: 'x \\approx ${sol.toDecimalLatex()}',
      );
    }

    if (!alreadyGrouped) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Agrupar incógnitas y términos independientes',
          latexExpression: groupedLatex,
          pedagogicalNote:
              'Pasamos los términos con x al primer miembro y los números al segundo cambiando el signo al cruzar el "=".',
        ),
      );
    }

    final prefixIfDirect =
        alreadyGrouped && steps.isEmpty ? '$groupedLatex \\implies ' : '';

    if (b == -1) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Despejar x cambiando el signo',
          latexExpression: '${prefixIfDirect}x = ${sol.toLatex()}',
          pedagogicalNote:
              'Multiplicamos ambos miembros por -1 para dejar la x positiva.',
        ),
      );
    } else if (b != 1) {
      final bool isExactInt = rhsInt % b == 0;
      final bool isSimplified = Rational.gcd(rhsInt, b) > 1 && !isExactInt;
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Despejar la incógnita x',
          latexExpression:
              '${prefixIfDirect}x = \\frac{$rhsInt}{$b}'
              '${isExactInt || isSimplified || b < 0 ? ' = ${sol.toLatex()}' : ''}',
          pedagogicalNote:
              'El coeficiente $b que multiplica a x pasa al otro miembro dividiendo'
              '${sol.toLatex() != '\\frac{$rhsInt}{$b}' ? ' y simplificamos al máximo.' : '.'}',
          warningTrick: b < 0
              ? 'Al pasar dividiendo $b (negativo) no cambia de signo; mantiene su signo en el denominador.'
              : null,
        ),
      );
    }

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: 'x = ${sol.toLatex()}',
      decimalApproxLatex: 'x \\approx ${sol.toDecimalLatex()}',
    );
  }

  static String _normalizeInput(String raw) {
    var s = raw
        .trim()
        .replaceAll('\uE000', '')
        .replaceAll('−', '-')
        .replaceAll('·', '*')
        .replaceAll('×', '*')
        .replaceAll(r'\cdot', '*')
        .replaceAll(r'\times', '*')
        .replaceAll(r'\left', '')
        .replaceAll(r'\right', '')
        .replaceAll('X', 'x');

    // Convertir \frac{num}{den} -> (num)/(den) y frac(num,den) -> (num)/(den)
    while (s.contains(r'\frac{')) {
      final idx = s.indexOf(r'\frac{');
      final numOpen = idx + 5;
      final numClose = _findMatchingDelim(s, numOpen, '{', '}');
      if (numClose == -1 ||
          numClose + 1 >= s.length ||
          s[numClose + 1] != '{') {
        throw const FormatException('Fracción LaTeX mal formada.');
      }
      final denOpen = numClose + 1;
      final denClose = _findMatchingDelim(s, denOpen, '{', '}');
      if (denClose == -1) {
        throw const FormatException('Fracción LaTeX mal formada.');
      }
      final numInner = s.substring(numOpen + 1, numClose);
      final denInner = s.substring(denOpen + 1, denClose);
      s = '${s.substring(0, idx)}($numInner)/($denInner)${s.substring(denClose + 1)}';
    }

    s = s
        .replaceAll('²', '^2')
        .replaceAll('³', '^3')
        .replaceAll('{', '(')
        .replaceAll('}', ')');
    return s;
  }

  static int _findMatchingDelim(
    String s,
    int openIdx,
    String openCh,
    String closeCh,
  ) {
    int depth = 1;
    for (int i = openIdx + 1; i < s.length; i++) {
      if (s[i] == openCh) depth++;
      if (s[i] == closeCh) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  static bool _containsParensOrPowers(_EqAstNode node) => switch (node) {
        _ParenAst() => true,
        _UnaryNegAst(:final inner) => _containsParensOrPowers(inner),
        _BinAst(:final op, :final left, :final right) =>
          (op == '^' && left is! _VarAst) ||
              (op == '*' && (left is _ParenAst || right is _ParenAst)) ||
              _containsParensOrPowers(left) ||
              _containsParensOrPowers(right),
        _ => false,
      };

  static bool _containsMinusBeforeFraction(_EqAstNode node) => switch (node) {
        _UnaryNegAst(:final inner) => _containsFraction(inner) ||
            _containsMinusBeforeFraction(inner),
        _ParenAst(:final inner) => _containsMinusBeforeFraction(inner),
        _BinAst(:final op, :final left, :final right) =>
          (op == '-' && _containsFraction(right)) ||
              _containsMinusBeforeFraction(left) ||
              _containsMinusBeforeFraction(right),
        _ => false,
      };

  static bool _containsFraction(_EqAstNode node) => switch (node) {
        _BinAst(:final op, :final left, :final right) =>
          op == '/' || _containsFraction(left) || _containsFraction(right),
        _ParenAst(:final inner) => _containsFraction(inner),
        _UnaryNegAst(:final inner) => _containsFraction(inner),
        _ => false,
      };

  static void _collectConstantDenominators(
    _EqAstNode node,
    List<int> out,
  ) {
    switch (node) {
      case _BinAst(:final op, :final left, :final right):
        if (op == '/') {
          final denPoly = _evalAst(right);
          if (!denPoly.isConstant || denPoly.at(0).isZero) {
            throw const FormatException(
              'Los denominadores no pueden contener la incógnita x ni ser cero.',
            );
          }
          final d = denPoly.at(0);
          if (d.denominator == 1) {
            final absVal = d.numerator.abs();
            if (absVal > 1) out.add(absVal);
          } else {
            out.add(d.numerator.abs());
          }
        }
        _collectConstantDenominators(left, out);
        _collectConstantDenominators(right, out);
      case _UnaryNegAst(:final inner):
        _collectConstantDenominators(inner, out);
      case _ParenAst(:final inner):
        _collectConstantDenominators(inner, out);
      case _NumAst():
      case _VarAst():
        break;
    }
  }

  static _RationalPoly _evalAst(_EqAstNode node) => switch (node) {
        _NumAst(:final value) => _RationalPoly.constant(value),
        _VarAst() => _RationalPoly.x(),
        _UnaryNegAst(:final inner) => -_evalAst(inner),
        _ParenAst(:final inner) => _evalAst(inner),
        _BinAst(:final op, :final left, :final right) => switch (op) {
            '+' => _evalAst(left) + _evalAst(right),
            '-' => _evalAst(left) - _evalAst(right),
            '*' => _evalAst(left) * _evalAst(right),
            '/' => () {
                final den = _evalAst(right);
                if (!den.isConstant) {
                  throw const FormatException(
                    'No se admite la incógnita x en el denominador.',
                  );
                }
                return _evalAst(left).divideByScalar(den.at(0));
              }(),
            '^' => () {
                final expPoly = _evalAst(right);
                if (!expPoly.isConstant || expPoly.at(0).denominator != 1) {
                  throw const FormatException(
                    'El exponente debe ser un número entero no negativo.',
                  );
                }
                return _evalAst(left).powInt(expPoly.at(0).numerator);
              }(),
            _ => throw FormatException('Operador desconocido: $op'),
          },
      };

  static String _formatClearedSide(_EqAstNode node, int lcm) {
    final pieces = <({bool isNeg, _EqAstNode node})>[];
    _flattenAdditive(node, false, pieces);
    if (pieces.isEmpty) return '0';

    final buf = StringBuffer();
    for (int i = 0; i < pieces.length; i++) {
      final item = pieces[i];
      final termLatex = _formatClearedPiece(
        item.node,
        lcm,
        leadNeg: item.isNeg,
        isFirst: i == 0,
      );
      buf.write(termLatex);
    }
    return buf.toString();
  }

  static void _flattenAdditive(
    _EqAstNode node,
    bool flipSign,
    List<({bool isNeg, _EqAstNode node})> out,
  ) {
    switch (node) {
      case _BinAst(op: '+', :final left, :final right):
        _flattenAdditive(left, flipSign, out);
        _flattenAdditive(right, flipSign, out);
      case _BinAst(op: '-', :final left, :final right):
        _flattenAdditive(left, flipSign, out);
        _flattenAdditive(right, !flipSign, out);
      case _UnaryNegAst(:final inner):
        _flattenAdditive(inner, !flipSign, out);
      default:
        out.add((isNeg: flipSign, node: node));
    }
  }

  static String _formatClearedPiece(
    _EqAstNode node,
    int lcm, {
    required bool leadNeg,
    required bool isFirst,
  }) {
    if (node is _BinAst && node.op == '/') {
      final denPoly = _evalAst(node.right);
      final denVal = denPoly.at(0);
      final factor = (Rational(lcm) / denVal);
      final numPoly = (_evalAst(node.left) *
              _RationalPoly.constant(leadNeg ? -factor : factor))
          .toLatex();
      if (isFirst) return numPoly;
      if (numPoly.startsWith('-')) return ' - ${numPoly.substring(1)}';
      return ' + $numPoly';
    }

    final poly = _evalAst(node).scale(Rational(leadNeg ? -lcm : lcm));
    final latex = poly.toLatex();
    if (isFirst) return latex;
    if (latex.startsWith('-')) return ' - ${latex.substring(1)}';
    return ' + $latex';
  }
}

class _EqSideParser {
  final List<_EqToken> _tokens;
  int _pos = 0;

  _EqSideParser(String input) : _tokens = _tokenize(input);

  static List<_EqToken> _tokenize(String src) {
    final cleaned = src.replaceAll(' ', '');
    final rawTokens = <_EqToken>[];
    int i = 0;
    while (i < cleaned.length) {
      final ch = cleaned[i];
      if (ch == 'x' || ch == 'X') {
        rawTokens.add(const _EqToken(_EqTokenType.variable, 'x'));
        i++;
      } else if (RegExp(r'[0-9.]').hasMatch(ch)) {
        final start = i;
        while (i < cleaned.length && RegExp(r'[0-9.]').hasMatch(cleaned[i])) {
          i++;
        }
        rawTokens.add(_EqToken(_EqTokenType.number, cleaned.substring(start, i)));
      } else if ('+-*/^()'.contains(ch)) {
        rawTokens.add(_EqToken(_EqTokenType.op, ch));
        i++;
      } else {
        throw FormatException('Símbolo no válido en ecuación: "$ch"');
      }
    }

    // Insertar multiplicación implícita `*` entre:
    // - número seguido de `x` o `(`
    // - `x` seguido de `x`, número o `(`
    // - `)` seguido de número, `x` o `(`
    final out = <_EqToken>[];
    for (int j = 0; j < rawTokens.length; j++) {
      final cur = rawTokens[j];
      if (out.isNotEmpty) {
        final prev = out.last;
        final prevEndsOperand = prev.type == _EqTokenType.number ||
            prev.type == _EqTokenType.variable ||
            prev.value == ')';
        final curStartsOperand = cur.type == _EqTokenType.number ||
            cur.type == _EqTokenType.variable ||
            cur.value == '(';
        if (prevEndsOperand && curStartsOperand) {
          out.add(const _EqToken(_EqTokenType.op, '*'));
        }
      }
      out.add(cur);
    }
    return out;
  }

  _EqToken? get _cur => _pos < _tokens.length ? _tokens[_pos] : null;

  _EqAstNode parse() {
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

  _EqAstNode _parseAddSub() {
    var node = _parseMulDiv();
    while (_cur?.value == '+' || _cur?.value == '-') {
      final op = _tokens[_pos++].value;
      final right = _parseMulDiv();
      node = _BinAst(op, node, right);
    }
    return node;
  }

  _EqAstNode _parseMulDiv() {
    var node = _parseUnary();
    while (_cur?.value == '*' || _cur?.value == '/') {
      final op = _tokens[_pos++].value;
      final right = _parseUnary();
      node = _BinAst(op, node, right);
    }
    return node;
  }

  _EqAstNode _parseUnary() {
    if (_cur?.value == '-') {
      _pos++;
      return _UnaryNegAst(_parseUnary());
    }
    if (_cur?.value == '+') {
      _pos++;
      return _parseUnary();
    }
    return _parsePower();
  }

  _EqAstNode _parsePower() {
    var base = _parsePrimary();
    if (_cur?.value == '^') {
      _pos++;
      final exp = _parseUnary();
      return _BinAst('^', base, exp);
    }
    return base;
  }

  _EqAstNode _parsePrimary() {
    final tok = _cur;
    if (tok == null) {
      throw const FormatException('Se esperaba un número, "x" o paréntesis.');
    }
    if (tok.type == _EqTokenType.number) {
      _pos++;
      final raw = tok.value;
      if (raw == '.') {
        throw const FormatException('Número decimal incompleto.');
      }
      final r = raw.contains('.')
          ? Rational.fromDecimalString(raw)
          : Rational(int.parse(raw));
      return _NumAst(r);
    }
    if (tok.type == _EqTokenType.variable) {
      _pos++;
      return const _VarAst();
    }
    if (tok.value == '(') {
      _pos++;
      final inner = _parseAddSub();
      if (_cur?.value != ')') {
        throw const FormatException('Falta cerrar un paréntesis ")".');
      }
      _pos++;
      return _ParenAst(inner);
    }
    throw FormatException('Token inesperado: "${tok.value}"');
  }
}

enum _EqTokenType { number, variable, op }

class _EqToken {
  final _EqTokenType type;
  final String value;
  const _EqToken(this.type, this.value);
}
