# LA SED MUSIC APP — PROMPT DE CONTINUIDAD

**Versión:** 0.5
**Fecha:** 10/09/2026
**Chat de origen:** `3 - F2b: Importador Apple Notes`
**Siguiente chat:** `4 - Fase 3: Song Editor` (o cierre de pulido de Fase 2b, ver sección 9)

> Pega este documento completo al inicio de un chat nuevo de Claude para retomar el proyecto exactamente donde quedó.

---

## 1. CÓMO DEBES RESPONDERME

- Ingeniero de datos. Nunca he programado en Swift/Xcode. Instrucciones explícitas, un paso por línea, sin comprimir varias acciones en una oración.
- No empieces dándome la razón. Cuestiona mi suposición o señala lo que paso por alto, antes de cualquier otra cosa.
- Etiqueta confianza: **(seguro)** / **(probable)** / **(suposición)**.
- Sé breve. Nada de "buena pregunta", "tienes razón".
- Indica en qué parte de la fase vamos (checklist), no solo al cerrar el chat.
- Al final de cada respuesta, una línea con % de chat usado y tokens estimados.
- Código completo de un archivo: dilo explícito ("archivo completo, reemplázalo entero").
- **Antes de escribir código que dependa de archivos existentes (Models.swift, AppDatabase.swift, cualquier Repository), pide el archivo tal cual está — no lo adivines.** Ya pasó dos veces en Fase 2b que adivinar casi rompe el build.
- Cuando pidas que corra algo en Xcode y el resultado no cuadre, pregunta primero si tocó el botón/menú correcto antes de asumir que el código falló (pasó con Test Plans, esquemas, target membership).

---

## 2. QUÉ ES EL PROYECTO

App multiplataforma (Swift/SwiftUI, GRDB/SQLite) para canciones, letras, acordes y setlists de la banda **La Sed**. Reemplaza Apple Notes.

```
CANCIONES → LETRAS/ACORDES → CSV → SETLISTS → BLOQUES → PERFORMANCE
```
Prioridad: **ESTABILIDAD > ARQUITECTURA > VELOCIDAD > FUNCIONALIDADES**

---

## 3. DECISIONES CERRADAS (no volver a discutir)

Heredadas de v0.1–v0.4: GRDB/SQLite, AST propio en JSON (no ChordPro), Apple Notes antes que CSV, Android futuro posible, escala 1,000 canciones, soft delete, sync tracking desde v1, song_code formato `LS-XXXX` con `suggestNextCode()`, `normalizeForMatching()` única función de normalización, UI tipo NavigationSplitView.

**Nuevas de este chat (Fase 2b):**

| Tema | Decisión | Motivo |
|---|---|---|
| **Extracción de notas** | Script AppleScript (`exportar_notas_lased.applescript`), no manual | 217 notas a mano era inviable |
| **Notación de acordes** | Se decide **UNA VEZ por archivo completo** (evidencia fuerte: alteración/calidad explícita), nunca por línea | Sílabas de solfeo (Do,Re,Mi,Fa,Sol,La,Si) son palabras españolas comunes; decidir por línea da falsos positivos |
| **Línea "anclable" vs "resumen"** | Solo líneas con espaciado real (doble espacio) se anclan carácter-por-carácter a la letra siguiente. Progresiones compactas tipo "D - Bm - G - A" o "E A E A" son **"resumen"**, nunca se anclan | Un resumen de acordes al inicio de la nota no tiene posición real por sílaba; anclarlo a la primera línea de letra sería incorrecto |
| **Tabs en notas** | Se normalizan a 4 espacios antes de calcular posición de carácter | Los .txt exportados mezclan tabs y espacios para alinear |
| **Carácter U+FFFC** | Indica imagen/objeto incrustado que `plaintext` no pudo exportar → nota marcada `requiereRevision`, nunca se descarta | Pérdida de contenido debe ser visible, no silenciosa |
| **contentAST mínimo (adelantado de Fase 3)** | `sections → lines → segments{chord?, text}`, con `Chord` estructurado (root/accidental/quality/extension/bassRoot) neutral a notación — nunca texto crudo | Fase 2b necesitaba un target de datos antes de que Fase 3 exista formalmente; se define lo mínimo ahora, se completa (StyleSheet, marks) en Fase 3 real |
| **Persistencia del AST** | Migración `v3_contenido_importado`: columna `contentASTJson TEXT` nullable en `song`, serializado con `JSONEncoder` | Sin esto, importar creaba la canción pero perdía la letra completa |
| **Artista en notas importadas** | Campo obligatorio, editable, con **sugerencia automática** por similitud de título contra tu Excel real (nunca autoritativo) | Apple Notes no trae artista; pedirlo 217 veces a ciegas era invivible |
| **Motor de sugerencia de artista** | `ArtistSuggestionService`: Levenshtein normalizado + comparación contra título completo Y contra el prefijo antes de " - " (sin lista de palabras clave tipo "remaster"/"live") | Los sufijos de gira/remaster en tu Excel son impredecibles; una lista de palabras siempre queda corta (pasó con "Prófugos - Gira Me Verás Volver") |
| **Sugerencia en vivo/estudio** | Si el título completo matcheado contiene "vivo/live/gira/tour/unplugged/concierto" → sugiere `isLive = true` en un Toggle editable | Mismo principio: sugerencia, no dato confirmado |
| **Duplicados al importar** | Antes de crear, se busca por `matchKey` (mismo cálculo que usa `SongRepository`); si existe, alerta con opción de crear de todos modos | Evita duplicar canciones que ya están en la biblioteca por Fase 2 |

