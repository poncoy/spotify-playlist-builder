# LA SED MUSIC APP — PROMPT DE CONTINUIDAD

**Versión:** 0.7
**Fecha:** 10/09/2026
**Chat de origen:** `5️⃣ F2b: song editor pre cierre - La Sed App`
**Siguiente chat:** `6️⃣ F3: Song Editor — edición real de acordes + StyleSheet` (ver sección 10 para alternativa)

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
- Antes de escribir código que dependa de archivos existentes, **lee el archivo real** vía Filesystem (ver sección 9) — no lo adivines.
- Tienes acceso de lectura/escritura directo a mi Mac vía el conector Filesystem: `/Users/pauloncoy/Library/CloudStorage/OneDrive-Personal/` (incluye el proyecto Xcode completo en `La Sed/2026/App/LaSed/LaSed/` y las notas en `LaSed_Notas_Export/`), además de `/Users/pauloncoy/Desktop/ordenar ya` y `/Users/pauloncoy/Downloads`. Un conector *separado* llamado "Filesystem" (mayúscula) da estos paths; uno llamado "filesystem" (minúscula) solo da Desktop/Downloads sin el OneDrive — si una herramienta falla con "Access denied", prueba con el otro conector antes de asumir que no tienes acceso.
- Sigues sin poder compilar ni ejecutar. Todo cambio tuyo requiere que yo corra ⌘B y te confirme.
- **Nuevo en este chat — disciplina de cambios de layout:** cuando un fix de UI no probado se encadena con otro fix no probado, para y pide confirmación de que el anterior funcionó antes de apilar el siguiente. Este chat tuvo 3-4 rondas seguidas de "arreglo esto, se rompe aquello" (ScrollView anidado sin altura, luego con altura fija rompiendo el Form, luego afectando al importador también) — evitable si cada capa se hubiera validado antes de tocar la siguiente.
- **Nuevo — orden de argumentos de `.frame()`:** Swift exige el orden exacto `minWidth, idealWidth, maxWidth, minHeight, idealHeight, maxHeight` en esa llamada. Nombrar los parámetros correctamente no alcanza si el orden está mezclado — es un error de compilación real, no un lint.
- **Nuevo — diagnóstico con datos reales sigue siendo la regla, y funcionó:** el bug de "GUITARRAS BLANCAS" (acordes pegados sin espacio) se resolvió leyendo el `.txt` real de la nota, no adivinando. Seguir haciendo esto antes de tocar el parser.

---

## 2. QUÉ ES EL PROYECTO

App multiplataforma (Swift/SwiftUI, GRDB/SQLite) para canciones, letras, acordes y setlists de la banda **La Sed**. Reemplaza Apple Notes.

```
CANCIONES → LETRAS/ACORDES → CSV → SETLISTS → BLOQUES → PERFORMANCE
```
Prioridad: **ESTABILIDAD > ARQUITECTURA > VELOCIDAD > FUNCIONALIDADES**

---

## 3. DECISIONES CERRADAS (no volver a discutir)

Heredadas de v0.1–v0.6: GRDB/SQLite, AST propio en JSON, Apple Notes antes que CSV, Android futuro posible, escala 1,000 canciones, soft delete, sync tracking desde v1, song_code `LS-XXXX`, `normalizeForMatching()` única función de normalización, notación de acordes decidida una vez por archivo completo, `contentASTJson` (migración v3), importador con lote+selección previa+deshacer+resumen visual (Fase 2b cerrada en v0.6).

**Nuevas de este chat:**

