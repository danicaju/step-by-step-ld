import 'dart:math' as math;
import '../../ast/ast_nodes.dart';
import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../logarithm_solver.dart';
import '../percentage_and_sci_solver.dart';
import '../radical_and_factor_solver.dart';
import '../trig_and_angles_solver.dart';
import 'evaluator_binary_op_helper.dart';
import 'evaluator_quick_eval.dart';

class EvaluatorSpecialNodesHelper {
  static StepByStepResolution? tryEvaluateTopLevel(
    ExprNode root, {
    required AngleUnit angleUnit,
    required String? rawInput,
    required void Function(Rational) setLastEvaluatedRational,
  }) {
    if (root is SqrtNode && root.radicand is IntNode) {
      return RadicalAndFactorSolver.simplifySquareRoot((root.radicand as IntNode).value);
    }

    if (root is DecimalNode && root.isDegrees) {
      final res = TrigAndAnglesSolver.solveDecimalToDms(
        root.toRational().toDouble(),
        originalLatex: root.rawText.replaceAll('.', ','),
      );
      setLastEvaluatedRational(root.toRational());
      return res;
    }

    final dmsTerms = EvaluatorBinaryOpHelper.tryCollectDmsTerms(root);
    if (dmsTerms != null && dmsTerms.isNotEmpty) {
      final res = TrigAndAnglesSolver.solveDmsOperation(
        terms: dmsTerms,
        originalLatex: rawInput ?? root.toLatex(),
      );
      final numVal = double.tryParse(
        res.decimalApproxLatex
            .replaceAll('°', '')
            .replaceAll('^\\circ', '')
            .replaceAll(',', '.'),
      );
      if (numVal != null) {
        setLastEvaluatedRational(Rational.fromDouble(numVal, 100000));
      }
      return res;
    }

    if (root is TrigNode) {
      return evaluateTopLevelTrig(
        root,
        angleUnit: angleUnit,
        setLastEvaluatedRational: setLastEvaluatedRational,
      );
    }

    if (root is LogNode) {
      return evaluateTopLevelLog(
        root,
        setLastEvaluatedRational: setLastEvaluatedRational,
      );
    }

    return tryEvaluatePercentageOrScientific(
      root,
      setLastEvaluatedRational: setLastEvaluatedRational,
    );
  }