---

## 4. ARCHIVOS NUEVOS/MODIFICADOS ESTE CHAT

```
LaSed/LaSed/
├── AppDatabase.swift          ← + migración v3_contenido_importado (columna contentASTJson)
├── Models.swift                ← Song + var contentASTJson: String?
├── NotesImportParser.swift     ← NUEVO. Parser .txt → ParsedNoteResult (AST + issues)
├── NotesImportPreviewView.swift← NUEVO. Pantalla de revisión + botón Importar → SongRepository
├── ArtistSuggestionService.swift← NUEVO. Sugerencia de artista + señal de en vivo
├── RepertorioConocido.csv      ← NUEVO (Copy Bundle Resources, no target de código). 214 pares título/artista extraídos de tu Excel real
LaSedTests/
└── NotesImportParserTests.swift← NUEVO. 7 tests, todos en verde
```

Herramientas fuera de la app (uso puntual, no se integran a Xcode):
- `exportar_notas_lased.applescript` — corrido una vez, exportó 217 notas a `~/Downloads/LaSed_Notas_Export/`
- `triage_notas_lased_v3.py` — perfiló las 217 antes de escribir el parser (no se vuelve a correr salvo que cambie el set de notas)

---

## 5. TRIAGE REAL DE LAS 217 NOTAS (contexto para no repetir análisis)

| Métrica | Cantidad |
|---|---|
| Notación inglesa | 171 |
| Notación solfeo | 13 |
| Sin evidencia de notación (probable solo-letra genuino) | 33 |
| Con carácter de reemplazo (posible contenido perdido) | 36 |
| Con tabs mezclados con espacios | 82 |
| Requiere revisión manual (unión) | 85 (39%) |

---

## 6. PUNTO EXACTO DONDE QUEDASTE

Fase 2b **funcionalmente completa** en flujo de una nota a la vez:
1. Abrís `NotesImportPreviewView` (hoy vive temporalmente como raíz de `LaSedApp.swift` en lugar de `SongLibraryView()` — **hay que revertir eso o darle una entrada propia en la UI real**, ver pendientes).
2. Eliges la carpeta `LaSed_Notas_Export`.
3. Lista con ✅/⚠️/●, clic en una nota → detalle con acordes en azul sobre letra.
4. Campo de artista prellenado por sugerencia (o vacío si no hay match ≥60% de confianza), toggle de en vivo, botón "Importar a biblioteca".
5. Verifica duplicado por `matchKey`, si no existe crea el `Song` con `contentASTJson` poblado.

**Falta para cerrar Fase 2b de verdad:**
1. Revertir `LaSedApp.swift` a `SongLibraryView()` como raíz, y darle a `NotesImportPreviewView` una entrada real (botón/menú) en vez de swap manual para pruebas.
2. **Importación en lote** (confirmado por el usuario, no opcional): botón para importar todas las notas ✅ de una vez, no nota por nota.
3. **Ingreso manual de canciones** que no vengan de una nota (ya existe como concepto en `AddSongView` de Fase 2 — evaluar si esta pantalla debe fusionarse con esa o quedar separada).
4. **Campo de artista sugerido debe bloquearse tras aceptarse**, no quedar editable libremente — el usuario espera un estado "confirmado" (solo lectura) vs "sugerido" (editable), con una acción explícita para pasar de uno a otro.
5. **Limpieza de títulos con prefijos de bloque**: notas con prefijos tipo "AUX", números u otros códigos delante del nombre real (ej. "12.BABY I LOVE YOUR WAY") deben separar ese prefijo del título real antes de buscar coincidencia de artista — hoy el matcher usa el título completo tal cual, incluido el prefijo.
6. **Multi-artista por canción**: una misma canción puede tener versiones de distintos artistas (ejemplo real: "Baby I Love Your Way" — Big Mountain vs. Peter Frampton, autor original). Regla acordada: **manda el artista que aparece en el Excel** (`RepertorioConocido.csv`) como fuente de verdad primaria, no la sugerencia genérica ni el conocimiento general de Claude.
7. Pulir presentación general de la pantalla de revisión — observaciones pendientes del usuario, deliberadamente pospuestas.
8. Confirmar visualmente contra varias notas reales más que la sugerencia de artista y el toggle de en vivo se comportan bien en general.