| Tema | Decisión | Motivo |
|---|---|---|
| **Arranque de Fase 3** | Empezar por **visualizar/editar contenido ya importado**, no por extender el modelo (marks/StyleSheet) a ciegas | Las ~217 notas importables ya guardan `contentASTJson`, pero antes de este chat era invisible fuera del importador — había que resolver eso antes de diseñar capas nuevas sobre un contenido que nadie podía ver todavía |
| **Editor de canción: pestañas, no todo junto** | `EditSongView` dividido en dos pestañas con `Picker(.segmented)`: "Datos" (metadata editable) y "Letra y acordes" (solo lectura, ocupa toda la pantalla) | Pedido explícito: mezclar campos editables con el chart de acordes en un solo `Form` resultaba confuso |
| **`ChordChartView.swift` como componente compartido** | Vista de solo lectura extraída del importador, reutilizada en `EditSongView`. Internamente **solo tiene scroll horizontal, nunca altura fija** | El texto monoespaciado no puede envolver línea (rompería el alineamiento acorde/sílaba). La restricción de altura la aplica quien la usa (`EditSongView`, porque vive en un `Form`), no el componente — así no afecta a otros usos (el importador, que vive en un `ScrollView` simple sin ese problema) |
| **Idioma: selección, no texto libre** | `Picker` con lista fija (Español, Inglés, Italiano, Alemán, Portugués, Francés) en `EditSongView` y `AddSongView`. Si una canción ya tenía un valor libre viejo que no matchea, se agrega como opción extra automáticamente (no se pierde) | Pedido explícito — texto libre generaba valores inconsistentes |
| **Barra de identificación de módulo (`ModuleHeaderBar.swift`)** | Componente nuevo: texto en mayúsculas sobre fondo de color sólido, primer elemento visible de cada pantalla principal (Biblioteca, Editor de canción, Importador y sus 3 sub-vistas, Agregar canción) | Pedido **tres veces** en este chat ("no se entiende en qué parte de la app uno está"). No se resolvió con `.navigationSubtitle` porque el estilo de ventana de esta app (barra de título minimalista) puede no mostrarlo de forma notoria |
| **Ícono de estado en lista de notas: `music.note`, no `circle`** | El círculo vacío se confundía con un checkbox seleccionable (confusión reportada **dos veces**, ya estaba anotada como pendiente P4 en v0.6) | Un ícono de estado no-interactivo nunca debe parecerse a un control real de macOS |
| **`AddSongView` ahora resizable + 4 campos nuevos** | `.frame(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:)`; se agregan ¿en vivo?, país, idioma (picker), nivel — ya existían en `Song` desde Fase 2 pero faltaban en el formulario de alta | Antes el sheet no se podía agrandar; los campos solo se podían cargar editando la canción después de crearla |
| **`SeleccionLoteView` se autoselecciona si llega vacía** | Si al terminar de calcular sugerencias `seleccion.isEmpty`, se preselecciona todo lo elegible por defecto | Bug real reportado: "Importar 0 de 118" con todo destildado al abrir |
| **Buscador en `SeleccionLoteView`** | `.searchable()` filtrando por título o artista | Con 118+ candidatas en 70+ artistas no había forma de encontrar una en particular sin scrollear a mano |
| **Fix de parser: progresiones largas con doble espacio no se anclan contra una línea mucho más corta** | En `NotesImportParser.swift`, `siguienteEsLetra` ahora exige que la columna del último acorde no exceda `siguiente.count + 10` | Caso real (GUITARRAS BLANCAS): la línea "G# - A# - G# - A#..." se anclaba contra " (percusión)" (12 caracteres), dejando los acordes pegados sin espacio |
| **El fix de parser NO es retroactivo** | Canciones ya importadas antes de este fix conservan el AST viejo en `contentASTJson` hasta que se borren y reimporten | No existe (todavía) una función de "reprocesar sin borrar" — ver pendiente P9 |

---

## 4. BUG REAL ENCONTRADO Y CORREGIDO (no reportado por el usuario)

`AddSongView.swift` no pasaba `contentASTJson` al crear un `Song` — parámetro obligatorio desde la migración v3 (Fase 2b), sin valor por defecto en el struct. Se agregó `contentASTJson: nil`. Si "Agregar canción" fallaba o no compilaba antes de este chat, era por esto.

---

## 5. ARCHIVOS MODIFICADOS/CREADOS ESTE CHAT

