---
name: casio-math-engine-step
description: >
  Diseña, implementa y testea motores de resolución matemática paso a paso en Dart
  que generan código LaTeX compatible con flutter_math_fork. Úsala SIEMPRE que se
  añadan o modifiquen operaciones aritméticas, jerarquía combinada, fracciones,
  polinomios, regla de Ruffini, ecuaciones de primer o segundo grado, sistemas de
  ecuaciones o evaluación de árboles sintácticos (AST) orientados al currículo de
  ESO y Bachillerato en España.
---

# Skill: Motor Matemático Paso a Paso en LaTeX (Currículo Español)

## Objetivo
Garantizar que ninguna operación matemática devuelva únicamente un `double` o un resultado final opaco. Cada operación resuelta por la calculadora debe devolver una estructura trazable con todos los pasos intermedios formateados en LaTeX puro y listos para ser navegados con el cursor D-Pad de la calculadora o explicados por el Tutor IA.

## Contrato de Datos Obligatorio en Dart
Cualquier solver o evaluador en `lib/domain/math_engine/` debe devolver un objeto `StepByStepResolution`:

```dart
class MathStep {
  final int index;
  final String shortTitle;       // Ej: "1. Denominador común (m.c.m.)"
  final String latexExpression;  // SOLO notación matemática pura: ej. r"\text{m.c.m.}(6, 4) = 12"
  final String pedagogicalNote;  // Explicación didáctica completa en español con tildes
  final String? warningTrick;    // Alerta de error típico en exámenes (opcional)

  const MathStep({
    required this.index,
    required this.shortTitle,
    required this.latexExpression,
    required this.pedagogicalNote,
    this.warningTrick,
  });
}

class StepByStepResolution {
  final String originalInputLatex;
  final List<MathStep> steps;
  final String exactResultLatex;   // Fracción irreducible o radical exacto
  final String decimalApproxLatex; // Valor para la tecla S<=>D

  const StepByStepResolution({
    required this.originalInputLatex,
    required this.steps,
    required this.exactResultLatex,
    required this.decimalApproxLatex,
  });
}
```

## Reglas Obligatorias de Notación y Blindaje de LaTeX
1. **Regla de Oro contra Roturas de KaTeX / `flutter_math_fork`:**
   - **NUNCA introduzcas texto con tildes españolas (`á, é, í, ó, ú, ñ, ¡, ¿`) dentro de `\text{...}` en `latexExpression`.** El parser de `flutter_math_fork` falla o genera caracteres rotos.
   - `latexExpression` debe contener **SOLO notación matemática válida** (números, variables, `\frac{}{}`, `\sqrt{}`, `\sqrt[n]{}`, `\cdot`, `\begin{array}`, `\boxed{}`, `\text{m.c.m.}`, `\text{M.C.D.}`).
   - Todas las explicaciones didácticas en español van exclusivamente en `shortTitle`, `pedagogicalNote` y `warningTrick`, renderizados con widgets `Text()` nativos en Flutter.
2. **Eliminación Absoluta de Retornos de Carro (`\r`):**
   - Nunca uses cadenas multilínea con saltos `\r\n` de Windows dentro de cadenas LaTeX. `flutter_math_fork` crea un nodo temporal `CrNode` que arroja excepciones en tiempo de ejecución.
3. **Multiplicación y División:**
   - Usa SIEMPRE `\cdot` para la multiplicación en expresiones algebraicas y numéricas intermedias, NUNCA `\times` ni `*`.
   - Las divisiones en modo *Natural Display* se representan como `\frac{a}{b}`, salvo en divisiones enteras o polinómicas.
4. **Operaciones con Fracciones:**
   - **Paso 1:** Simplificar las fracciones iniciales si son reducibles antes de buscar el denominador común.
   - **Paso 2:** Mostrar la descomposición en factores primos y el `\text{m.c.m.}(d_1, d_2)` (escrito en minúsculas con puntos, según convención española, y `\text{M.C.D.}` en mayúsculas).
   - **Paso 3:** Mostrar las fracciones equivalentes amplificadas con el denominador común, destacando en azul (`\textcolor{#2563EB}{...}`) el factor por el que se multiplica cada numerador.
   - **Paso 4:** Operar numeradores y simplificar hasta la fracción irreducible dividiendo por el `\text{M.C.D.}`.
5. **Ecuaciones de 2.º Grado (Fórmula General y Casos Incompletos):**
   - Si es incompleta ($b = 0$ o $c = 0$), despejar directamente o sacar factor común $x$.
   - Si es completa: identificar $a, b, c$, calcular discriminante $\Delta = b^2 - 4ac$ y desglosar ramas en formato exacto y decimal.
6. **Regla de Ruffini y Factorización:**
   - Muestra primero la lista de divisores enteros en notación matemática pura: `\text{Div}(a_0) = \{\pm 1, \pm 2, \dots\}`.
   - Formatea la caja de Ruffini en LaTeX usando `\begin{array}{r|rrrr}` compatible con `flutter_math_fork`, encerrando el resto final en `\boxed{0}`.

## Restricciones de Calidad (TDD)
- Prohibido arrancar la calculadora o los modos con presets precargados. Arranca siempre en `0` limpio.
- Prohibido usar `eval()` genérico de cadenas de texto. Opera siempre sobre el Árbol de Sintaxis Abstracta (AST) tipado.
- Todo solver debe tener tests unitarios comprobando tanto `exactResultLatex` como la secuencia completa de `steps`.