  static StepByStepResolution? tryEvaluatePercentageOrScientific(
    ExprNode root, {
    required void Function(Rational) setLastEvaluatedRational,
  }) {
    if (root is PercentNode) {
      final pVal = EvaluatorQuickEval.evalToRationalQuick(root.operand);
      if (pVal != null) {
        final res = PercentageAndSciSolver.solveStandalonePercent(pVal);
        setLastEvaluatedRational(pVal / Rational(100));
        return res;
      }
    }

    if (root is BinaryOpNode) {
      if ((root.op == BinaryOperator.add || root.op == BinaryOperator.subtract) &&
          root.right is PercentNode) {
        final baseVal = EvaluatorQuickEval.evalToRationalQuick(root.left);
        final pctVal = EvaluatorQuickEval.evalToRationalQuick((root.right as PercentNode).operand);
        if (baseVal != null && pctVal != null) {
          final isDiscount = root.op == BinaryOperator.subtract;
          final iv = isDiscount
              ? Rational(1) - pctVal / Rational(100)
              : Rational(1) + pctVal / Rational(100);
          setLastEvaluatedRational(baseVal * iv);
          return PercentageAndSciSolver.solvePercentageVariation(
            baseValue: baseVal,
            percentValue: pctVal,
            isDiscount: isDiscount,
            originalLatex: root.toLatex(),
          );
        }
      }

      if (root.op == BinaryOperator.multiply &&
          (root.right is PercentNode || root.left is PercentNode)) {
        final bool pctOnRight = root.right is PercentNode;
        final pctNode = (pctOnRight ? root.right : root.left) as PercentNode;
        final otherNode = pctOnRight ? root.left : root.right;
        final baseVal = EvaluatorQuickEval.evalToRationalQuick(otherNode);
        final pctVal = EvaluatorQuickEval.evalToRationalQuick(pctNode.operand);
        if (baseVal != null && pctVal != null) {
          setLastEvaluatedRational(baseVal * (pctVal / Rational(100)));
          return PercentageAndSciSolver.solvePercentOf(
            baseValue: baseVal,
            percentValue: pctVal,
            originalLatex: root.toLatex(),
          );
        }
      }

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
            setLastEvaluatedRational(rawMant * Rational(10).pow(rawExp));
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

    final singleSci = PercentageAndSciSolver.tryExtractSciTerm(root);
    if (singleSci != null) {
      if (singleSci.exponent.abs() <= 8) {
        setLastEvaluatedRational(
          singleSci.mantissa * Rational(10).pow(singleSci.exponent),
        );
      }
      return PercentageAndSciSolver.solveScientificSingle(
        singleSci,
        originalLatex: root.toLatex(),
      );
    }

    return null;
  }
  static StepByStepResolution evaluateTopLevelTrig(
    TrigNode node, {
    required AngleUnit angleUnit,
    required void Function(Rational) setLastEvaluatedRational,
  }) {
    final piMult = EvaluatorQuickEval.extractPiMultiple(node.arg);
    final ratArg = piMult == null ? EvaluatorQuickEval.evalToRationalQuick(node.arg) : null;
    final numArg = EvaluatorQuickEval.evalToDoubleQuick(node.arg, angleUnit: angleUnit);
    final res = TrigAndAnglesSolver.solveTrig(
      function: node.function,
      argNode: node.arg,
      unit: angleUnit,
      evaluatedNumericArg: numArg,
      exactRationalArg: ratArg,
      piMultipleRational: piMult,
    );
    final approxNum = double.tryParse(
      res.decimalApproxLatex
          .replaceAll('°', '')
          .replaceAll('^\\circ', '')
          .replaceAll(',', '.'),
    );
    if (approxNum != null) {
      setLastEvaluatedRational(Rational.fromDouble(approxNum, 100000));
    }
    return res;
  }

  static StepByStepResolution evaluateTopLevelLog(
    LogNode node, {
    required void Function(Rational) setLastEvaluatedRational,
  }) {
    final baseRat = node.base != null ? EvaluatorQuickEval.evalToRationalQuick(node.base!) : null;
    final argRat = EvaluatorQuickEval.evalToRationalQuick(node.arg);
    if (argRat != null && (node.base == null || baseRat != null)) {
      final res = LogarithmSolver.solve(
        base: baseRat,
        argument: argRat,
        isNaturalLn: node.isNaturalLn,
        customExprLatex: node.toLatex(),
      );
      final parsedDec = double.tryParse(res.decimalApproxLatex.replaceAll(',', '.'));
      if (parsedDec != null) {
        setLastEvaluatedRational(Rational.fromDouble(parsedDec, 100000));
      }
      return res;
    }

    final argD = EvaluatorQuickEval.evalToDoubleQuick(node.arg);
    final baseD = node.isNaturalLn
        ? math.e
        : (node.base != null ? EvaluatorQuickEval.evalToDoubleQuick(node.base!) : 10.0);
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
    setLastEvaluatedRational(Rational.fromDouble(val, 1000000));
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

  static ExprNode reduceMcmOrMcd(
    List<ExprNode> args, {
    required bool isMcm,
    required ExprNode fullRoot,
    required ExprNode Function(ExprNode, {required ExprNode fullRoot}) reduceNextStep,
    required void Function({
      required String title,
      required String latex,
      required String note,
      String? warning,
    }) addStep,
  }) {
    for (int i = 0; i < args.length; i++) {
      if (args[i] is! ResolvedRationalNode) {
        final nextArgs = List<ExprNode>.from(args);
        nextArgs[i] = reduceNextStep(args[i], fullRoot: fullRoot);
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

    final factorMaps = nums.map(Rational.primeFactorsMap).toList();
    final factorRows = <String>[];
    for (int i = 0; i < nums.length; i++) {
      factorRows.add('${nums[i]} = ${Rational.factorMapToLatex(factorMaps[i])}');
    }
    addStep(
      title: 'Descomposición en factores primos',
      latex: '\\begin{aligned} ${factorRows.join(r' \\ ')} \\end{aligned}',
      note:
          'Descomponemos cada uno de los ${nums.length} números en producto de factores primos.',
    );

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

      addStep(
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

      addStep(
        title: 'Regla ESO del M.C.D. (comunes al menor exponente)',
        latex: exprLatex,
        note: commonPrimes.isEmpty
            ? 'No comparten factores primos comunes; por tanto, son primos entre sí y su M.C.D. es 1.'
            : 'Tomamos únicamente los factores primos comunes a todos elevados al menor exponente.',
      );
      return ResolvedRationalNode(Rational(gcdVal));
    }
  }
}