```
LaSed/LaSed/
├── ChordChartView.swift        ← NUEVO. Vista de solo lectura del AST, extraída del importador. Solo scroll horizontal.
├── ModuleHeaderBar.swift       ← NUEVO. Barra de color sólido con nombre de módulo, usada en 4 pantallas.
├── EditSongView.swift          ← Reescrito: pestañas "Datos"/"Letra y acordes", Idioma como Picker, ModuleHeaderBar.
├── AddSongView.swift           ← Reescrito: resizable, +4 campos (en vivo/país/idioma/nivel), fix contentASTJson faltante, ModuleHeaderBar.
├── SongLibraryView.swift       ← + ModuleHeaderBar arriba de la lista.
├── NotesImportParser.swift     ← Fix: progresiones largas con doble espacio ya no se anclan contra línea mucho más corta.
└── NotesImportPreviewView.swift ← + ModuleHeaderBar (lista, detalle, selección de lote); ícono "circle"→"music.note";
                                    SeleccionLoteView se autoselecciona si llega vacía + buscador (.searchable);
                                    reutiliza ChordChartView en vez de código duplicado.
```

Nada de esto fue compilado por Claude en este chat sin que el usuario confirmara — sí se llegó a un ⌘B exitoso (confirmado por capturas de pantalla funcionando) después de corregir un error real de orden de argumentos en `.frame()`.

---

## 6. ROADMAP

| Fase | Contenido | Estado |
|---|---|---|
| 0 | Relevamiento, arquitectura, entorno | ✅ |
| 1 | Esquema SQLite + repositorios + tests | ✅ |
| 2 | Song Library (CRUD, FTS5, matchKey, alias, UI) | ✅ |
| 2b | Importador Apple Notes (.txt → AST → revisión → SongRepository) | ✅ funcional — quedan P1-P8 (v0.6) + P9 (este doc), todos menores/no bloqueantes |
| 3 | Song Editor (AST completo, StyleSheet, marks inline) | 🔵 **EN PROGRESO** — visualización de solo lectura lista y probada (pestaña "Letra y acordes"); edición real de acordes/texto y StyleSheet/marks **no empezados** |
| 4 | Setlists (bloques, reordenar, duplicar) | ⬜ |
| 5 | CSV → Matching Engine → Setlist automático | ⬜ |
| 6 | Performance Mode | ⬜ |
| 7 | Sincronización Supabase | ⬜ |

---

## 7. APRENDIZAJES OPERATIVOS NUEVOS (este chat)

1. **Un `ScrollView` sin `.frame` de altura, anidado dentro de un `Form`/`Section` en macOS, rompe el layout de todo el `Form`** (contenido flotando fuera de lugar, tapando controles). No es solo un problema de "se ve feo" — desordena la vista entera.
2. **La restricción de altura/anchura de un componente reutilizable se aplica del lado de quien lo USA, no adentro del componente.** `ChordChartView` se usa en dos contextos distintos (un `Form` y un `ScrollView` simple) con necesidades de contención distintas — meter la restricción adentro del componente compartido rompe el caso que no la necesitaba.
3. **`.frame(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:)` exige ese orden exacto de argumentos.** Los nombres correctos no bastan si el orden está mezclado — error de compilación real: *"Argument 'maxWidth' must precede argument 'minHeight'"*.
4. **Íconos de estado no-interactivos nunca deben parecerse a controles reales de macOS** (checkboxes, radios). Un `circle` vacío al lado de cada fila de una lista se lee como "seleccionable" aunque no lo sea — mejor un glifo que no tenga análogo interactivo obvio (ej. `music.note`).
5. **`.navigationSubtitle` puede no ser suficientemente visible** en un estilo de ventana con barra de título minimalista/sin texto. Para comunicar "en qué parte de la app estás", un banner de color sólido dentro del contenido es más confiable que metadata de navegación del sistema.
6. **Cadenas largas de fixes de layout no probados se penalizan solas.** Cada iteración cuesta un ciclo completo de ⌘B + probar + capturar pantalla porque Claude no tiene toolchain — más razón para no apilar más de un cambio de layout arriesgado por vez en una zona que ya viene inestable.
7. Se reafirma el aprendizaje de Fase 2b: **diagnosticar con el archivo real antes de tocar el parser** siguió siendo la única forma confiable de encontrar el bug real (vs. adivinar por la captura de pantalla).

---

## 8. PENDIENTES REALES

