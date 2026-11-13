import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';

enum BinaryOperator {
  add('+'),
  subtract('-'),
  multiply(r'\cdot'),
  divide(':');

  final String latexSymbol;
  const BinaryOperator(this.latexSymbol);
}

sealed class ExprNode {
  const ExprNode();

  /// Convierte el subárbol actual a código LaTeX respetando paréntesis necesarios
  String toLatex();
}

/// Número entero literal: ej. 5
final class IntNode extends ExprNode {
  final int value;
  const IntNode(this.value);

  @override
  String toLatex() => '$value';
}

/// Fracción literal en pantalla Natural Display: ej. \frac{4}{6}
final class FractionNode extends ExprNode {
  final int numerator;
  final int denominator;
  const FractionNode(this.numerator, this.denominator);

  Rational toRawRational() => Rational.raw(numerator, denominator);

  @override
  String toLatex() => Rational.raw(numerator, denominator).toLatex();
}

/// Nodo de valor racional ya resuelto internamente durante la reducción del AST
final class ResolvedRationalNode extends ExprNode {
  final Rational value;
  const ResolvedRationalNode(this.value);

  @override
  String toLatex() => value.toLatex();
}

/// Signo menos unario delante de una expresión: ej. -3^2 o -(4 + 2)
final class UnaryMinusNode extends ExprNode {
  final ExprNode operand;
  final bool hasExplicitParentheses;

  const UnaryMinusNode(this.operand, {this.hasExplicitParentheses = false});

  @override
  String toLatex() {
    if (hasExplicitParentheses) {
      return '\\left(-${operand.toLatex()}\\right)';
    }
    if (operand is BinaryOpNode) {
      return '-\\left(${operand.toLatex()}\\right)';
    }
    return '-${operand.toLatex()}';
  }
}

/// Potencia: base^{exponent}
final class PowerNode extends ExprNode {
  final ExprNode base;
  final int exponent;

  const PowerNode(this.base, this.exponent);

  @override
  String toLatex() {
    // Si la base es negativa con paréntesis o es una fracción, envolvemos en \left( \right)
    if (base is UnaryMinusNode ||
        base is FractionNode ||
        (base is ResolvedRationalNode && !(base as ResolvedRationalNode).value.isInteger)) {
      return '\\left(${base.toLatex()}\\right)^{$exponent}';
    }
    return '{${base.toLatex()}}^{$exponent}';
  }
}

/// Raíz cuadrada: \sqrt{radicand}
final class SqrtNode extends ExprNode {
  final ExprNode radicand;

  const SqrtNode(this.radicand);

  @override
  String toLatex() => '\\sqrt{${radicand.toLatex()}}';
}

/// Raíz cúbica: \sqrt[3]{radicand}
final class CbrtNode extends ExprNode {
  final ExprNode radicand;

  const CbrtNode(this.radicand);

  @override
  String toLatex() => '\\sqrt[3]{${radicand.toLatex()}}';
}

/// Raíz enésima: \sqrt[n]{radicand}
final class NthRootNode extends ExprNode {
  final int n;
  final ExprNode radicand;

  const NthRootNode(this.n, this.radicand);

  @override
  String toLatex() => '\\sqrt[$n]{${radicand.toLatex()}}';
}

/// Mínimo común múltiplo N-ario: \text{m.c.m.}(a ; b ; c)
final class McmNode extends ExprNode {
  final List<ExprNode> args;

  const McmNode(this.args);

  @override
  String toLatex() =>
      '\\text{m.c.m.}\\left(${args.map((e) => e.toLatex()).join(' ; ')}\\right)';
}

/// Máximo común divisor N-ario: \text{M.C.D.}(a ; b ; c)
final class McdNode extends ExprNode {
  final List<ExprNode> args;

  const McdNode(this.args);

  @override
  String toLatex() =>
      '\\text{M.C.D.}\\left(${args.map((e) => e.toLatex()).join(' ; ')}\\right)';
}

/// Radical exacto simplificado: multiplier \cdot \sqrt{radicand} (ej: 6\sqrt{2})
final class ExactRadicalNode extends ExprNode {
  final int multiplier;
  final int radicand;

  const ExactRadicalNode(this.multiplier, this.radicand);

  @override
  String toLatex() => AlgebraicLatexFormatter.radical(multiplier, radicand);
}

