---
description: QA completo: límite <500 líneas en lib/, dart analyze y flutter test (solo errores)
---
Ejecuta en orden y reporta SOLO los problemas (si todo pasa, responde "QA OK" en una línea):

1. Archivos `.dart` de `lib/` con >= 500 líneas:
   `find lib -name '*.dart' -exec wc -l {} + | grep -v ' total$' | awk '$1>=500'`
2. `dart analyze` (debe dar 0 issues).
3. `flutter test` (100 % en verde; si falla, muestra solo los tests fallidos y su causa).

No arregles nada sin que se pida; resume los fallos por archivo.