**Heredados de v0.6 (sin tocar en este chat):** P1 (limpieza de prefijos de título), P2 (regla multi-artista), P3 ("115_" en detalle de nota), P4 (selección múltiple en lista principal — YA NO aplica tal como estaba planteado, el ícono que causaba la confusión se corrigió), P5 (deshacer granular por canción), P6 (alert de "Deshacer lote" sigue simple), P7 (tamaños de ventana arbitrarios), P8 (pulido visual general, pospuesto a propósito).

**Nuevos de este chat:**

| # | Item | Detalle | Prioridad |
|---|---|---|---|
| P9 | Reprocesar/reimportar una canción ya guardada sin borrarla | Necesario para que los fixes del parser (como el de este chat) apliquen a canciones ya importadas. Hoy la única forma es borrar y reimportar desde el `.txt` original | Media-alta — se va a repetir cada vez que se ajuste el parser |
| P10 | ¿Simplificar el flujo manual de importación (quitar el paso "Confirmar artista")? | Quedó sin resolver: se aclaró que el flujo YA permite importar una nota sola sin pasar por el lote, pero el usuario no confirmó si el paso de confirmación extra le sigue pareciendo innecesario | Baja — pendiente de una respuesta explícita antes de tocarlo |
| P11 | Edición real de letra/acordes (mover acordes, cambiar texto) | Hoy la pestaña "Letra y acordes" es **solo lectura** | Alta — es el corazón de lo que falta en Fase 3 |
| P12 | StyleSheet (fuente, tamaño, justificado, interlineado) + `marks` inline (negrita/cursiva) | No empezado. `LineSegment` hoy solo tiene `{chord, text}`, sin campo para marks | Alta — parte del objetivo original de Fase 3 (ver v1.0, sección 4) |

---

## 9. ENTORNO — VERIFICADO ✅ (sin cambios de hardware/software este chat)

MacBook Pro 14", Apple ID `paul.oncoy@gmail.com`. macOS 26.5.2, Xcode 26.6, Swift 6.3.3, GRDB 7.11.1.

**Filesystem MCP — dos conectores activos, no confundir:**
- `Filesystem` (mayúscula): `/Users/pauloncoy/Downloads`, `/Users/pauloncoy/Desktop/ordenar ya`, `/Users/pauloncoy/Library/CloudStorage/OneDrive-Personal` ← **este es el que da acceso al proyecto Xcode y a las notas**
- `filesystem` (minúscula): solo `/Users/pauloncoy/Desktop`, `/Users/pauloncoy/Downloads` — sin OneDrive

Proyecto Xcode real en: `/Users/pauloncoy/Library/CloudStorage/OneDrive-Personal/La Sed/2026/App/LaSed/LaSed/`
Notas exportadas en: `/Users/pauloncoy/Library/CloudStorage/OneDrive-Personal/La Sed/2026/App/LaSed/LaSed_Notas_Export/`
Docs de continuidad viven en la carpeta padre: `/Users/pauloncoy/Library/CloudStorage/OneDrive-Personal/La Sed/2026/App/LaSed/`

---

## 10. REGLA DE TRABAJO

Antes de escribir código: analiza, identifica riesgos, explica decisiones. Después implementa.
Antes de modificar código existente: lee el archivo real vía Filesystem, analiza dependencias, evita breaking changes.
Cada funcionalidad nueva es un módulo independiente.
No introducir dependencias externas si Swift/SwiftUI resuelve el problema.
Validar lógica compleja (parsers, heurísticas) contra datos reales antes de asumir que un fix es correcto.
Actualizar el header `Modificado:` (fecha + hora) de cada archivo tocado, sin que el usuario tenga que pedirlo.
**Nuevo:** si una zona de la app tuvo 2+ rondas de fix-rotos-fix en el mismo chat, proponer UN cambio a la vez y pedir confirmación antes de apilar el siguiente, en vez de encadenar varios cambios de layout sin probar.

**Nota sobre el siguiente chat:** el título sugerido (`6️⃣ F3: Song Editor — edición real de acordes + StyleSheet`) asume que se sigue avanzando en Fase 3 (P11/P12). Si prefieres cerrar primero los pendientes menores heredados (P1-P3, P5-P10), un nombre alternativo sería `6️⃣ F2b/F3: cierre de pendientes menores`. Decide al abrir el chat nuevo cuál de los dos.
