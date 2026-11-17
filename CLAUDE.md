# STEP-BY-STEP LD (`casio_tutor_calc`)
Calculadora Casio ClassWiz paso a paso (Flutter/Dart, ESO/Bachillerato España). Resultados siempre como `StepByStepResolution` en LaTeX.

## Mapa
- `lib/domain/math_engine/`: `ast/` (AST tipado, sin eval de strings), `parser/` (tokenizer, parser, navegación cursor/plantillas), `solvers/` (un solver por modo, subcarpetas por tema), `core/`, `models/`.
- `lib/presentation/`: `screens/` (calculator_screen_*: teclado, d-pad, solvers, toolbars), `widgets/` (LCD en `lcd/`, teclado, editores matriz/vector/complejo/cálculo), `painters/`, `utils/`.
- `test/` espejo del dominio + auditorías (`qa_exhaustive_audit_test`, `audit_all_latex_test`).

## 12 modos (3 páginas de 4)
P1: M1 Calcular · M2 Ecuaciones 1.º/2.º · M3 Sistemas 2x2/3x3 · M4 Polinomios/Ruffini
P2: M5 Estudio de Funciones · M6 Inecuaciones · M7 Sistemas de Inecuaciones 1D/2D · M8 Estadística 1 Variable
P3: M9 Matrices · M10 Vectores 2D/3D · M11 Complejos (a+bi ⬄ r_α) · M12 Derivadas e Integrales
Fuente: `lib/presentation/widgets/lcd/lcd_mode_menu.dart`.

## Reglas de oro (inquebrantables)
1. **< 500 líneas** por `.dart` en `lib/` (mantener <= 450). Si se acerca, dividir en archivos/helpers.
2. **LaTeX (`flutter_math_fork`)**: sin `á é í ó ú ñ ¿ ¡` dentro de `\text{}`/`\mathrm{}` (texto didáctico va en `shortTitle`/`pedagogicalNote`/`warningTrick` con `Text()`); llaves en sub/superíndices múltiples (`x_{10}`, `z_{1}`, `r_{\alpha}`); `\cdot` para el producto; sin `\r`; `Math.tex` con `onErrorFallback` y `FittedBox`.
3. **Estética Casio (anti-slop)**: chasis `#181E29`, LCD `#C8D6CD`/`#BDCEBE`, texto `#1A2530`, SHIFT `#E5A93C`, ALPHA `#E05D5D`. Prohibido azul/cian/morado en botones o bordes (`#2563EB` solo en LaTeX).
4. **D-Pad físico 100 % operativo** (◀ ▶ ▲ ▼ OK/=) en menús, selectores, matrices, tablas y editores. Sin `TextField` nativo; arranque limpio en `0`, sin presets.
5. **Verificación tras cada cambio**: `dart analyze` (0 issues) y `flutter test` (todo verde).

## Comandos
- `/qa` verificación completa · `/audit-lines` archivos más largos.
- Skills en `.claude/skills/`: `casio-math-engine-step` (motor/LaTeX), `casio-classwiz-ui` (UI/teclado/LCD), `casio-anti-slop` (paleta) + skills genéricas `dart-*`/`flutter-*`.
- MCP (`.mcp.json`): dart, context7, firebase, stitch.
