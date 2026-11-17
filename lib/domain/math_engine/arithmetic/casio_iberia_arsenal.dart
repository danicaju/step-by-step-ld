import '../core/rational.dart';
import '../models/step_resolution.dart';

/// Error didactico del arsenal (se muestra en `LcdErrorScreen`).
/// El mensaje empieza por `Math ERROR:` o `Sintaxis incompleta:`.
class ArsenalException implements Exception {
  final String message;
  const ArsenalException(this.message);

  @override
  String toString() => message;
}

/// Utilidades LaTeX comunes del arsenal (sin depender de SETUP: nunca mixtos).
class ArsenalLatex {
  const ArsenalLatex._();

  /// `\frac{n}{d}` o entero, con signo delante.
  static String rat(Rational r) {
    if (r.isInteger) return '${r.numerator}';
    final sign = r.numerator < 0 ? '-' : '';
    return '$sign\\frac{${r.numerator.abs()}}{${r.denominator}}';
  }

  /// Igual que [rat] pero entre parentesis si es negativo o fraccion.
  static String ratParen(Rational r) {
    if (r.isInteger && r.numerator >= 0) return '${r.numerator}';
    return '\\left(${rat(r)}\\right)';
  }

  static String frac(Object n, Object d) => '\\frac{$n}{$d}';
}

/// Arsenal Casio Iberia de M1: periodico a fraccion, division con resto y
/// combinatoria (`n!`, `nPr`, `nCr`) paso a paso.
class CasioIberiaArsenal {
  const CasioIberiaArsenal._();

  static const int maxFactorial = 69;

  static final RegExp _perRe = RegExp(r'^Per\(\s*(-?\d*\.?\d*)\s*,\s*(\d*)\s*\)$');
  static final RegExp _divRe = RegExp(r'^(-?\d+)÷R(-?\d+)$');
  static final RegExp _factRe = RegExp(r'^(-?\d+(?:\.\d+)?)!$');
  static final RegExp _combRe = RegExp(r'^(-?\d+(?:\.\d+)?)(nCr|nPr)(-?\d+(?:\.\d+)?)$');

  /// Resuelve la entrada de M1 si es un literal del arsenal; `null` si no lo es.
  static StepByStepResolution? routeInput(String raw) {
    final s = raw.replaceAll(' ', '').replaceAll(r'\,', '');
    final per = _perRe.firstMatch(s);
    if (per != null) return periodicToFraction(per.group(1)!, per.group(2)!);
    final div = _divRe.firstMatch(s);
    if (div != null) return integerDivision(int.parse(div.group(1)!), int.parse(div.group(2)!));
    final fact = _factRe.firstMatch(s);
    if (fact != null) return factorial(_intArg(fact.group(1)!, 'n'));
    final comb = _combRe.firstMatch(s);
    if (comb != null) {
      final n = _intArg(comb.group(1)!, 'n');
      final r = _intArg(comb.group(3)!, 'r');
      return comb.group(2) == 'nPr' ? permutations(n, r) : combinations(n, r);
    }
    return null;
  }

  static int _intArg(String text, String name) {
    final v = double.parse(text);
    if (v != v.truncateToDouble()) {
      throw ArsenalException('Math ERROR: $name debe ser un entero.');
    }
    return v.toInt();
  }

  // ---------------------------------------------------------------- periodicos

