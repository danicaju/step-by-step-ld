import 'dart:math' as math;
import '../ast/ast_nodes.dart';
import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import 'logarithm_solver.dart';
import 'percentage_and_sci_solver.dart';
import 'radical_and_factor_solver.dart';
import 'trig_and_angles_solver.dart';

class StepEvaluator {
  final List<MathStep> _steps = [];
  Map<String, Rational> _memoryVariables = const {};
  AngleUnit _angleUnit = AngleUnit.deg;
  Rational? _lastEvaluatedRational;

  Rational? get lastEvaluatedRational => _lastEvaluatedRational;

  StepByStepResolution evaluate(
    ExprNode root, {
    Map<String, Rational>? memoryVariables,
    AngleUnit angleUnit = AngleUnit.deg,
  }) {
    _memoryVariables = memoryVariables ?? const {};
    _angleUnit = angleUnit;

    if (root is SqrtNode && root.radicand is IntNode) {
      return RadicalAndFactorSolver.simplifySquareRoot((root.radicand as IntNode).value);
    }

    // 1. Conversión decimal a DMS (ej: 34.52°)
    if (root is DecimalNode && root.isDegrees) {
      final res = TrigAndAnglesSolver.solveDecimalToDms(
        root.toRational().toDouble(),
        originalLatex: root.rawText.replaceAll('.', ','),
      );
      _lastEvaluatedRational = root.toRational();
      return res;
    }

    // 2. Sistema Sexagesimal puro (sumas y restas DMS)
    final dmsTerms = _tryCollectDmsTerms(root);
    if (dmsTerms != null) {
      final res = TrigAndAnglesSolver.solveDmsOperation(
        originalLatex: root.toLatex(),
        terms: dmsTerms,
      );
      final decTotal = dmsTerms.fold<double>(
        0,
        (acc, t) => acc + (t.isSubtract ? -t.value.toDecimalDegrees() : t.value.toDecimalDegrees()),
      );
      _lastEvaluatedRational = Rational.fromDouble(decTotal, 1000000);
      return res;
    }

    // 3. Trigonometría directa e inversa de nivel ESO / Bachillerato
    if (root is TrigNode) {
      return _evaluateTopLevelTrig(root);
    }

    // 4. Logaritmos de nivel 4.º ESO / Bachillerato
    if (root is LogNode) {
      return _evaluateTopLevelLog(root);
    }

    // 5. Porcentaje directo (A%)
    if (root is PercentNode) {
      final pVal = _evalToRationalQuick(root.operand);
      if (pVal != null) {
        final res = PercentageAndSciSolver.solveStandalonePercent(pVal);
        _lastEvaluatedRational = pVal / Rational(100);
        return res;
      }
    }

    // 6. Operaciones porcentuales y Notación Científica binaria / simple
    if (root is BinaryOpNode) {
      // Aumento / descuento porcentual (B + A% / B - A%)
      if ((root.op == BinaryOperator.add || root.op == BinaryOperator.subtract) &&
          root.right is PercentNode) {
        final baseVal = _evalToRationalQuick(root.left);
        final pctVal = _evalToRationalQuick((root.right as PercentNode).operand);
        if (baseVal != null && pctVal != null) {
          final isDiscount = root.op == BinaryOperator.subtract;
          final iv = isDiscount
              ? Rational(1) - pctVal / Rational(100)
              : Rational(1) + pctVal / Rational(100);
          _lastEvaluatedRational = baseVal * iv;
          return PercentageAndSciSolver.solvePercentageVariation(
            baseValue: baseVal,
            percentValue: pctVal,
            isDiscount: isDiscount,
            originalLatex: root.toLatex(),
          );
        }
      }

      // Porcentaje directo sobre cantidad (B * A% o A% * B)
      if (root.op == BinaryOperator.multiply &&
          (root.right is PercentNode || root.left is PercentNode)) {
        final bool pctOnRight = root.right is PercentNode;
        final pctNode = (pctOnRight ? root.right : root.left) as PercentNode;
        final otherNode = pctOnRight ? root.left : root.right;
        final baseVal = _evalToRationalQuick(otherNode);
        final pctVal = _evalToRationalQuick(pctNode.operand);
        if (baseVal != null && pctVal != null) {
          _lastEvaluatedRational = baseVal * (pctVal / Rational(100));
          return PercentageAndSciSolver.solvePercentOf(
            baseValue: baseVal,
            percentValue: pctVal,
            originalLatex: root.toLatex(),
          );
        }
      }

      // Operación binaria en Notación Científica: (m1 * 10^e1) * / : (m2 * 10^e2)
      if (root.op == BinaryOperator.multiply || root.op == BinaryOperator.divide) {
        final leftSci = PercentageAndSciSolver.tryExtractSciTerm(root.left);
        final rightSci = PercentageAndSciSolver.tryExtractSciTerm(root.right);
        if (leftSci != null && rightSci != null) {
          if (root.op == BinaryOperator.divide && rightSci.mantissa.isZero) {
            return PercentageAndSciSolver.solveScientificBinary(
              left: leftSci,
              op: root.op,
              right: rightSci,
              originalLatex: root.toLatex(),
            );
          }
          final rawMant = root.op == BinaryOperator.multiply
              ? leftSci.mantissa * rightSci.mantissa
              : leftSci.mantissa / rightSci.mantissa;
          final rawExp = root.op == BinaryOperator.multiply
              ? leftSci.exponent + rightSci.exponent
              : leftSci.exponent - rightSci.exponent;
          if (rawExp.abs() <= 8) {
            _lastEvaluatedRational = rawMant * Rational(10).pow(rawExp);
          }
          return PercentageAndSciSolver.solveScientificBinary(
            left: leftSci,
            op: root.op,
            right: rightSci,
            originalLatex: root.toLatex(),
          );
        }
      }
    }

    // Término único en notación científica (ej: 3.2 * 10^-5)
    final singleSci = PercentageAndSciSolver.tryExtractSciTerm(root);
    if (singleSci != null) {
      if (singleSci.exponent.abs() <= 8) {
        _lastEvaluatedRational =
            singleSci.mantissa * Rational(10).pow(singleSci.exponent);
      }
      return PercentageAndSciSolver.solveScientificSingle(
        singleSci,
        originalLatex: root.toLatex(),
      );
    }

    _steps.clear();
    final originalLatex = root.toLatex();

    ExprNode currentTree = root;

    // Reducimos el AST paso a paso hasta que quede un único ResolvedRationalNode o ExactRadicalNode
    int safetyCounter = 0;
    while (currentTree is! ResolvedRationalNode &&
        currentTree is! ExactRadicalNode &&
        safetyCounter < 50) {
      safetyCounter++;
      currentTree = _reduceNextStep(currentTree, fullRoot: currentTree);
    }

    if (currentTree is ExactRadicalNode) {
      final decApprox = (currentTree.multiplier * math.sqrt(currentTree.radicand))
          .toStringAsFixed(6)
          .replaceAll('.', ',');
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: List.unmodifiable(_steps),
        exactResultLatex: currentTree.toLatex(),
        decimalApproxLatex: decApprox,
      );
    }

