---
name: casio-classwiz-ui
description: >
  Construye y modifica la interfaz de usuario eskeuomórfica inspirada en las calculadoras
  científicas Casio ClassWiz (fx-570SP X II / fx-991SP X II Iberia), incluyendo botones físicos con doble/triple
  leyenda (Normal, SHIFT, ALPHA), respuesta háptica, cursor D-Pad 2D y la pantalla LCD
  Natural Textbook Display con auto-escalado FittedBox y flutter_math_fork blindado.
---

# Skill: Interfaz Eskeuomórfica Casio ClassWiz Iberia y Pantalla Natural Display

## Objetivo
Replicar fielmente la ergonomía táctil, disposición espacial y memoria muscular de la calculadora física **Casio fx-570SP X II / fx-991SP X II Iberia**, integrando controles modernos para el Modo Tutor IA y navegación paso a paso sin ensuciar la distribución clásica.

## 1. Reglas Críticas de Estado y Limpieza Visual
1. **PROHIBIDO mostrar ejemplos o presets precargados al iniciar o al cambiar de modo.**
   - La calculadora debe arrancar limpia en `0`, exactamente como una Casio física recién encendida.
   - En modos por coeficientes (2.º grado, Ruffini, sistemas 2x2, parábolas), arranca con las celdas vacías listas para la introducción por el teclado.
   - Prohibido incluir filas de botones de "Ej. Fracc", "Ej. -3²", "Ej. Comb" o "Ej. Clase".
2. **Prohibición de Textos Redundantes en Leyendas:**
   - No pongas etiquetas obvias como "PROD", "COCIENTE", "CUADRADO", "POTENCIA", "LIMPIAR", "EDITAR", "RESOLVER", "ANTERIOR", "SIGUIENTE".
   - Usa únicamente las subfunciones reales serigrafiadas en la Casio ClassWiz Iberia (`x■`, `x³`, `ⁿ√■`, `³√■`, `c a/b`, `X`, `Y`, `FACT`, `m.c.m.`, `M.C.D.`, `TUTOR IA`).

## 2. Mapa de Teclado Fiel a Casio fx-570SP X II Iberia
Estructurado estrictamente en dos zonas ergonómicas:
- **Zona Superior (Teclas científicas oscuras y D-Pad Central):**
  - **Fila 1:** `SHIFT` (Ámbar `#E5A93C`), `ALPHA` (Coral rojo `#E05252`), `CasioDPad` (central con `◀`, `▶`, `▲`, `▼`), `MODE` (con `CONFIG` en shift).
  - **Fila 2:**
    - `a/b`: Fracción normal `/`, con SHIFT `c a/b`.
    - `√■`: Raíz cuadrada, con SHIFT `ⁿ√■`, con ALPHA `³√■`.
    - `x²`: Al cuadrado (`^2`), con SHIFT exponente libre `x■` (`^(`), con ALPHA cubo `x³` (`^3`).
    - `(`: Paréntesis apertura, con ALPHA variable `Y`.
    - `)`: Paréntesis cierre, con ALPHA variable `X`.
    - `S⬄D`: Alterna visualización exacta (fracción/radical) y aproximación decimal.
- **Zona Inferior (Pad numérico y operadores):**
  - **Fila 3:** `7` (alpha `A`), `8` (alpha `B`), `9` (alpha `C`), `DEL` (Azul `#2E86DE`), `AC` (Azul `#2E86DE`).
  - **Fila 4:** `4` (alpha `D`), `5` (alpha `E`), `6` (alpha `F`), `×` (shift `m.c.m.`, alpha `M.C.D.`), `÷` (shift `FACT`).
  - **Fila 5:** `1`, `2`, `3`, `+`, `-`.
  - **Fila 6:** `0`, `.`, `M+` (shift `M-`, alpha `M`), `ANS` (shift `TUTOR IA`), `=` (Azul `#2E86DE`).

## 3. Entrada 100 % por Teclado Físico en Todos los Modos
- **PROHIBIDO usar `TextField` nativos de Android que abran el teclado virtual del sistema.** El teclado físico de la calculadora es la única fuente de entrada.
- **Modos de Expresión (Modos 1, 2 y 6 - Calcular, Ecuaciones 1.º Grado e Identidades Notables):**
  - Escribe directamente en el buffer de expresión (`_rawInput`) permitiendo usar números, signos, potencias, fracciones y la variable `x` (`ALPHA` + `)`).
- **Modos por Coeficientes (Modo 3, 4, 5, 7 - 2.º Grado, Ruffini, Sistemas 2x2 y Parábolas):**
  - Usa el componente `CasioCoefficientView`: muestra la plantilla matemática en la LCD con celdas `[ a ]x² + [ b ]x + [ c ] = 0`.
  - La celda activa se resalta con fondo inverso de alto contraste.
  - Al pulsar números, `-` o `/` en el teclado físico, se escriben dentro de la celda activa.
  - Al pulsar `=` o `◀` / `▶` del D-Pad, se confirma y se pasa a la celda siguiente/anterior. Al pulsar `=` en la última celda, se ejecuta el solver y se muestran los pasos navegables con `◀` y `▶` o con `=`.

## 4. Reglas Definitivas de `AC` y `DEL`
- **`AC` (All Clear):** Funciona SIEMPRE. Cierra la resolución paso a paso, vacía las celdas de coeficientes o resetea la expresión a `0`, y apaga `SHIFT` y `ALPHA`.
- **`DEL`:** Si se están viendo pasos de una solución, pulsar `DEL` sale de la vista de pasos y regresa a la plantilla o expresión editable (comportamiento real Casio). Si se está escribiendo, borra el último carácter.

## 5. Auto-Redimensionado en Pantalla LCD (`CasioLcdScreen`)
- Envuelve SIEMPRE el renderizado principal de `Math.tex` dentro de:
  ```dart
  LayoutBuilder(
    builder: (context, constraints) => ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: constraints.maxWidth,
        maxHeight: constraints.maxHeight,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: isMultiLine ? Alignment.center : Alignment.centerRight,
        child: Math.tex(...),
      ),
    ),
  )
  ```
- Esto garantiza que expresiones largas o matrices de Ruffini reduzcan suavemente su tamaño sin cortarse jamás ni provocar `RenderFlex overflowed`.

## 6. Blindaje contra Roturas en `flutter_math_fork`
1. Elimina cualquier carácter `\r` (`replaceAll('\r', '')`) antes de pasarlo a `Math.tex` para evitar la excepción `CrNode`.
2. Proporciona siempre `onErrorFallback: (err) => Text(...)` en todos los widgets `Math.tex`.
3. Normaliza cualquier tilde o carácter no ASCII dentro de `\text{...}` para que KaTeX no lance excepciones.