/// Operación binaria (+, -, \cdot, :)
final class BinaryOpNode extends ExprNode {
  final ExprNode left;
  final BinaryOperator op;
  final ExprNode right;
  final bool parenthesized;

  const BinaryOpNode(
    this.left,
    this.op,
    this.right, {
    this.parenthesized = false,
  });

  @override
  String toLatex() {
    final inner = '${left.toLatex()} ${op.latexSymbol} ${right.toLatex()}';
    return parenthesized ? '\\left($inner\\right)' : inner;
  }
}

/// Nodo que representa una variable o memoria de la calculadora (ej: ANS, A, B, C, D, E, F, X, Y)
final class VariableNode extends ExprNode {
  final String name;
  const VariableNode(this.name);

  @override
  String toLatex() =>
      name.toUpperCase() == 'ANS' ? r'\text{ANS}' : name.toUpperCase();
}

/// Número decimal exacto finito introducido por el usuario (ej: 3.2 o 34.52).
final class DecimalNode extends ExprNode {
  final String rawText;
  final bool isDegrees;
  const DecimalNode(this.rawText, {this.isDegrees = false});

  Rational toRational() => Rational.fromDecimalString(rawText);

  @override
  String toLatex() {
    final base = rawText.replaceAll('.', ',');
    return isDegrees ? '$base^\\circ' : base;
  }
}

/// Constante matemática Pi (\pi)
final class PiNode extends ExprNode {
  const PiNode();

  @override
  String toLatex() => r'\pi';
}

enum TrigFunction { sin, cos, tan, asin, acos, atan }

/// Función trigonométrica directa o inversa.
final class TrigNode extends ExprNode {
  final TrigFunction function;
  final ExprNode arg;
  final bool showDegSymbol;

  const TrigNode(this.function, this.arg, {this.showDegSymbol = false});

  @override
  String toLatex() {
    final fnLatex = switch (function) {
      TrigFunction.sin => r'\sin',
      TrigFunction.cos => r'\cos',
      TrigFunction.tan => r'\tan',
      TrigFunction.asin => r'\sin^{-1}',
      TrigFunction.acos => r'\cos^{-1}',
      TrigFunction.atan => r'\tan^{-1}',
    };
    final argLatex = showDegSymbol && arg is! DmsNode
        ? '${arg.toLatex()}^\\circ'
        : arg.toLatex();
    return '$fnLatex\\left($argLatex\\right)';
  }
}

/// Logaritmo decimal (\log), neperiano (\ln) o en base arbitraria (\log_a(b)).
final class LogNode extends ExprNode {
  final ExprNode arg;
  final ExprNode? base;
  final bool isNaturalLn;

  const LogNode({
    required this.arg,
    this.base,
    this.isNaturalLn = false,
  });

  @override
  String toLatex() {
    if (isNaturalLn) {
      return '\\ln\\left(${arg.toLatex()}\\right)';
    }
    if (base == null) {
      return '\\log\\left(${arg.toLatex()}\\right)';
    }
    return '\\log_{${base!.toLatex()}}\\left(${arg.toLatex()}\\right)';
  }
}

/// Porcentaje: operand\% (ej: 20\% = \frac{20}{100})
final class PercentNode extends ExprNode {
  final ExprNode operand;
  const PercentNode(this.operand);

  @override
  String toLatex() => '${operand.toLatex()}\\%';
}

/// Medida angular o temporal en Sistema Sexagesimal (Grados, Minutos, Segundos).
final class DmsNode extends ExprNode {
  final int degrees;
  final int minutes;
  final double seconds;
  final bool isNegative;
  final bool hasMinutes;
  final bool hasSeconds;

  const DmsNode({
    required this.degrees,
    this.minutes = 0,
    this.seconds = 0,
    this.isNegative = false,
    this.hasMinutes = false,
    this.hasSeconds = false,
  });

  @override
  String toLatex() {
    final sign = isNegative ? '-' : '';
    final buf = StringBuffer('$sign$degrees^\\circ');
    if (hasMinutes || minutes != 0 || hasSeconds || seconds != 0) {
      buf.write(" $minutes'");
    }
    if (hasSeconds || seconds != 0) {
      final isWhole = (seconds - seconds.roundToDouble()).abs() < 1e-6;
      final secStr = isWhole
          ? '${seconds.round()}'
          : seconds
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '')
              .replaceAll('.', ',');
      buf.write(" $secStr''");
    }
    return buf.toString();
  }
}

