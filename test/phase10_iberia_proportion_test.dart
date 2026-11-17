import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/arithmetic/casio_iberia_arsenal.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/proportion/proportion_conversion_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/exact/extended_calc_solver.dart';

import 'support/e2e_helpers.dart';

String _all(StepByStepResolution r) =>
    '${r.originalInputLatex}${r.steps.map((s) => s.latexExpression).join()}${r.exactResultLatex}';

/// Sin tildes/enes dentro de \text{} o \mathrm{} y con llaves balanceadas.
void _clean(StepByStepResolution r) {
  final tex = _all(r);
  expect(balanced(tex), isTrue, reason: tex);
  expect(RegExp(r'\\(text|mathrm)\{[^}]*[áéíóúñ¿¡][^}]*\}').hasMatch(tex), isFalse, reason: tex);
  expect(RegExp(r'\\r(?![a-zA-Z])').hasMatch(tex), isFalse, reason: 'sin \\r suelto');
}

String _per(String a, String p) => CasioIberiaArsenal.periodicToFraction(a, p).exactResultLatex;

Future<void> _optn(WidgetTester t) async {
  await tapF(t, find.text('SHIFT'));
  await tapF(t, find.text('CALC'));
}

/// OPTN > Arsenal Iberia (6.º de la pagina 2) > entrada 6 (Regla de 3 directa).
Future<void> _openProportion(WidgetTester t) async {
  await _optn(t);
  await pad(t, 'right');
  await key(t, '2');
  await pad(t, 'right');
  await key(t, '2');
}

