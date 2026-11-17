---
name: goodnotes-latex-exporter
description: >
  Exporta desarrollos matemáticos paso a paso, tablas de Ruffini y gráficas de la
  calculadora como imágenes PNG de alta resolución con fondo transparente (stickers
  para Goodnotes y pizarras digitales) o como bloques de código LaTeX listos para
  compilar en documentos de apuntes y exámenes.
---

# Skill: Exportador de Stickers para Goodnotes y Apuntes LaTeX

## Objetivo
Permitir que el profesor o el alumno exporte en un solo toque (`[SHIFT]` + `[EXPORT]`) el desglose completo de una operación desde la pantalla de la calculadora hacia aplicaciones de toma de apuntes (Goodnotes, Notability, Samsung Notes) o documentos `.tex`.

## Especificación Técnica de Exportación PNG (Modo Sticker Goodnotes)
1. **Renderizado Off-Screen de Alta Densidad:**
   - Nunca captures directamente la pantalla con el fondo verde/oscuro de la LCD si el modo seleccionado es "Sticker Apuntes".
   - Construye un widget dedicado `GoodnotesStickerCanvas` envuelto en un `RepaintBoundary` con `backgroundColor: Colors.transparent`.
   - Captura la imagen usando `RenderRepaintBoundary.toImage(pixelRatio: 3.0)` para que al hacer zoom en un iPad o tablet Android los símbolos matemáticos se vean perfectamente nítidos.
2. **Estética de Tinta de Pizarra / Cuaderno:**
   - Fórmulas principales: Tinta azul oscuro o carbón (`#1E293B`) para que contraste sobre papel blanco, cuadriculado o amarillento en Goodnotes.
   - Cambios algebraicos o factores comunes (como el m.c.m.): Azul vivo (`#2563EB`).
   - Avisos de signos o trampas de examen: Rojo carmesí (`#DC2626`).
   - Cada paso incluye a la izquierda su etiqueta numerada (`Paso 1`, `Paso 2`) con una flecha de implicación `\Rightarrow`.
3. **Compartir e Integrar con el Sistema:**
   - Guarda el buffer PNG temporalmente con `path_provider` (`getTemporaryDirectory()`) con un nombre descriptivo (`resolucion_paso_a_paso.png`) y lanza el menú nativo mediante `Share.shareXFiles([XFile(path, mimeType: 'image/png')])` (del paquete `share_plus`), lo que permite arrastrar o copiar directamente a Goodnotes.

## Especificación de Exportación a Código LaTeX Puro
- Incluye siempre una segunda acción rápida ("Copiar bloque LaTeX") que copie al portapapeles (`Clipboard.setData`) la secuencia completa de `StepByStepResolution` envuelta en un entorno `align*` de `amsmath`, alineada por el signo `=` (`&=`) y con las notas pedagógicas comentadas o en `\text{...}` a la derecha:

```latex
\begin{align*}
  \text{Expresión inicial:} \quad & \frac{4}{6} + \frac{5}{4} \\
  \text{1. Simplificar y m.c.m.}(3, 4) = 12: \quad & \frac{2 \cdot 4}{12} + \frac{5 \cdot 3}{12} \\
  \text{2. Operar numeradores:} \quad & \frac{8 + 15}{12} = \mathbf{\frac{23}{12}}
\end{align*}
```
