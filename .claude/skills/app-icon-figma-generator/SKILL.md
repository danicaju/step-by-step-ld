---
name: app-icon-figma-generator
description: >
  Diseña y genera el sistema de iconos oficiales estilo Figma / iOS / Android Adaptive
  y PWA para la aplicación STEP-BY-STEP LD con estética industrial Formato 1 (Casio
  ClassWiz fibra de carbono tejida + cristal LCD verde líquido), aplicando criterios
  anti-slop, geometría maestra 1024x1024 px y zonas seguras adaptativas.
---

# Skill: Sistema de Iconos Oficiales `STEP-BY-STEP LD` (Formato 1)

## 1. Principios de Diseño (`anti-slop` + `casio-classwiz-ui`)
- **Prohibición de artificios genéricos (*anti-slop*):** Prohibido usar destellos/estrellas violetas (`#7C5CFF`), brillos neón difuminados, degradados arcoíris o etiquetas de marketing redundantes.
- **Autenticidad industrial ClassWiz Iberia:** Superficie mate de fibra de carbono tejida, biseles mecanizados con catchlight cenital contenido, cristal líquido verde `#DDE6DF` con marco hundido real y 4 teclas físicas abombadas con alto contraste legible incluso a `32×32 px` (favicon).

---

## 2. Especificaciones de Geometría y Lienzo Maestro
- **Resolución Maestra:** `1024 × 1024 px`.
- **Variantes Exportadas:**
  - `assets/icon/app_icon.png`: **100 % opaco** (`remove_alpha_ios: true`), requerido por iOS App Store, macOS, Windows y PWA.
  - `assets/icon/app_icon_foreground.png`: Fondo **100 % transparente** para **Android Adaptive Icons**, con toda la composición escalada (`0.72×`) y centrada para garantizar un **margen de seguridad perimetral ≥ 20 %** (contenido dentro del círculo central seguro de Android Adaptive).
  - `adaptive_icon_background`: Color sólido hexadecimal `#181A1E`.

---

## 3. Paleta Cromática Oficial (Formato 1)
| Elemento | Color Hex | Rol Visual |
|---|---|---|
| **Chasis Fibra de Carbono** | `#181A1E` | Fondo carbón oscuro con patrón diagonal 2×2 tejido |
| **Bisel Interior Metálico** | `#2A2E37` | Marco interior mecanizado con catchlight superior `#3D4350` |
| **Siglas Cabecera `LD`** | `#F8FAFC` / `#CBD5E1` | Tipografía geométrica industrial bold blanca/plata |
| **Micro-etiqueta `STEP`** | `#E5A93C` | Insignia ámbar industrial junto a `LD` (tinta `#141619`) |
| **Pantalla LCD Hundida** | `#DDE6DF` | Cristal líquido verde Casio con *inset shadow* de `12 px` |
| **Tinta LCD Matemática** | `#0F172A` | Expresión `\frac{\sqrt{x}}{2}` de alto contraste |
| **Flechas de Paso `◀ ▶`** | `#2563EB` | Navegación vectorial de pasos en azul Casio |
| **Tecla `SHIFT` (Sup-Izq)** | `#E5A93C` | Tecla abombada dorada Casio con texto oscuro `#141619` |
| **Tecla `ALPHA` (Sup-Der)** | `#E05252` | Tecla abombada roja coral con texto blanco |
| **Tecla `a/b` (Inf-Izq)** | `#22252B` | Tecla abombada negra carbón con fracción apilada blanca |
| **Tecla `=` (Inf-Der)** | `#3B78E7` | Tecla abombada azul Casio con signo `=` vectorial blanco |

---

## 4. Arquitectura de Capas (`1024 × 1024 px`)

```
+-------------------------------------------------------------+
|  Chasis #181A1E · Fibra de carbono diagonal + Bisel #2A2E37 |
|                                                             |
|    LD  [ STEP ]  ----------------------------------------   |
|                                                             |
|    +---------------------------------------------------+    |
|    |  LCD #DDE6DF (inset shadow 12 px)                 |    |
|    |         √x                                        |    |
|    |        ────                        ◀  ▶           |    |
|    |         2                       (#2563EB)         |    |
|    +---------------------------------------------------+    |
|                                                             |
|    +---------------------+   +-------------------------+    |
|    |    SHIFT (#E5A93C)  |   |     ALPHA (#E05252)     |    |
|    +---------------------+   +-------------------------+    |
|    +---------------------+   +-------------------------+    |
|    |     a/b (#22252B)   |   |       = (#3B78E7)       |    |
|    +---------------------+   +-------------------------+    |
+-------------------------------------------------------------+
```

### Capa 1: Chasis Fibra de Carbono y Bisel Interior
- Relleno opaco `#181A1E` sobre `1024 × 1024 px`.
- Patrón diagonal tejido (`2×2 twill` en micro-celdas a ±45°) en tonos `#1E2126` / `#131519` con sutil brillo de urdimbre `#2A2E37`.
- Bisel interior metálico oscuro `#2A2E37` en `inset 46 px` (`RRect radius: 176 px`, concéntrico con el recorte squircle de iOS) con ranura interior `#0F1114`.

### Capa 2: Cabecera `LD` + `STEP` (`Y: 96–162 px`)
- `LD` en tipografía geométrica industrial bold blanca/plata (`X: 128 px`) acompañada inmediatamente a su derecha por la micro-etiqueta ámbar `#E5A93C` (`STEP`) y una línea metálica acanalada hasta `X: 896 px`.

### Capa 3: Mini Pantalla LCD Hundida (`Y: 184–456 px`, `768 × 272 px`)
- Cristal `#DDE6DF` (`radius: 26 px`) con recorte interno y *inset shadow* oscura de `12 px` para profundidad física real.
- Fórmula `\frac{\sqrt{x}}{2}` en tinta `#0F172A` (radical vectorial grueso + `x` itálica KaTeX + barra horizontal + `2` bold KaTeX).
- Flechas vectoriales **`◀ ▶`** en azul Casio `#2563EB` alineadas a la derecha dentro de la LCD.

### Capa 4: Cuadrícula `2×2` de Teclas Físicas Abombadas (`Y: 492–892 px`)
- 4 teclas de `370 × 187 px` (`gap: 28 × 26 px`, `radius: 28 px`) alojadas en rebajes oscuros `#0D0E12`, con falda lateral 3D, superficie convexa abombada y borde cenital nítido:
  1. Arriba-Izquierda: `SHIFT` (`#E5A93C`).
  2. Arriba-Derecha: `ALPHA` (`#E05252`).
  3. Abajo-Izquierda: `a/b` (`#22252B`).
  4. Abajo-Derecha: `=` (`#3B78E7`).

---

## 5. Pipeline de Generación en Dart y Multiplataforma
1. **Generador Vectorial:** `flutter test tool/generate_app_icon.dart` (carga fuentes TTF reales desde `flutter_math_fork` / Flutter SDK / sistema para evitar bloques *Ahem* en el entorno de tests) y exporta `assets/icon/app_icon.png` y `assets/icon/app_icon_foreground.png`.
2. **Inyección Multiplataforma:** `flutter pub get` seguido de `dart run flutter_launcher_icons` para regenerar iconos de Android (`launcher_icon`), iOS (`AppIcon.appiconset`), Web/PWA (`web/icons/`, `favicon.png`) y Windows (`app_icon.ico`).