void main() {
  group('Fraccion generatriz', () {
    test('periodicos puros', () {
      expect(_per('1', '3'), r'\frac{4}{3}');
      expect(_per('0', '3'), r'\frac{1}{3}');
      expect(_per('0', '6'), r'\frac{2}{3}');
      expect(_per('0', '9'), '1');
    });
    test('periodicos mixtos', () {
      expect(_per('2.1', '6'), r'\frac{13}{6}');
      expect(_per('0.4', '5'), r'\frac{41}{90}');
      expect(_per('-2.1', '6'), r'-\frac{13}{6}');
    });
    test('pasos: planteamiento, 100x-10x y simplificacion', () {
      final r = CasioIberiaArsenal.periodicToFraction('2.1', '6');
      final tex = _all(r);
      expect(r.steps.first.latexExpression, r'x = 2{,}1\widehat{6}');
      expect(tex, contains('100x - 10x'));
      expect(tex, contains('90x = 195'));
      expect(tex, contains(r'\frac{195}{90}'));
      expect(tex, contains(': 15'));
      _clean(r);
      _clean(CasioIberiaArsenal.periodicToFraction('-0', '3'));
    });
    test('routeInput Per(a,b) y errores', () {
      expect(CasioIberiaArsenal.routeInput('Per(1,3)')!.exactResultLatex, r'\frac{4}{3}');
      expect(() => CasioIberiaArsenal.routeInput('Per(1,)'), throwsA(isA<ArsenalException>()));
    });
  });

  group('Division con resto', () {
    test('17 ÷R 5', () {
      final r = CasioIberiaArsenal.routeInput('17÷R5')!;
      expect(r.exactResultLatex, r'C = 3,\; R = 2');
      expect(_all(r), contains(r'5 \cdot 3 + 2 = 17'));
      _clean(r);
    });
    test('negativos y divisor 0', () {
      expect(CasioIberiaArsenal.integerDivision(-17, 5).exactResultLatex, r'C = -4,\; R = 3');
      expect(CasioIberiaArsenal.integerDivision(17, -5).exactResultLatex, r'C = -3,\; R = 2');
      expect(() => CasioIberiaArsenal.integerDivision(7, 0), throwsA(isA<ArsenalException>()));
      expect(() => CasioIberiaArsenal.routeInput('7÷R0'), throwsA(isA<ArsenalException>()));
    });
  });

  group('Combinatoria', () {
    String ex(String s) => CasioIberiaArsenal.routeInput(s)!.exactResultLatex;
    test('valores', () {
      expect(ex('5!'), '120');
      expect(ex('0!'), '1');
      expect(ex('7nPr3'), '210');
      expect(ex('10nCr3'), '120');
      expect(ex('5nCr0'), '1');
      expect(ex('6nCr6'), '1');
      expect(ex('52nCr5'), '2598960');
      expect(ex('20!'), '2432902008176640000');
    });
    test('simplifica factoriales antes de multiplicar', () {
      final p = _all(CasioIberiaArsenal.permutations(7, 3));
      expect(p, contains(r'\frac{7 \cdot 6 \cdot 5 \cdot 4!}{4!}'));
      expect(p, contains('V_{7,3}'));
      final c = _all(CasioIberiaArsenal.combinations(10, 3));
      expect(c, contains(r'\frac{10 \cdot 9 \cdot 8}{3 \cdot 2 \cdot 1}'));
      expect(c, contains(r'\binom{10}{3}'));
      _clean(CasioIberiaArsenal.permutations(7, 3));
      _clean(CasioIberiaArsenal.permutations(5, 0));
      _clean(CasioIberiaArsenal.combinations(10, 3));
      _clean(CasioIberiaArsenal.combinations(5, 0));
      _clean(CasioIberiaArsenal.factorial(5));
    });
    test('validacion 0 <= r <= n enteros', () {
      for (final bad in ['3nCr5', '3nPr5', '70!', '2.5!', '5nCr1.5']) {
        expect(() => CasioIberiaArsenal.routeInput(bad), throwsA(isA<ArsenalException>()), reason: bad);
      }
      expect(() => CasioIberiaArsenal.combinations(5, -1), throwsA(isA<ArsenalException>()));
    });
    test('no intercepta expresiones generales', () {
      expect(CasioIberiaArsenal.routeInput('2+3'), isNull);
      expect(CasioIberiaArsenal.routeInput('5nCr2+1'), isNull);
    });
  });

  test('Abs exacto en expresiones aritmeticas y algebraicas', () {
    String e(String s) => ExtendedCalcSolver.solve(s).exactResultLatex;
    expect(e('Abs(-3)+Abs(2-5)'), '6');
    expect(e('Abs(-7)'), '7');
    expect(e('Abs(1/2-3/4)'), r'\frac{1}{4}');
  });

  group('Reglas de 3', () {
    Rational q(String s) => ProportionSolver.parseQuantity(s);
    test('directa', () {
      final r = ProportionSolver.direct(q('3'), q('12'), q('5'));
      expect(r.exactResultLatex, '20');
      expect(_all(r), contains(r'x = \frac{B \cdot C}{A}'));
      expect(_all(r), contains(r'x = \frac{12 \cdot 5}{3}'));
      _clean(r);
    });
    test('inversa', () {
      final r = ProportionSolver.inverse(q('3'), q('12'), q('6'));
      expect(r.exactResultLatex, '6');
      expect(_all(r), contains(r'x = \frac{A \cdot B}{C}'));
      _clean(r);
    });
    test('fracciones, decimales y errores', () {
      expect(ProportionSolver.direct(q('2'), q('1/2'), q('3')).exactResultLatex, r'\frac{3}{4}');
      expect(ProportionSolver.direct(q('0.5'), q('2'), q('3')).exactResultLatex, '12');
      expect(() => ProportionSolver.direct(q('0'), q('1'), q('2')), throwsA(isA<ArsenalException>()));
      expect(() => ProportionSolver.inverse(q('1'), q('1'), q('0')), throwsA(isA<ArsenalException>()));
      expect(() => q(''), throwsA(isA<ArsenalException>()));
      expect(() => q('1/0'), throwsA(isA<ArsenalException>()));
    });
  });

  group('Factores de conversion', () {
    String conv(String v, String a, String b) => ConversionFactorSolver.solve(
            ProportionSolver.parseQuantity(v), ConversionCatalog.byLabel(a), ConversionCatalog.byLabel(b))
        .exactResultLatex;
    test('velocidad', () {
      expect(conv('72', 'km/h', 'm/s'), r'20\;\frac{\mathrm{m}}{\mathrm{s}}');
      expect(conv('10', 'm/s', 'km/h'), r'36\;\frac{\mathrm{km}}{\mathrm{h}}');
    });
    test('densidad', () {
      expect(conv('1', 'g/cm3', 'kg/m3'), startsWith('1000'));
      expect(conv('1000', 'kg/m3', 'g/cm3'), startsWith(r'1\;'));
    });
    test('presion y energia', () {
      expect(conv('1', 'atm', 'Pa'), startsWith('101325'));
      expect(conv('101325', 'Pa', 'atm'), startsWith(r'1\;'));
      expect(conv('1', 'cal', 'J'), startsWith(r'\frac{523}{125}'));
      expect(conv('1', 'kcal', 'cal'), startsWith('1000'));
    });
    test('longitud, masa y tiempo', () {
      expect(conv('2.5', 'km', 'cm'), startsWith('250000'));
      expect(conv('3', 'kg', 'g'), startsWith('3000'));
      expect(conv('2', 'h', 'min'), startsWith('120'));
      expect(conv('1', 'd', 's'), startsWith('86400'));
    });
    test('pasos con fracciones unitarias y cancelacion', () {
      final r = ConversionFactorSolver.solve(
          Rational(72), ConversionCatalog.byLabel('km/h'), ConversionCatalog.byLabel('m/s'));
      final tex = _all(r);
      expect(tex, contains(r'\frac{1000\,\mathrm{m}}{'));
      expect(tex, contains(r'1\,\mathrm{km}}'));
      expect(tex, contains(r'3600\,\mathrm{s}}'));
      expect(tex, contains(r'\textcolor{#7A8A7E}'));
      _clean(r);
      const pairs = {'g/cm3': 'kg/m3', 'atm': 'Pa', 'cal': 'J', 'mm': 'km', 'mg': 't', 'd': 'ms'};
      pairs.forEach((u, other) {
        _clean(ConversionFactorSolver.solve(
            Rational(3, 2), ConversionCatalog.byLabel(u), ConversionCatalog.byLabel(other)));
      });
    });
    test('magnitudes incompatibles', () {
      expect(() => conv('1', 'km', 'kg'), throwsA(isA<ArsenalException>()));
    });
  });

  group('E2E en M1 (OPTN > Arsenal Iberia)', () {
    testWidgets('= resuelve 10 nCr 3 escrito con teclas', (t) async {
      await boot(t);
      await keys(t, ['1', '0']);
      await _optn(t);
      await key(t, '4'); // Otras funciones
      await key(t, '3'); // nCr
      await keys(t, ['3', '=']);
      expect(result(t), '120');
    });

    testWidgets('formulario de regla de 3 directa con teclado y =', (t) async {
      await boot(t);
      await _openProportion(t);
      expect(find.byKey(const Key('proportion_widget')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await keys(t, ['3', '=', '1', '2', '=', '5', '=']);
      expect(result(t), '20');
      expect(find.byKey(const Key('proportion_widget')), findsNothing);
    });

    testWidgets('divisor 0 muestra LcdErrorScreen y AC sale', (t) async {
      await boot(t);
      await _openProportion(t);
      await keys(t, ['0', '=', '1', '=', '2', '=']);
      expect(find.byKey(const Key('lcd_error_screen')), findsOneWidget);
      await key(t, 'AC');
      expect(find.byKey(const Key('proportion_widget')), findsOneWidget);
      await key(t, 'AC');
      expect(find.byKey(const Key('proportion_widget')), findsNothing);
    });

    testWidgets('cabecera: ▲, = abre desplegable y 3 elige conversion', (t) async {
      await boot(t);
      await _openProportion(t);
      await pad(t, 'up');
      await key(t, '=');
      expect(find.byKey(const Key('proportion_mode_2')), findsOneWidget);
      await key(t, '3');
      await pad(t, 'right');
      await pad(t, 'down');
      expect(find.textContaining('unidad'), findsOneWidget);
    });
  });
}