---

## 7. ROADMAP

| Fase | Contenido | Estado |
|---|---|---|
| 0 | Relevamiento, arquitectura, entorno | ✅ |
| 1 | Esquema SQLite + repositorios + tests | ✅ |
| 2 | Song Library (CRUD, FTS5, matchKey, alias, UI) | ✅ |
| 2b | Importador Apple Notes (.txt → AST → revisión → SongRepository) | 🔵 **funcional, pulido pendiente (sección 6)** |
| 3 | Song Editor (AST completo, StyleSheet, marks inline) — **ya tiene un mínimo adelantado desde 2b, falta completarlo** | ⬜ |
| 4 | Setlists (bloques, reordenar, duplicar) | ⬜ |
| 5 | CSV → Matching Engine → Setlist automático | ⬜ |
| 6 | Performance Mode | ⬜ |
| 7 | Sincronización Supabase | ⬜ |

---

## 8. APRENDIZAJES OPERATIVOS NUEVOS (Fase 2b)

1. **AppleScript puede automatizar exportación bulk de Apple Notes** vía `plaintext` property — evita exportar a mano nota por nota. Ojo: `plaintext` convierte imágenes/objetos incrustados en U+FFFC (Object Replacement Character), perdiendo ese contenido silenciosamente si no se detecta explícitamente.
2. **Nunca confiar un regex/heurística de clasificación de texto sin probarlo contra datos reales primero.** Dos bugs reales de este chat: (a) anclas `^$` de regex Python aplicadas sobre el archivo completo en vez de por línea — invalidó un resultado completo; (b) heurística de línea-de-acorde que exigía doble espacio no reconocía progresiones compactas tipo "D - Bm - G - A", muy comunes en los datos reales.
3. **Validar lógica en Python antes de traducir a Swift sigue siendo la práctica correcta** (ya establecida desde Fase 1) — se detectaron y corrigieron 2 bugs de diseño en Python antes de escribir una sola línea de Swift, evitando iteraciones costosas en Xcode.
4. **Xcode Test Plans puede quedar "en memoria" sin guardar a disco** — si editas el Test Plan (agregar/activar un target) y no le das clic explícito a "Save" en el diálogo que aparece, el cambio no persiste y `⌘U` sigue sin correr el target nuevo.
5. **`⌘U` puede quedar "pegado" a la última selección específica del Test Navigator** (ej. solo `LaSedUITests`) — hay que correr desde el nodo raíz del proyecto en el Test Navigator (⌘6), no desde un target o test individual, para correr todo.
6. **Al pedir "reemplaza el archivo entero", cualquier edición manual que el usuario haya hecho en Xcode (ej. agregar `nonisolated` para resolver un error de actor isolation) se pierde** si Claude no la propaga al archivo fuente que mantiene. Antes de regenerar un archivo completo, revisar si hubo fixes manuales del usuario en el camino.
7. **Un CSV de referencia (como tu Excel de repertorio) es reutilizable para más que su propósito original** — se usó para sugerir artista por similitud de título, no solo para el matching de Fase 5. Vale la pena preguntar "¿ya tienes datos que resuelvan esto?" antes de pedirle al usuario que genere algo nuevo.
8. **Listas de palabras clave para limpiar texto (ej. "remaster", "live") son inherentemente frágiles** — siempre va a aparecer un caso no anticipado (pasó con nombres de gira: "Gira Me Verás Volver"). Preferir un enfoque estructural (comparar también contra el prefijo antes de un separador conocido como " - ") en vez de una lista de excepciones.

---

## 9. REGLA DE TRABAJO

Antes de escribir código: analiza, identifica riesgos, explica decisiones. Después implementa.
Antes de modificar código existente: pide el archivo real, analiza dependencias, evita breaking changes.
Cada funcionalidad nueva es un módulo independiente.
No introducir dependencias externas si Swift/SwiftUI resuelve el problema.
Validar lógica compleja (parsers, heurísticas de clasificación, algoritmos de similitud) en Python contra datos reales antes de traducir a Swift — no hay toolchain de Swift disponible para Claude, así que la validación previa es la única red de seguridad real.
