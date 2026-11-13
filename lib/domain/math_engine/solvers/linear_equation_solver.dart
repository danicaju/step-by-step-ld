import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';

/// Término de una ecuación lineal: \pm \frac{a x + b}{d}
class LinearTerm {
  final int xCoeff;
  final int constant;
  final int denominator;
  final bool isSubtract;

  const LinearTerm({
    required this.xCoeff,
    required this.constant,
    this.denominator = 1,
    this.isSubtract = false,
  });

  String toLatex() {
    final numStr = AlgebraicLatexFormatter.linearExpression(xCoeff, constant);

    if (denominator == 1) {
      if (isSubtract) {
        if (xCoeff != 0 && constant != 0) return '- ($numStr)';
        if (numStr.startsWith('-')) return '+ ${numStr.substring(1)}';
        return '- $numStr';
      }
      return numStr;
    }
    final signStr = isSubtract ? '- ' : '+ ';
    return '$signStr\\frac{$numStr}{$denominator}';
  }
}

class LinearEquationSolver {

  static String _formatSideLatex(List<LinearTerm> terms) {
    if (terms.isEmpty) return '0';
    final buffer = StringBuffer();
    for (int i = 0; i < terms.length; i++) {
      String part = terms[i].toLatex().trim();
      if (i == 0) {
        if (part.startsWith('+ ')) {
          part = part.substring(2).trimLeft();
        }
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

  static List<String> _buildExpandedSide(
    List<LinearTerm> terms,
    int commonDen,
  ) {
    final parts = <String>[];
    for (int i = 0; i < terms.length; i++) {
      final t = terms[i];
      final factor = commonDen ~/ t.denominator;
      final sign = t.isSubtract ? '-' : (i > 0 ? '+' : '');
      final numExpr = AlgebraicLatexFormatter.linearExpression(t.xCoeff, t.constant);
      final hasTwoTerms = t.xCoeff != 0 && t.constant != 0;
      if (factor == 1) {
        final wrapped = hasTwoTerms ? '($numExpr)' : numExpr;
        parts.add(sign.isEmpty ? wrapped : '$sign $wrapped');
      } else {
        parts.add('$sign \\textcolor{#2563EB}{$factor} \\cdot ($numExpr)'.trimLeft());
      }
    }
    return parts;
  }
  /// Resuelve una ecuación lineal con fracciones y pasos pedagógicos de ESO:
  /// Ejemplo clásico de examen: \frac{x-2}{3} - \frac{x+1}{4} = 2
  static StepByStepResolution solveFractionEquation({
    required List<LinearTerm> leftTerms,
    required List<LinearTerm> rightTerms,
    String? customOriginalLatex,
  }) {
    final originalLatex = customOriginalLatex ??
        '${_formatSideLatex(leftTerms)} = ${_formatSideLatex(rightTerms)}';

    final List<MathStep> steps = [];

    // Recopilar todos los denominadores
    final allDenominators = [
      ...leftTerms.map((t) => t.denominator),
      ...rightTerms.map((t) => t.denominator),
    ].where((d) => d > 1).toList();

    int commonDen = 1;
    if (allDenominators.isNotEmpty) {
      commonDen = allDenominators.reduce((a, b) => Rational.lcm(a, b));
    }

    // Comprobar si hay trampa de signo negativo delante de binomio
    bool hasNegativeFractionWithBinomial = false;
    for (final t in [...leftTerms, ...rightTerms]) {
      if (t.isSubtract && t.denominator > 1 && t.xCoeff != 0 && t.constant != 0) {
        hasNegativeFractionWithBinomial = true;
        break;
      }
    }

    // Paso 1: Quitar denominadores con m.c.m. si commonDen > 1
    if (commonDen > 1) {
      final factLatex = Rational.primeFactorizationLatex(commonDen);

      final leftExpandedParts = _buildExpandedSide(leftTerms, commonDen);
      final rightExpandedParts = _buildExpandedSide(rightTerms, commonDen);

      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Quitar denominadores con el m.c.m.',
          latexExpression:
              '\\begin{aligned} '
              '\\text{m.c.m. de denominadores} = $commonDen \\quad ($commonDen = $factLatex) \\\\[4pt] '
              '${leftExpandedParts.join(' ')} = ${rightExpandedParts.join(' ')} '
              '\\end{aligned}',
          pedagogicalNote:
              'Multiplicamos todos los términos de la ecuación por el m.c.m. ($commonDen) para eliminar las fracciones dividiendo cada factor por su denominador.',
          warningTrick: hasNegativeFractionWithBinomial
              ? 'El signo menos delante de una fracción afecta a todos los términos del numerador: -(A + B)/d → (-A - B)/d.'
              : null,
        ),
      );
    }

    // Multiplicar los factores y operar paréntesis
    int leftTotalX = 0;
    int leftTotalConst = 0;
    for (final t in leftTerms) {
      final factor = commonDen ~/ t.denominator;
      final sign = t.isSubtract ? -1 : 1;
      leftTotalX += sign * factor * t.xCoeff;
      leftTotalConst += sign * factor * t.constant;
    }

    int rightTotalX = 0;
    int rightTotalConst = 0;
    for (final t in rightTerms) {
      final factor = commonDen ~/ t.denominator;
      final sign = t.isSubtract ? -1 : 1;
      rightTotalX += sign * factor * t.xCoeff;
      rightTotalConst += sign * factor * t.constant;
    }

    // Paso 2: Transposición de términos (solo si realmente hay términos que mover)
    final netXLeft = leftTotalX - rightTotalX;
    final netConstRight = rightTotalConst - leftTotalConst;

    final bool needsTransposition =
        rightTotalX != 0 || leftTotalConst != 0 || (leftTotalX == 0 && rightTotalX == 0 && leftTotalConst == 0 && rightTotalConst == 0 ? false : false);
    if (needsTransposition) {
      final xLeftPart = AlgebraicLatexFormatter.monomialTerm(leftTotalX, 'x', isFirst: true);
      final xRightMoved = AlgebraicLatexFormatter.monomialTerm(
        -rightTotalX,
        'x',
        isFirst: leftTotalX == 0,
      );
      final lhsTransposed = '$xLeftPart$xRightMoved'.isEmpty ? '0' : '$xLeftPart$xRightMoved';

      final cRightPart = AlgebraicLatexFormatter.constantTerm(rightTotalConst, isFirst: true);
      final cLeftMoved = AlgebraicLatexFormatter.constantTerm(
        -leftTotalConst,
        isFirst: rightTotalConst == 0,
      );
      final rhsTransposed = '$cRightPart$cLeftMoved'.isEmpty ? '0' : '$cRightPart$cLeftMoved';

      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Transposición de términos',
          latexExpression: '$lhsTransposed = $rhsTransposed',
          pedagogicalNote:
              'Agrupamos los términos con x en el primer miembro y los términos independientes en el segundo miembro, cambiando el signo al cruzar el igual.',
        ),
      );
    }

