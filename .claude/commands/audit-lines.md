---
description: Lista los archivos .dart más largos de lib/ (límite 500, objetivo <=450)
---
Ejecuta `find lib -name '*.dart' -exec wc -l {} + | grep -v ' total$' | sort -rn | head -25` y muestra la tabla.
Marca con ⚠️ los >450 líneas y con ❌ los >=500. No modifiques nada.