  /// Decimal periodico `a,b\widehat{p}` -> fraccion generatriz.
  /// [nonRepeating] es la parte antes del periodo (`2.1`, `1`, `0`), [period] las cifras que se repiten.
  static StepByStepResolution periodicToFraction(String nonRepeating, String period) {
    if (period.isEmpty || !RegExp(r'^\d+$').hasMatch(period)) {
      throw const ArsenalException('Sintaxis incompleta: escribe el periodo (cifras que se repiten).');
    }
    var nr = nonRepeating.trim();
    final neg = nr.startsWith('-');
    if (neg) nr = nr.substring(1);
    if (nr.isEmpty) nr = '0';
    final parts = nr.split('.');
    if (parts.length > 2 || !RegExp(r'^\d+$').hasMatch(parts[0]) || (parts.length == 2 && parts[1].isNotEmpty && !RegExp(r'^\d+$').hasMatch(parts[1]))) {
      throw const ArsenalException('Sintaxis incompleta: parte no periodica no valida.');
    }
    final intStr = parts[0];
    final fracStr = parts.length == 2 ? parts[1] : '';
    final k = fracStr.length;
    final m = period.length;
    if (intStr.length + k + m > 15) {
      throw const ArsenalException('Math ERROR: demasiadas cifras (maximo 15).');
    }
    final na = int.parse('$intStr$fracStr'); // parte no periodica como entero
    final p = int.parse(period);
    final pow10k = _pow10(k);
    final pow10m = _pow10(m);
    final big = na * pow10m + p; // cifras de 10^(k+m) x sin la cola periodica
    final num = big - na;
    final den = pow10k * (pow10m - 1);
    final sign = neg ? '-' : '';
    final signedNum = neg ? -num : num;
    final r = Rational(signedNum, den);
    final xLatex = '$sign${_dec('$na', k, period)}';
    final lowC = k == 0 ? 'x' : '${pow10k}x';
    final highC = '${pow10k * pow10m}x';
    final lowN = _shifted(na, k, period, 0);
    final highN = _shifted(na, k, period, m);
    final g = Rational.gcd(num, den);
    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Planteamiento',
        latexExpression: 'x = $xLatex',
        pedagogicalNote: 'Llamamos x al decimal periodico. El arco marca las cifras que se repiten.',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Multiplicar por potencias de 10',
        latexExpression: '$highC = $sign$highN \\qquad $lowC = $sign$lowN',
        pedagogicalNote:
            'Multiplicamos por 10^$k para llevar la coma al inicio del periodo y por 10^${k + m} para pasar un periodo completo; asi las dos colas periodicas son iguales.',
      ),
      MathStep(
        index: 3,
        shortTitle: 'Restar para eliminar la cola',
        latexExpression: '$highC - $lowC = ${_wrap(neg, highN)} - ${_wrap(neg, lowN)} \\;\\Rightarrow\\; ${pow10k * (pow10m - 1)}x = ${neg ? -num : num}',
        pedagogicalNote: 'Al restar desaparece la parte decimal periodica.',
      ),
      MathStep(
        index: 4,
        shortTitle: 'Despejar x',
        latexExpression: 'x = \\frac{${neg ? -num : num}}{$den}',
        pedagogicalNote: 'Dividimos entre el coeficiente de x.',
      ),
      MathStep(
        index: 5,
        shortTitle: 'Simplificar',
        latexExpression: g > 1
            ? 'x = \\frac{$signedNum : $g}{$den : $g} = ${ArsenalLatex.rat(r)}'
            : 'x = ${ArsenalLatex.rat(r)}',
        pedagogicalNote: g > 1
            ? 'Dividimos numerador y denominador entre su m.c.d. = $g y queda una fraccion irreducible.'
            : 'La fraccion ya es irreducible (m.c.d. = 1).',
        warningTrick: period.replaceAll('9', '').isEmpty
            ? 'Un periodo 9 equivale a sumar 1 a la cifra anterior: 0,9 periodico es exactamente 1.'
            : null,
      ),
    ];
    return StepByStepResolution(
      originalInputLatex: xLatex,
      steps: steps,
      exactResultLatex: ArsenalLatex.rat(r),
      decimalApproxLatex: r.toDecimalLatex(),
    );
  }

  static int _pow10(int e) {
    var v = 1;
    for (var i = 0; i < e; i++) {
      v *= 10;
    }
    return v;
  }

  static String _wrap(bool neg, String body) => neg ? '(-$body)' : body;

  /// `2{,}1\widehat{6}` para parte no periodica `na` con [k] decimales.
  static String _dec(String na, int k, String period) {
    final digits = na.padLeft(k + 1, '0');
    final intPart = digits.substring(0, digits.length - k);
    final frac = digits.substring(digits.length - k);
    return '$intPart{,}$frac\\widehat{$period}';
  }

  /// Decimal tras desplazar la coma [k] cifras a la derecha del entero `na` y otras [extra] cifras del periodo.
  static String _shifted(int na, int k, String period, int extra) {
    final head = extra == 0 ? '$na' : '$na${period.substring(0, extra)}';
    return '$head{,}\\widehat{$period}';
  }

  // -------------------------------------------------------- division con resto

  /// `D \div R d`: cociente entero C y resto R con `D = d*C + R`, `0 <= R < |d|`.
  static StepByStepResolution integerDivision(int dividend, int divisor) {
    if (divisor == 0) {
      throw const ArsenalException('Math ERROR: el divisor no puede ser 0.');
    }
    final r = dividend % divisor.abs(); // Dart: resto no negativo
    final c = (dividend - r) ~/ divisor;
    final prod = divisor * c;
    return StepByStepResolution(
      originalInputLatex: '$dividend \\div R\\; $divisor',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Division entera',
          latexExpression: '$dividend \\;:\\; $divisor \\;\\Rightarrow\\; C = $c',
          pedagogicalNote: 'Buscamos el mayor cociente entero C tal que el resto no sea negativo.',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Calcular el resto',
          latexExpression: 'R = $dividend - $divisor \\cdot ${c < 0 ? '($c)' : c} = $dividend - ${prod < 0 ? '($prod)' : prod} = $r',
          pedagogicalNote: 'El resto es lo que sobra: R = D - d \\cdot C, siempre con 0 <= R < |d|.',
        ),
        MathStep(
          index: 3,
          shortTitle: 'Comprobacion',
          latexExpression: 'D = d \\cdot C + R \\;\\Rightarrow\\; $divisor \\cdot ${c < 0 ? '($c)' : c} + $r = $dividend',
          pedagogicalNote: 'Verificamos la prueba de la division: D = d x C + R.',
        ),
      ],
      exactResultLatex: 'C = $c,\\; R = $r',
      decimalApproxLatex: Rational(dividend, divisor).toDecimalLatex(),
    );
  }

  // ------------------------------------------------------------- combinatoria

  static void _check(int n, [int? r]) {
    if (n < 0 || n > maxFactorial) {
      throw const ArsenalException('Math ERROR: n debe ser un entero entre 0 y 69.');
    }
    if (r != null && (r < 0 || r > n)) {
      throw const ArsenalException('Math ERROR: se exige 0 <= r <= n.');
    }
  }

  static BigInt _fact(int n) => _prodRange(2, n);

  static BigInt _prodRange(int from, int to) {
    var v = BigInt.one;
    for (var i = from; i <= to; i++) {
      v *= BigInt.from(i);
    }
    return v;
  }

  /// `n \cdot (n-1) \cdot ... \cdot lo` (descendente, abreviado si es largo).
  static String _desc(int hi, int lo) {
    if (hi < lo) return '1';
    final count = hi - lo + 1;
    if (count <= 6) return [for (var i = hi; i >= lo; i--) '$i'].join(r' \cdot ');
    return '$hi \\cdot ${hi - 1} \\cdot \\ldots \\cdot $lo';
  }

  /// `n!` paso a paso.
  static StepByStepResolution factorial(int n) {
    _check(n);
    final v = _fact(n);
    return StepByStepResolution(
      originalInputLatex: '$n!',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Definicion de factorial',
          latexExpression: '$n! = ${n <= 1 ? '1' : _desc(n, 1)}',
          pedagogicalNote: 'n! es el producto de todos los enteros de 1 a n. Por convenio 0! = 1.',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Resultado',
          latexExpression: '$n! = $v',
          pedagogicalNote: 'Multiplicamos los factores.',
        ),
      ],
      exactResultLatex: '$v',
      decimalApproxLatex: '$v',
    );
  }

  /// Variaciones `V_{n,r} = n!/(n-r)!` (nPr), simplificando factoriales.
  static StepByStepResolution permutations(int n, int r) {
    _check(n, r);
    final nr = n - r;
    final v = _prodRange(nr + 1, n);
    final num = r == 0 ? '$n!' : '${_desc(n, nr + 1)} \\cdot $nr!';
    return StepByStepResolution(
      originalInputLatex: '$n\\,\\mathrm{nPr}\\,$r',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Formula de variaciones',
          latexExpression: 'V_{n,r} = \\frac{n!}{(n-r)!} = \\frac{$n!}{($n-$r)!} = \\frac{$n!}{$nr!}',
          pedagogicalNote: 'Importa el orden: V(n,r) = n! / (n-r)!.',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Desarrollar el factorial mayor',
          latexExpression: 'V_{$n,$r} = \\frac{$num}{$nr!}',
          pedagogicalNote: 'Escribimos n! hasta llegar a (n-r)! para poder simplificar.',
        ),
        MathStep(
          index: 3,
          shortTitle: 'Simplificar factoriales',
          latexExpression: 'V_{$n,$r} = ${r == 0 ? '1' : _desc(n, nr + 1)}',
          pedagogicalNote: 'Se cancela $nr! del numerador y del denominador antes de multiplicar.',
        ),
        MathStep(
          index: 4,
          shortTitle: 'Resultado',
          latexExpression: 'V_{$n,$r} = $v',
          pedagogicalNote: 'Producto de los $r factores que quedan.',
        ),
      ],
      exactResultLatex: '$v',
      decimalApproxLatex: '$v',
    );
  }

  /// Combinaciones `\binom{n}{r} = n!/(r!(n-r)!)` (nCr), simplificando factoriales.
  static StepByStepResolution combinations(int n, int r) {
    _check(n, r);
    final nr = n - r;
    final big = r > nr ? r : nr;
    final small = r > nr ? nr : r;
    final numProd = _prodRange(big + 1, n);
    final denProd = _fact(small);
    final v = numProd ~/ denProd;
    final nStr = small == 0 ? '1' : _desc(n, big + 1);
    final dStr = small <= 1 ? '1' : _desc(small, 1);
    return StepByStepResolution(
      originalInputLatex: '$n\\,\\mathrm{nCr}\\,$r',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Formula de combinaciones',
          latexExpression: '\\binom{n}{r} = \\frac{n!}{r!\\,(n-r)!} \\;\\Rightarrow\\; \\binom{$n}{$r} = \\frac{$n!}{$r!\\,$nr!}',
          pedagogicalNote: 'No importa el orden: C(n,r) = n! / (r! (n-r)!).',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Desarrollar y simplificar factoriales',
          latexExpression: small == 0
              ? '\\binom{$n}{$r} = \\frac{$n!}{$n!} = 1'
              : '\\binom{$n}{$r} = \\frac{$nStr \\cdot $big!}{$small!\\,\\cdot\\,$big!} = \\frac{$nStr}{$dStr}',
          pedagogicalNote: 'Desarrollamos n! hasta $big! y lo cancelamos con el factorial igual del denominador.',
        ),
        MathStep(
          index: 3,
          shortTitle: 'Multiplicar y dividir',
          latexExpression: '\\binom{$n}{$r} = \\frac{$numProd}{$denProd} = $v',
          pedagogicalNote: 'Primero multiplicamos numerador y denominador y despues dividimos.',
        ),
      ],
      exactResultLatex: '$v',
      decimalApproxLatex: '$v',
    );
  }
}