    final finalRational = (currentTree as ResolvedRationalNode).value.simplify();
    _lastEvaluatedRational = finalRational;

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: List.unmodifiable(_steps),
      exactResultLatex: finalRational.toLatex(),
      decimalApproxLatex: finalRational.toDecimalLatex(),
    );
  }

  StepByStepResolution _evaluateTopLevelTrig(TrigNode node) {
    final piMult = _extractPiMultiple(node.arg);
    final ratArg = piMult == null ? _evalToRationalQuick(node.arg) : null;
    final numArg = _evalToDoubleQuick(node.arg);
    final res = TrigAndAnglesSolver.solveTrig(
      function: node.function,
      argNode: node.arg,
      unit: _angleUnit,
      evaluatedNumericArg: numArg,
      exactRationalArg: ratArg,
      piMultipleRational: piMult,
    );
    final approxNum = double.tryParse(res.decimalApproxLatex.replaceAll('°', '').replaceAll('^\\circ', '').replaceAll(',', '.'));
    if (approxNum != null) {
      _lastEvaluatedRational = Rational.fromDouble(approxNum, 100000);
    }
    return res;
  }

  StepByStepResolution _evaluateTopLevelLog(LogNode node) {
    final baseRat = node.base != null ? _evalToRationalQuick(node.base!) : null;
    final argRat = _evalToRationalQuick(node.arg);
    if (argRat != null && (node.base == null || baseRat != null)) {
      final res = LogarithmSolver.solve(
        base: baseRat,
        argument: argRat,
        isNaturalLn: node.isNaturalLn,
        customExprLatex: node.toLatex(),
      );
      final parsedDec = double.tryParse(res.decimalApproxLatex.replaceAll(',', '.'));
      if (parsedDec != null) {
        _lastEvaluatedRational = Rational.fromDouble(parsedDec, 100000);
      }
      return res;
    }

    // Fallback cuando base o argumento incluyen raíces/decimales no reducidos aún
    final argD = _evalToDoubleQuick(node.arg);
    final baseD = node.isNaturalLn
        ? math.e
        : (node.base != null ? _evalToDoubleQuick(node.base!) : 10.0);
    if (argD == null || argD <= 0 || baseD == null || baseD <= 0 || (baseD - 1).abs() < 1e-12) {
      return LogarithmSolver.solve(
        base: baseRat,
        argument: Rational(argD != null && argD <= 0 ? 0 : 1),
        isNaturalLn: node.isNaturalLn,
        customExprLatex: node.toLatex(),
      );
    }
    final val = math.log(argD) / math.log(baseD);
    final decStr = Rational.fromDouble(val, 1000000).toDecimalLatex();
    _lastEvaluatedRational = Rational.fromDouble(val, 1000000);
    return StepByStepResolution(
      originalInputLatex: node.toLatex(),
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Cálculo aproximado del logaritmo',
          latexExpression: '${node.toLatex()} \\approx $decStr',
          pedagogicalNote: 'Evaluamos numéricamente el argumento y calculamos el logaritmo.',
        ),
      ],
      exactResultLatex: decStr,
      decimalApproxLatex: decStr,
    );
  }

  void _addStep({
    required String title,
    required String latex,
    required String note,
    String? warning,
  }) {
    _steps.add(
      MathStep(
        index: _steps.length + 1,
        shortTitle: '${_steps.length + 1}. $title',
        latexExpression: latex,
        pedagogicalNote: note,
        warningTrick: warning,
      ),
    );
  }

  ExprNode _reduceNextStep(ExprNode node, {required ExprNode fullRoot}) {
    switch (node) {
      case ResolvedRationalNode():
        return node;

      case ExactRadicalNode():
        return node;

      case VariableNode(:final name):
        final upper = name.toUpperCase();
        final val = _memoryVariables[upper] ?? Rational(0);
        final varLatex = upper == 'ANS' ? r'\text{ANS}' : upper;
        _addStep(
          title: 'Sustitución de variable o memoria $upper',
          latex:
              '\\text{Sustituimos } $varLatex = ${val.toLatex()} \\text{ en la expresion}',
          note:
              'Recuperamos el valor almacenado en la memoria $upper (${val.toLatex()}) para evaluar la expresión.',
        );
        return ResolvedRationalNode(val);

      case CbrtNode(:final radicand):
        if (radicand is! ResolvedRationalNode) {
          return CbrtNode(_reduceNextStep(radicand, fullRoot: fullRoot));
        }
        final val = radicand.value;
        if (val.isInteger) {
          final n = val.numerator;
          final sign = n < 0 ? -1 : 1;
          final absN = n.abs();
          final cbrtApprox = math.pow(absN, 1 / 3).round();
          if (cbrtApprox * cbrtApprox * cbrtApprox == absN) {
            final resVal = sign * cbrtApprox;
            _addStep(
              title: 'Raíz cúbica exacta',
              latex: '\\sqrt[3]{$n} = $resVal',
              note: '$n es un cubo perfecto ($resVal · $resVal · $resVal = $n).',
            );
            return ResolvedRationalNode(Rational(resVal));
          }
        }
        final doubleVal = (math.pow(val.toDouble().abs(), 1 / 3) * (val.toDouble() < 0 ? -1 : 1)).toDouble();
        _addStep(
          title: 'Raíz cúbica',
          latex: '\\sqrt[3]{${val.toLatex()}} \\approx ${doubleVal.toStringAsFixed(4)}',
          note: 'Calculamos la raíz cúbica decimal aproximada.',
        );
        return ResolvedRationalNode(Rational.fromDouble(doubleVal));

      case NthRootNode(:final n, :final radicand):
        if (radicand is! ResolvedRationalNode) {
          return NthRootNode(n, _reduceNextStep(radicand, fullRoot: fullRoot));
        }
        final val = radicand.value;
        final doubleVal = math.pow(val.toDouble(), 1 / n).toDouble();
        _addStep(
          title: 'Raíz de índice $n',
          latex: '\\sqrt[$n]{${val.toLatex()}} \\approx ${doubleVal.toStringAsFixed(4)}',
          note: 'Calculamos la raíz de índice $n.',
        );
        return ResolvedRationalNode(Rational.fromDouble(doubleVal));

      case McmNode(:final args):
        return _reduceMcmOrMcd(args, isMcm: true, fullRoot: fullRoot);

      case McdNode(:final args):
        return _reduceMcmOrMcd(args, isMcm: false, fullRoot: fullRoot);

      case SqrtNode(:final radicand):
        if (radicand is IntNode) {
          final n = radicand.value;
          if (n < 0) {
            _addStep(
              title: 'Raíz cuadrada de número negativo',
              latex: '\\sqrt{$n} \\implies \\text{Sin solucion real}',
              note: 'No existe la raíz cuadrada real de un número negativo.',
              warning: 'Una raíz cuadrada con radicando negativo no tiene solución real.',
            );
            return ResolvedRationalNode(Rational(0));
          }
          final sqrtInt = math.sqrt(n).toInt();
          if (sqrtInt * sqrtInt == n) {
            _addStep(
              title: 'Raíz cuadrada exacta',
              latex: '\\sqrt{$n} = $sqrtInt',
              note: '$n es un cuadrado perfecto ($sqrtInt · $sqrtInt = $n).',
            );
            return ResolvedRationalNode(Rational(sqrtInt));
          }
          final res = RadicalAndFactorSolver.simplifySquareRoot(n);
          for (final s in res.steps) {
            _steps.add(s);
          }
          return ExactRadicalNode(1, n);
        }
        if (radicand is! ResolvedRationalNode) {
          return SqrtNode(_reduceNextStep(radicand, fullRoot: fullRoot));
        }
        final val = radicand.value;
        if (val.numerator < 0) {
          _addStep(
            title: 'Raíz cuadrada de número negativo',
            latex: '\\sqrt{${val.toLatex()}} \\implies \\text{Sin solucion real}',
            note: 'No existe la raíz cuadrada real de un número negativo.',
          );
          return ResolvedRationalNode(Rational(0));
        }
        if (val.isInteger) {
          final n = val.numerator;
          final sqrtInt = math.sqrt(n).toInt();
          if (sqrtInt * sqrtInt == n) {
            _addStep(
              title: 'Raíz cuadrada exacta',
              latex: '\\sqrt{$n} = $sqrtInt',
              note: '$n es un cuadrado perfecto.',
            );
            return ResolvedRationalNode(Rational(sqrtInt));
          }
          return ExactRadicalNode(1, n);
        }
        return ResolvedRationalNode(Rational.fromDouble(math.sqrt(val.toDouble())));

      case IntNode(:final value):
        return ResolvedRationalNode(Rational(value));

      case DecimalNode():
        return ResolvedRationalNode(node.toRational());

      case PiNode():
        return ResolvedRationalNode(Rational.fromDouble(math.pi, 1000000));

      case TrigNode():
        final res = _evaluateTopLevelTrig(node);
        for (final s in res.steps) {
          _steps.add(s);
        }
        final approxD = _evalToDoubleQuick(node) ?? 0.0;
        return ResolvedRationalNode(
          _rationalFromResultLatexOrDouble(res.exactResultLatex, approxD),
        );

      case LogNode():
        final res = _evaluateTopLevelLog(node);
        for (final s in res.steps) {
          _steps.add(s);
        }
        final approxD = _evalToDoubleQuick(node) ?? 0.0;
        return ResolvedRationalNode(
          _rationalFromResultLatexOrDouble(res.exactResultLatex, approxD),
        );

      case PercentNode(:final operand):
        if (operand is! ResolvedRationalNode) {
          return PercentNode(_reduceNextStep(operand, fullRoot: fullRoot));
        }
        final ratio = operand.value / Rational(100);
        _addStep(
          title: 'Conversión de porcentaje',
          latex: '${operand.value.toLatex()}\\% = ${ratio.toLatex()}',
          note: 'Dividimos entre 100 para operar el porcentaje en forma exacta.',
        );
        return ResolvedRationalNode(ratio);

      case DmsNode(:final degrees, :final minutes, :final seconds, :final isNegative):
        final dms = DmsValue(
          degrees: degrees,
          minutes: minutes,
          seconds: seconds,
          isNegative: isNegative,
        );
        return ResolvedRationalNode(Rational.fromDouble(dms.toDecimalDegrees(), 1000000));

      case FractionNode(:final numerator, :final denominator):
        final raw = Rational.raw(numerator, denominator);
        if (raw.isReducible) {
          final common = Rational.gcd(numerator, denominator);
          final simplified = raw.simplify();
          _addStep(
            title: 'Simplificar fracción inicial',
            latex:
                '\\frac{$numerator : $common}{$denominator : $common} = ${simplified.toLatex()}',
            note:
                'Dividimos numerador y denominador entre su M.C.D. ($common) antes de operar para trabajar con números más pequeños.',
          );
          return ResolvedRationalNode(simplified);
        }
        return ResolvedRationalNode(raw);

      // TRAMPA CLÁSICA DE EXAMEN: -a^n (el signo menos está fuera de la potencia)
      case UnaryMinusNode(operand: PowerNode(:final base, :final exponent)):
        if (base is IntNode) {
          final baseVal = base.value;
          final powVal = Rational(baseVal).pow(exponent);
          final finalVal = Rational(-powVal.numerator, powVal.denominator);
          final isEven = exponent % 2 == 0;
          final expansion = exponent > 0 && exponent <= 6
              ? '-\\left(${List.filled(exponent, baseVal).join(r' \cdot ')}\\right) = '
              : '';

          _addStep(
            title: 'Potencia sin paréntesis en el signo',
            latex: '-$baseVal^{$exponent} = $expansion${finalVal.toLatex()}',
            note:
                'Calculamos la potencia de $baseVal y mantenemos el signo menos delante.',
            warning: isEven
                ? 'El exponente $exponent solo afecta al $baseVal porque no hay paréntesis: el resultado es negativo (-${powVal.denominator == 1 ? '${powVal.numerator}' : '${powVal.numerator}/${powVal.denominator}'}).'
                : null,
          );
          return ResolvedRationalNode(finalVal);
        }
        final reducedOperand = _reduceNextStep(node.operand, fullRoot: fullRoot);
        return UnaryMinusNode(reducedOperand);

      case UnaryMinusNode(:final operand):
        if (operand is IntNode) {
          return ResolvedRationalNode(Rational(-operand.value));
        }
        if (operand is ResolvedRationalNode) {
          final v = operand.value;
          return ResolvedRationalNode(Rational(-v.numerator, v.denominator));
        }
        return UnaryMinusNode(_reduceNextStep(operand, fullRoot: fullRoot));

      // CASO CON PARÉNTESIS: (-a)^n
      case PowerNode(:final base, :final exponent):
        if (base is UnaryMinusNode && base.operand is IntNode) {
          final baseVal = -(base.operand as IntNode).value;
          final result = Rational(baseVal).pow(exponent);
          final isEven = exponent % 2 == 0;
          final expansion = exponent > 0 && exponent <= 6
              ? '${List.filled(exponent, '($baseVal)').join(r' \cdot ')} = '
              : '';

          _addStep(
            title: 'Potencia de base negativa entre paréntesis',
            latex: '\\left($baseVal\\right)^{$exponent} = $expansion${result.toLatex()}',
            note: isEven
                ? 'Base negativa entre paréntesis elevada a exponente par ($exponent) da resultado positivo.'
                : 'Base negativa elevada a exponente impar ($exponent) conserva el signo negativo.',
          );
          return ResolvedRationalNode(result);
        }

        if (base is! ResolvedRationalNode) {
          return PowerNode(_reduceNextStep(base, fullRoot: fullRoot), exponent);
        }

        final result = base.value.pow(exponent);
        _addStep(
          title: 'Resolver potencia',
          latex: '${node.toLatex()} = ${result.toLatex()}',
          note: 'Elevamos la base al exponente $exponent.',
        );
        return ResolvedRationalNode(result);

      case BinaryOpNode(:final left, :final op, :final right):
        if (left is! ResolvedRationalNode) {
          return BinaryOpNode(
            _reduceNextStep(left, fullRoot: fullRoot),
            op,
            right,
            parenthesized: node.parenthesized,
          );
        }
        if (right is! ResolvedRationalNode) {
          return BinaryOpNode(
            left,
            op,
            _reduceNextStep(right, fullRoot: fullRoot),
            parenthesized: node.parenthesized,
          );
        }

        return _evaluateBinaryRational(left.value, op, right.value);
    }
  }

  ExprNode _reduceMcmOrMcd(
    List<ExprNode> args, {
    required bool isMcm,
    required ExprNode fullRoot,
  }) {
    for (int i = 0; i < args.length; i++) {
      if (args[i] is! ResolvedRationalNode) {
        final nextArgs = List<ExprNode>.from(args);
        nextArgs[i] = _reduceNextStep(args[i], fullRoot: fullRoot);
        return isMcm ? McmNode(nextArgs) : McdNode(nextArgs);
      }
    }

    final nums = <int>[];
    for (final node in args) {
      final rat = (node as ResolvedRationalNode).value.simplify();
      if (!rat.isInteger || rat.numerator <= 0) {
        throw const FormatException(
          'm.c.m. y M.C.D. requieren números enteros positivos mayores que 0.',
        );
      }
      nums.add(rat.numerator);
    }

    if (nums.length < 2) {
      throw const FormatException(
        'm.c.m. y M.C.D. requieren al menos 2 números positivos.',
      );
    }

    // Paso 1: Descomposición factorial de TODOS los números
    final factorMaps = nums.map(Rational.primeFactorsMap).toList();
    final factorRows = <String>[];
    for (int i = 0; i < nums.length; i++) {
      factorRows.add('${nums[i]} = ${Rational.factorMapToLatex(factorMaps[i])}');
    }
    _addStep(
      title: 'Descomposición en factores primos',
      latex: '\\begin{aligned} ${factorRows.join(r' \\ ')} \\end{aligned}',
      note:
          'Descomponemos cada uno de los ${nums.length} números en producto de factores primos.',
    );

    // Paso 2: Regla ESO para m.c.m. o M.C.D.
    final fnLatex = isMcm ? r'\text{m.c.m.}' : r'\text{M.C.D.}';
    final argsListLatex = nums.join(' ; ');

    if (isMcm) {
      final allPrimes = <int>{
        for (final m in factorMaps) ...m.keys,
      }.toList()
        ..sort();
      final selectedMap = <int, int>{};
      for (final p in allPrimes) {
        int maxExp = 0;
        for (final m in factorMaps) {
          final e = m[p] ?? 0;
          if (e > maxExp) maxExp = e;
        }
        selectedMap[p] = maxExp;
      }

      final lcmVal = Rational.lcmMany(nums);
      final prodLatex = Rational.factorMapToLatex(selectedMap);
      final exprLatex = prodLatex == '$lcmVal'
          ? '$fnLatex\\left($argsListLatex\\right) = $lcmVal'
          : '$fnLatex\\left($argsListLatex\\right) = $prodLatex = $lcmVal';

      _addStep(
        title: 'Regla ESO del m.c.m. (comunes y no comunes al mayor exponente)',
        latex: exprLatex,
        note:
            'Tomamos todos los factores primos (comunes y no comunes) elevados al mayor exponente y multiplicamos.',
      );
      return ResolvedRationalNode(Rational(lcmVal));
    } else {
      final commonPrimes = factorMaps.first.keys.where((p) {
        return factorMaps.every((m) => m.containsKey(p));
      }).toList()
        ..sort();

      final selectedMap = <int, int>{};
      for (final p in commonPrimes) {
        int minExp = factorMaps.first[p]!;
        for (int i = 1; i < factorMaps.length; i++) {
          final e = factorMaps[i][p]!;
          if (e < minExp) minExp = e;
        }
        selectedMap[p] = minExp;
      }

      final gcdVal = Rational.gcdMany(nums);
      final prodLatex = Rational.factorMapToLatex(selectedMap);
      final exprLatex = (commonPrimes.isEmpty || prodLatex == '$gcdVal')
          ? '$fnLatex\\left($argsListLatex\\right) = $gcdVal'
          : '$fnLatex\\left($argsListLatex\\right) = $prodLatex = $gcdVal';

      _addStep(
        title: 'Regla ESO del M.C.D. (comunes al menor exponente)',
        latex: exprLatex,
        note: commonPrimes.isEmpty
            ? 'No comparten factores primos comunes; por tanto, son primos entre sí y su M.C.D. es 1.'
            : 'Tomamos únicamente los factores primos comunes a todos elevados al menor exponente.',
      );
      return ResolvedRationalNode(Rational(gcdVal));
    }
  }

  ResolvedRationalNode _evaluateBinaryRational(
    Rational a,
    BinaryOperator op,
    Rational b,
  ) {
    switch (op) {
      case BinaryOperator.add:
      case BinaryOperator.subtract:
        final signSymbol = op == BinaryOperator.add ? '+' : '-';

        // Si tienen distinto denominador, explicamos el m.c.m. y amplificamos
        if (a.denominator != b.denominator) {
          final commonDen = Rational.lcm(a.denominator, b.denominator);
          final factorA = commonDen ~/ a.denominator;
          final factorB = commonDen ~/ b.denominator;

          final factALatex = Rational.primeFactorizationLatex(a.denominator);
          final factBLatex = Rational.primeFactorizationLatex(b.denominator);

          _addStep(
            title: 'Denominador común (m.c.m.)',
            latex:
                '\\text{m.c.m.}(${a.denominator}, ${b.denominator}) = $commonDen \\quad \\left(${a.denominator} = $factALatex, \\; ${b.denominator} = $factBLatex\\right)',
            note:
                'Factorizamos los denominadores y tomamos los factores comunes y no comunes elevados al mayor exponente.',
          );

          final newNumA = a.numerator * factorA;
          final newNumB = b.numerator * factorB;

          _addStep(
            title: 'Amplificar fracciones al denominador $commonDen',
            latex:
                '\\frac{\\textcolor{#2563EB}{$factorA} \\cdot ${AlgebraicLatexFormatter.parenIfNegative(a.numerator)}}{$commonDen} $signSymbol \\frac{\\textcolor{#2563EB}{$factorB} \\cdot ${AlgebraicLatexFormatter.parenIfNegative(b.numerator)}}{$commonDen} = \\frac{$newNumA}{$commonDen} $signSymbol \\frac{$newNumB}{$commonDen}',
            note:
                'Dividimos el m.c.m. ($commonDen) entre cada denominador antiguo y multiplicamos por su numerador.',
          );

          final combinedNum =
              op == BinaryOperator.add ? newNumA + newNumB : newNumA - newNumB;
          final unreduced = Rational.raw(combinedNum, commonDen);
          final simplified = unreduced.simplify();
          final numExprLatex = '$newNumA $signSymbol ${AlgebraicLatexFormatter.parenIfNegative(newNumB)}';

          if (unreduced.isReducible) {
            final gcd = Rational.gcd(combinedNum, commonDen);
            _addStep(
              title: 'Operar numeradores y simplificar a fracción irreducible',
              latex:
                  '\\frac{$numExprLatex}{$commonDen} = \\frac{$combinedNum : $gcd}{$commonDen : $gcd} = ${simplified.toLatex()}',
              note:
                  'Operamos los numeradores y simplificamos dividiendo entre el M.C.D. ($gcd).',
            );
          } else {
            _addStep(
              title: 'Operar numeradores',
              latex: '\\frac{$numExprLatex}{$commonDen} = ${simplified.toLatex()}',
              note: 'La fracción resultante ya es irreducible.',
            );
          }
          return ResolvedRationalNode(simplified);
        }

        // Mismo denominador o números enteros
        final result = op == BinaryOperator.add ? a + b : a - b;
        final rightStr = b.numerator < 0 ? '(${b.toLatex()})' : b.toLatex();
        _addStep(
          title: a.isInteger && b.isInteger
              ? 'Operar números enteros'
              : 'Fracciones con igual denominador',
          latex: '${a.toLatex()} $signSymbol $rightStr = ${result.toLatex()}',
          note: a.isInteger && b.isInteger
              ? 'Resolvemos la operación entera respetando la regla de los signos.'
              : 'Mantenemos el denominador común (${a.denominator}) y operamos los numeradores.',
        );
        return ResolvedRationalNode(result);

      case BinaryOperator.multiply:
        final result = a * b;
        final rightStr = b.numerator < 0 ? '(${b.toLatex()})' : b.toLatex();
        final mulLatex = (a.isInteger && b.isInteger)
            ? '${a.toLatex()} \\cdot $rightStr = ${result.toLatex()}'
            : '${a.toLatex()} \\cdot $rightStr = \\frac{${a.numerator} \\cdot ${AlgebraicLatexFormatter.parenIfNegative(b.numerator)}}{${a.denominator} \\cdot ${b.denominator}} = ${result.toLatex()}';
        _addStep(
          title: (a.isInteger && b.isInteger) ? 'Multiplicar enteros' : 'Multiplicación en línea',
          latex: mulLatex,
          note: (a.isInteger && b.isInteger)
              ? 'Calculamos el producto respetando la regla de los signos.'
              : 'Multiplicamos en línea: numerador por numerador y denominador por denominador.',
        );
        return ResolvedRationalNode(result);

      case BinaryOperator.divide:
        final result = a / b;
        final rightStr = b.numerator < 0 ? '(${b.toLatex()})' : b.toLatex();
        final divLatex = (a.isInteger && b.isInteger)
            ? '${a.toLatex()} : $rightStr = ${result.toLatex()}'
            : '${a.toLatex()} : $rightStr = \\frac{${a.numerator} \\cdot ${b.denominator}}{${a.denominator} \\cdot ${AlgebraicLatexFormatter.parenIfNegative(b.numerator)}} = ${result.toLatex()}';
        _addStep(
          title: (a.isInteger && b.isInteger)
              ? 'División exacta o en forma de fracción'
              : 'División de fracciones (productos cruzados)',
          latex: divLatex,
          note: (a.isInteger && b.isInteger)
              ? 'Dividimos los dos números y simplificamos si es fracción irreducible.'
              : 'Multiplicamos en cruz (o multiplicamos la primera fracción por la inversa de la segunda).',
        );
        return ResolvedRationalNode(result);
    }
  }

  Rational _rationalFromResultLatexOrDouble(String latex, double fallback) {
    final trimmed = latex.trim();
    if (trimmed == '0') return Rational(0);
    if (trimmed == '1') return Rational(1);
    if (trimmed == '-1') return Rational(-1);
    final fracM = RegExp(r'^(-?)\\frac\{(\d+)\}\{(\d+)\}$').firstMatch(trimmed);
    if (fracM != null) {
      final sign = fracM[1] == '-' ? -1 : 1;
      return Rational(sign * int.parse(fracM[2]!), int.parse(fracM[3]!));
    }
    return Rational.fromDouble(fallback, 1000000);
  }

  List<({DmsValue value, bool isSubtract})>? _tryCollectDmsTerms(ExprNode node) {
    if (node is DmsNode) {
      return [
        (
          value: DmsValue(
            degrees: node.degrees,
            minutes: node.minutes,
            seconds: node.seconds,
            isNegative: node.isNegative,
          ),
          isSubtract: false,
        ),
      ];
    }
    if (node is UnaryMinusNode && node.operand is DmsNode) {
      final d = node.operand as DmsNode;
      return [
        (
          value: DmsValue(
            degrees: d.degrees,
            minutes: d.minutes,
            seconds: d.seconds,
            isNegative: d.isNegative,
          ),
          isSubtract: true,
        ),
      ];
    }
    if (node is BinaryOpNode &&
        (node.op == BinaryOperator.add || node.op == BinaryOperator.subtract)) {
      final lTerms = _tryCollectDmsTerms(node.left);
      final rTerms = _tryCollectDmsTerms(node.right);
      if (lTerms == null || rTerms == null) return null;
      return [
        ...lTerms,
        for (final t in rTerms)
          (
            value: t.value,
            isSubtract: node.op == BinaryOperator.subtract ? !t.isSubtract : t.isSubtract,
          ),
      ];
    }
    return null;
  }

  Rational? _extractPiMultiple(ExprNode node) {
    if (node is PiNode) return Rational(1);
    if (node is UnaryMinusNode) {
      final sub = _extractPiMultiple(node.operand);
      return sub == null ? null : -sub;
    }
    if (node is BinaryOpNode) {
      if (node.op == BinaryOperator.multiply) {
        final lPi = _extractPiMultiple(node.left);
        final rRat = _evalToRationalQuick(node.right);
        if (lPi != null && rRat != null) return lPi * rRat;
        final rPi = _extractPiMultiple(node.right);
        final lRat = _evalToRationalQuick(node.left);
        if (rPi != null && lRat != null) return rPi * lRat;
      } else if (node.op == BinaryOperator.divide) {
        final lPi = _extractPiMultiple(node.left);
        final rRat = _evalToRationalQuick(node.right);
        if (lPi != null && rRat != null && !rRat.isZero) return lPi / rRat;
      }
    }
    return null;
  }

  Rational? _evalToRationalQuick(ExprNode node) {
    return switch (node) {
      IntNode(:final value) => Rational(value),
      DecimalNode() => node.toRational(),
      FractionNode(:final numerator, :final denominator) =>
        denominator == 0 ? null : Rational(numerator, denominator),
      ResolvedRationalNode(:final value) => value,
      VariableNode(:final name) => _memoryVariables[name.toUpperCase()] ?? Rational(0),
      PercentNode(:final operand) => () {
          final v = _evalToRationalQuick(operand);
          return v == null ? null : v / Rational(100);
        }(),
      UnaryMinusNode(:final operand) => () {
          final v = _evalToRationalQuick(operand);
          return v == null ? null : -v;
        }(),
      PowerNode(:final base, :final exponent) => () {
          final v = _evalToRationalQuick(base);
          if (v == null || (exponent < 0 && v.isZero)) return null;
          return v.pow(exponent);
        }(),
      BinaryOpNode(:final left, :final op, :final right) => () {
          final l = _evalToRationalQuick(left);
          final r = _evalToRationalQuick(right);
          if (l == null || r == null) return null;
          return switch (op) {
            BinaryOperator.add => l + r,
            BinaryOperator.subtract => l - r,
            BinaryOperator.multiply => l * r,
            BinaryOperator.divide => r.isZero ? null : l / r,
          };
        }(),
      _ => null,
    };
  }

  double? _evalToDoubleQuick(ExprNode node) {
    final rat = _evalToRationalQuick(node);
    if (rat != null) return rat.toDouble();
    return switch (node) {
      PiNode() => math.pi,
      DmsNode(:final degrees, :final minutes, :final seconds, :final isNegative) =>
        DmsValue(
          degrees: degrees,
          minutes: minutes,
          seconds: seconds,
          isNegative: isNegative,
        ).toDecimalDegrees(),
      SqrtNode(:final radicand) => () {
          final v = _evalToDoubleQuick(radicand);
          return (v == null || v < 0) ? null : math.sqrt(v);
        }(),
      TrigNode(:final function, :final arg) => () {
          final a = _evalToDoubleQuick(arg);
          if (a == null) return null;
          final rad = _angleUnit == AngleUnit.deg ? a * math.pi / 180.0 : a;
          return switch (function) {
            TrigFunction.sin => math.sin(rad),
            TrigFunction.cos => math.cos(rad),
            TrigFunction.tan => math.tan(rad),
            TrigFunction.asin => math.asin(a.clamp(-1.0, 1.0)) *
                (_angleUnit == AngleUnit.deg ? 180.0 / math.pi : 1.0),
            TrigFunction.acos => math.acos(a.clamp(-1.0, 1.0)) *
                (_angleUnit == AngleUnit.deg ? 180.0 / math.pi : 1.0),
            TrigFunction.atan => math.atan(a) *
                (_angleUnit == AngleUnit.deg ? 180.0 / math.pi : 1.0),
          };
        }(),
      UnaryMinusNode(:final operand) => () {
          final v = _evalToDoubleQuick(operand);
          return v == null ? null : -v;
        }(),
      BinaryOpNode(:final left, :final op, :final right) => () {
          final l = _evalToDoubleQuick(left);
          final r = _evalToDoubleQuick(right);
          if (l == null || r == null) return null;
          return switch (op) {
            BinaryOperator.add => l + r,
            BinaryOperator.subtract => l - r,
            BinaryOperator.multiply => l * r,
            BinaryOperator.divide => r == 0 ? null : l / r,
          };
        }(),
      _ => null,
    };
  }
}