    // Paso 3: Reducción y Despeje
    if (netXLeft == 0) {
      final isIdentity = netConstRight == 0;
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: isIdentity ? 'Identidad (Infinitas soluciones)' : 'Ecuación incompatible (Sin solución)',
          latexExpression: '0 = $netConstRight',
          pedagogicalNote: isIdentity
              ? 'Cualquier número real satisface la ecuación (0 = 0).'
              : 'Es imposible que 0 sea igual a $netConstRight. La ecuación no tiene solución.',
        ),
      );
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: isIdentity ? r'\text{Infinitas soluciones}' : r'\text{Sin solucion}',
        decimalApproxLatex: isIdentity ? r'\text{Infinitas}' : r'\text{Sin sol}',
      );
    }

    final rawRational = Rational.raw(netConstRight, netXLeft);
    final simplified = rawRational.simplify();
    final String stepLatex;
    final String stepNote;

    if (netXLeft == 1) {
      stepLatex = 'x = ${simplified.toLatex()}';
      stepNote = 'La incógnita x queda despejada directamente sin necesidad de dividir.';
    } else if (netXLeft == -1) {
      stepLatex = '-x = $netConstRight \\implies x = ${simplified.toLatex()}';
      stepNote = 'Multiplicamos ambos miembros por -1 para cambiar el signo de -x a x.';
    } else {
      final lhsTerm = AlgebraicLatexFormatter.monomialTerm(netXLeft, 'x', isFirst: true);
      final unsimplifiedLatex = AlgebraicLatexFormatter.signedFraction(netConstRight, netXLeft);
      final simplifiedLatex = simplified.toLatex();
      stepLatex = unsimplifiedLatex == simplifiedLatex
          ? '$lhsTerm = $netConstRight \\implies x = $simplifiedLatex'
          : '$lhsTerm = $netConstRight \\implies x = $unsimplifiedLatex = $simplifiedLatex';
      stepNote =
          'Dividimos el término independiente entre $netXLeft y simplificamos al máximo cuando es posible.';
    }

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: netXLeft.abs() == 1 && !needsTransposition
            ? 'Solución directa'
            : 'Reducción y despeje de la incógnita x',
        latexExpression: stepLatex,
        pedagogicalNote: stepNote,
      ),
    );

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: 'x = ${simplified.toLatex()}',
      decimalApproxLatex: simplified.toDecimalLatex(),
    );
  }

  /// Preset clásico de ESO con fracciones y trampa de signo:
  /// \frac{x-2}{3} - \frac{x+1}{4} = 2
  static StepByStepResolution solveClassicPreset() {
    return solveFractionEquation(
      leftTerms: const [
        LinearTerm(xCoeff: 1, constant: -2, denominator: 3),
        LinearTerm(xCoeff: 1, constant: 1, denominator: 4, isSubtract: true),
      ],
      rightTerms: const [
        LinearTerm(xCoeff: 0, constant: 2, denominator: 1),
      ],
      customOriginalLatex: r'\frac{x - 2}{3} - \frac{x + 1}{4} = 2',
    );
  }

  /// Ecuación lineal directa sin denominadores: ax + b = cx + d
  static StepByStepResolution solveDirect({
    required int a,
    required int b,
    required int c,
    required int d,
  }) {
    return solveFractionEquation(
      leftTerms: [
        LinearTerm(xCoeff: a, constant: b),
      ],
      rightTerms: [
        LinearTerm(xCoeff: c, constant: d),
      ],
      customOriginalLatex:
          '${a}x ${b >= 0 ? '+ $b' : '- ${b.abs()}'} = ${c}x ${d >= 0 ? '+ $d' : '- ${d.abs()}'}',
    );
  }

  /// Parsea y resuelve una ecuación lineal introducida como texto por el alumno.
  /// Soporta: "2x + 4 = 16", "2*x = 8", "2(x - 3) = 4", "(x-2)/3 - (x+1)/4 = 2", etc.
  static StepByStepResolution solveEquationString(String equationStr) {
    String cleaned = _normalizeEquationInput(equationStr);
    if (cleaned.isEmpty || cleaned == '0') {
      throw const FormatException('Ecuación vacía');
    }
    // Si el usuario aún no ha puesto '=', asumimos '= 0'
    if (!cleaned.contains('=')) {
      cleaned = '$cleaned=0';
    }

    final parts = cleaned.split('=');
    if (parts.length != 2) {
      throw const FormatException('La ecuación debe contener un único signo =');
    }
    if (parts[0].isEmpty || parts[1].isEmpty) {
      throw const FormatException('Completa ambos miembros de la ecuación');
    }

    _checkBalancedParens(parts[0]);
    _checkBalancedParens(parts[1]);

    final leftTerms = _parseLinearTerms(parts[0]);
    final rightTerms = _parseLinearTerms(parts[1]);

    if (leftTerms.isEmpty && rightTerms.isEmpty) {
      throw const FormatException('No se encontraron términos en la ecuación');
    }

    final effectiveLeft = leftTerms.isEmpty
        ? [const LinearTerm(xCoeff: 0, constant: 0)]
        : leftTerms;
    final effectiveRight = rightTerms.isEmpty
        ? [const LinearTerm(xCoeff: 0, constant: 0)]
        : rightTerms;

    return solveFractionEquation(
      leftTerms: effectiveLeft,
      rightTerms: effectiveRight,
      customOriginalLatex:
          '${_formatSideLatex(effectiveLeft)} = ${_formatSideLatex(effectiveRight)}',
    );
  }

  static String _normalizeEquationInput(String raw) {
    var s = raw
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('\u2212', '-')
        .replaceAll(r'\cdot', '*')
        .replaceAll('·', '*')
        .replaceAll('×', '*')
        .replaceAll(r'\left(', '(')
        .replaceAll(r'\right)', ')')
        .replaceAll('X', 'x');
    return _replaceLatexFractions(s);
  }

  static String _replaceLatexFractions(String input) {
    var s = input;
    while (true) {
      final idx = s.indexOf(r'\frac{');
      if (idx == -1) break;
      final numEnd = _findMatchingBrace(s, idx + 5);
      if (numEnd == -1 || numEnd + 1 >= s.length || s[numEnd + 1] != '{') {
        break;
      }
      final denEnd = _findMatchingBrace(s, numEnd + 1);
      if (denEnd == -1) break;
      final numContent = s.substring(idx + 6, numEnd);
      final denContent = s.substring(numEnd + 2, denEnd);
      s = '${s.substring(0, idx)}($numContent)/($denContent)${s.substring(denEnd + 1)}';
    }
    return s;
  }

  static int _findMatchingBrace(String s, int openIdx) {
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

  static void _checkBalancedParens(String s) {
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

  static List<({bool isSubtract, String body})> _splitTopLevelAdditive(
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

  static List<LinearTerm> _parseLinearTerms(String sideStr) {
    final List<LinearTerm> terms = [];
    if (sideStr.isEmpty) return terms;

    for (final (:isSubtract, :body) in _splitTopLevelAdditive(sideStr)) {
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
        final rawDen = _unwrapOuterParens(body.substring(slashIndex + 1));
        final parsedDen = int.tryParse(rawDen);
        if (parsedDen == null || parsedDen <= 0) {
          throw FormatException(
            'El denominador debe ser un entero positivo: $rawDen',
          );
        }
        denominator = parsedDen;
      }

      final parsed = _parseLinearExpr(numeratorStr);
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

  static String _unwrapOuterParens(String s) {
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

  static ({int xCoeff, int constant}) _parseLinearExpr(String expr) {
    final unwrapped = _unwrapOuterParens(expr);
    if (unwrapped.isEmpty) {
      throw const FormatException('Expresión vacía');
    }

    final addTerms = _splitTopLevelAdditive(unwrapped);
    if (addTerms.length > 1 || addTerms.first.isSubtract) {
      int totalX = 0;
      int totalConst = 0;
      for (final (:isSubtract, :body) in addTerms) {
        final sub = _parseLinearProduct(body);
        final sign = isSubtract ? -1 : 1;
        totalX += sign * sub.xCoeff;
        totalConst += sign * sub.constant;
      }
      return (xCoeff: totalX, constant: totalConst);
    }

    return _parseLinearProduct(addTerms.first.body);
  }

  static ({int xCoeff, int constant}) _parseLinearProduct(String term) {
    // Insertar '*' implícito junto a paréntesis: 2(x-1) -> 2*(x-1), (x+1)2 -> (x+1)*2
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
          ? _parseLinearExpr(factor)
          : _parseSingleMonomial(factor);
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

  static ({int xCoeff, int constant}) _parseSingleMonomial(String token) {
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
