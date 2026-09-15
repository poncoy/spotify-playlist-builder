# LA SED MUSIC APP — PROMPT DE CONTINUIDAD

**Versión:** 0.9
**Fecha:** 10/09/2026
**Chat de origen:** `7️⃣ F3: cierre de pendientes de importador + formularios`
**Siguiente chat:** `8️⃣ F3: Song Editor — identidad estable del AST (implementación de la Opción B)`

> Pega este documento completo al inicio de un chat nuevo de Claude para retomar el proyecto exactamente donde quedó. Reemplaza al v0.8 — todo lo de acá incluye lo de ese doc más lo cerrado después.

---

## 1. CÓMO DEBES RESPONDERME

- Ingeniero de datos. Nunca he programado en Swift/Xcode. Instrucciones explícitas, un paso por línea, sin comprimir varias acciones en una oración.
- No empieces dándome la razón. Cuestiona mi suposición o señala lo que paso por alto, antes de cualquier otra cosa.
- Etiqueta confianza: **(seguro)** / **(probable)** / **(suposición)**.
- Sé breve. Nada de "buena pregunta", "tienes razón".
- Indica en qué parte de la fase vamos (checklist), no solo al cerrar el chat.
- **SIEMPRE, al final de CADA respuesta sin excepción, una línea con el % de chat usado y tokens estimados.** Esto se ha olvidado más de una vez — no es opcional, no esperar a que lo pida.
- Código completo de un archivo: dilo explícito ("archivo completo, reemplázalo entero").
- Antes de escribir código que dependa de archivos existentes, **lee el archivo real** vía Filesystem — no lo adivines.
- Acceso de lectura/escritura directo a mi Mac vía el conector Filesystem: `/Users/pauloncoy/Library/CloudStorage/OneDrive-Personal/` (proyecto Xcode en `La Sed/2026/App/LaSed/LaSed/`, notas en `La Sed/2026/App/LaSed/LaSed_Notas_Export/`, docs de continuidad en `La Sed/2026/App/LaSed/`), además de `/Users/pauloncoy/Desktop/ordenar ya` y `/Users/pauloncoy/Downloads`. Hay DOS conectores: "Filesystem" (mayúscula, da el OneDrive) y "filesystem" (minúscula, solo Desktop/Downloads) — si uno falla con "Access denied", probar el otro.
- Sigues sin poder compilar ni ejecutar. Todo cambio tuyo requiere que yo corra ⌘B (y ⌘U si tocaste el parser) y te confirme.
- **Disciplina de cambios de layout — REFORZADA este chat:** si un fix de UI no probado se encadena con otro sin confirmación, la sesión se descontrola. En este chat pasó 3 veces seguidas con el mismo problema de formularios antes de encontrar la causa real. Regla dura: máximo UN fix de layout no confirmado por turno; si el usuario reporta que sigue mal después de un fix, no adivinar una segunda vez con el mismo mecanismo — cambiar de estrategia por completo (ver sección 4).
- **Nuevo — antes de iniciar trabajo NUEVO (no un fix) con el chat por encima de ~85% de uso, ofrecer cerrar con doc de continuidad primero.** Implementar algo nuevo a medio contexto deja el trabajo a medias, que es peor que un corte limpio.

---

## 2. QUÉ ES EL PROYECTO

App multiplataforma (Swift/SwiftUI, GRDB/SQLite) para canciones, letras, acordes y setlists de la banda **La Sed**. Reemplaza Apple Notes.

```
CANCIONES → LETRAS/ACORDES → CSV → SETLISTS → BLOQUES → PERFORMANCE
```
Prioridad: **ESTABILIDAD > ARQUITECTURA > VELOCIDAD > FUNCIONALIDADES**

---

## 3. DECISIONES CERRADAS (no volver a discutir)

Heredadas de v0.1–v0.8: GRDB/SQLite, AST propio en JSON, Apple Notes antes que CSV, Android futuro posible, escala 1,000 canciones, soft delete, sync tracking desde v1, song_code `LS-XXXX`, `normalizeForMatching()` única función de normalización, notación de acordes decidida una vez por archivo completo, `contentASTJson` (migración v3), importador con lote+selección previa+deshacer+resumen visual+buscador, `EditSongView` con pestañas "Datos"/"Letra y acordes", `ChordChartView.swift` compartido (solo scroll horizontal, sin altura fija propia), `ModuleHeaderBar.swift` en las 4 pantallas principales.

**Nuevas de este chat:**

| Tema | Decisión | Motivo |
|---|---|---|
| **P9 resuelto: actualizar sin perder datos** | `DetalleNotaParseadaView` (dentro de `NotesImportPreviewView.swift`) ofrece un tercer botón "Actualizar contenido de existente" en el alert de duplicado, además de Cancelar/Crear de todos modos. Nuevo método `actualizarContenido(_:)`: reemplaza SOLO `contentASTJson` de la canción existente vía `repo.update()`, conserva song_code, Spotify, YouTube, país, idioma, nivel, notas y alias intactos | Reimportar para arreglar una canción con bug de parser viejo ya no destruye su enriquecimiento manual |
| **Bug real corregido: `fetchByMatchKey` no filtraba `deletedAt`** | `SongRepository.fetchByMatchKey()` ahora exige `deletedAt IS NULL`. Antes, una canción borrada (soft delete) seguía "existiendo" para el importador — síntoma real: borrar toda la biblioteca (119 canciones) y reimportar mostraba "Ya estaban en tu biblioteca (119)", 0 nuevas | Una canción borrada debe tratarse como si no existiera para efectos de duplicados |
| **Fix real de parser: acordes mayores sin calificador** | `NotesImportParser.detectarNotacion()` ahora tiene una segunda pasada, `detectarNotacionDebil()`, que activa SOLO si la primera (evidencia fuerte por calificador: #, b, m, 7, etc.) no encontró nada. Cuenta como evidencia una línea con 2+ tokens donde TODOS parsean como acorde en notación **inglesa únicamente** (nunca solfeo, mismo riesgo de falso positivo con palabras españolas ya documentado). Exige 2+ líneas así en toda la nota | Caso real confirmado con el `.txt` de "BORN TO BE WILD": chart válido de E/G/A/D, pero SIN una sola séptima/menor/sostenido en toda la canción — `evidenciaFuerte()` exigía calificador y la nota entera caía a "sin acordes". Afecta a cualquier canción de acordes mayores simples |
| **Picker de País** | Nuevo catálogo fijo `PaisConocido`/`paisesConocidos` en `Repository.swift` (15 países, alfabético). El valor guardado en `Song.country` sigue siendo el EMOJI de bandera (no el nombre) — mismo formato que ya escribe el importador en `banderaPaisDetectada`, así que las 116+ canciones ya importadas matchean sin migración. `EditSongView` tiene fallback (`opcionesPais`) que agrega el valor viejo como opción extra si no está en el catálogo, igual que ya hacía con Idioma | Pedido explícito, evita "Perú"/"PERU"/🇵🇪 como valores distintos |
| **Idioma alfabético en AddSongView** | La lista estaba en orden de escritura, no alfabético (`EditSongView` ya lo hacía bien) | Inconsistencia entre las dos pantallas |
| **FIX DEFINITIVO de descuadres de formulario: se elimina `Form` por completo en `AddSongView.swift` y en la pestaña "Datos" de `EditSongView.swift`** | Reemplazado por `ScrollView` + `VStack` + `GroupBox`, con cada campo como `Text(etiqueta)` arriba + `TextField(placeholder)` abajo (`.textFieldStyle(.roundedBorder)`), y Pickers como `HStack` manual (`Text` + `Spacer` + `Picker("", selection:).labelsHidden()`) | **2 intentos previos fallaron** (acortar etiquetas individuales; envolver el `TextField` en un `VStack` dentro del `Form`). Confirmado con capturas del usuario: `Form` en macOS sigue usando el texto de `TextField` como etiqueta externa en columna aparte AUNQUE esté envuelto en un `VStack` — el mecanismo busca un `TextField`-con-título en cualquier profundidad de la fila, no solo como hijo directo de `Section`. La única forma de evitarlo por completo es no usar `Form` en absoluto para estos formularios. Ver sección 4 |
| **Decisión de arquitectura para Song Editor: identidad estable del AST = OPCIÓN B, no la A** | **NO se toca** `ParsedSongContent`/`ParsedSection`/`ParsedLine`/`LineSegment`/`Chord` ni su `Codable`. Cuando exista el editor real: convertir a una copia temporal EN MEMORIA con structs espejo `Identifiable` (UUID generado al abrir, nunca persistido) — edita ahí — al guardar, convertir de vuelta al formato de siempre y escribir `contentASTJson` igual que hoy | Cero riesgo a las 116+ canciones ya importadas, a los 7 tests de `NotesImportParserTests.swift`, ni a `ChordChartView.swift` (que sigue leyendo el AST de solo lectura tal cual). La Opción A (agregar `id: UUID` directo a los structs actuales, sin persistirlo) también era segura pero toca archivos ya estables sin necesidad. Confirmado con el usuario que StyleSheet (marks inline por segmento, no una tabla externa por ID) y un futuro glosario de acordes (por nombre musical, no por instancia) no necesitan que el ID sobreviva entre sesiones — Opción B les alcanza. Única excepción futura que forzaría migrar a A: si algún día se necesita una anulación de estilo específica a una sola instancia de un acorde en una sola canción (no en el roadmap hoy) |

---

## 4. LECCIÓN CRÍTICA DE ESTE CHAT: `Form` de macOS y etiquetas largas

Si en el futuro aparece OTRO campo con texto cortado por la izquierda sin puntos suspensivos dentro de un `Form`, **no intentar acortar la etiqueta ni envolverla en un `VStack` — ninguna de las dos funciona.** `Form` en macOS extrae el título de cualquier `TextField` (u otro control con parámetro de título) que encuentre en la fila, sin importar cuántos contenedores intermedios haya, y lo usa como etiqueta en una columna que se recalcula dinámicamente según el contenido de TODA la sección — por eso acortar una etiqueta rompía otra distinta cada vez. La única solución confirmada: no usar `Form` para esa pantalla. Usar `ScrollView` + `VStack` + `GroupBox` en su lugar (ver patrón ya aplicado en `AddSongView.swift` y `EditSongView.swift`).

---

## 5. ARCHIVOS MODIFICADOS ESTE CHAT

```
LaSed/LaSed/
├── NotesImportPreviewView.swift  ← P9: botón "Actualizar contenido de existente" +
│                                     actualizarContenido() en DetalleNotaParseadaView.
├── SongRepository.swift          ← fetchByMatchKey() ahora filtra deletedAt IS NULL.
├── NotesImportParser.swift       ← detectarNotacionDebil() (segunda pasada, solo inglesa,
│                                     2+ líneas con 2+ tokens sin calificador).
├── Repository.swift              ← nuevo: struct PaisConocido + let paisesConocidos
│                                     (15 países, alfabético, id = emoji de bandera).
├── AddSongView.swift             ← Form eliminado (ScrollView+VStack+GroupBox), País/Idioma
│                                     como Picker, Idioma alfabético, Stepper corto.
└── EditSongView.swift            ← Form eliminado en datosForm (mismo patrón), Picker de
                                      País con fallback (opcionesPais), Stepper corto.
```

Todo compilado y confirmado por el usuario en vivo (⌘B + ⌘U), incluyendo reimportación real de 116 canciones de prueba.

---

## 6. ROADMAP

| Fase | Contenido | Estado |
|---|---|---|
| 0 | Relevamiento, arquitectura, entorno | ✅ |
| 1 | Esquema SQLite + repositorios + tests | ✅ |
| 2 | Song Library (CRUD, FTS5, matchKey, alias, UI, selección múltiple) | ✅ |
| 2b | Importador Apple Notes (.txt → AST → revisión → SongRepository) | ✅ funcional, con ruta segura de actualizar-sin-perder-datos (P9) |
| 3 | Song Editor (AST completo, StyleSheet, marks inline) | 🔵 **EN PROGRESO** — visualización de solo lectura lista, formularios de datos arreglados. **Identidad estable del AST decidida (Opción B) pero NO implementada — es el primer paso del próximo chat.** Edición real, StyleSheet/marks y biblioteca de acordes siguen sin empezar |
| 4 | Setlists (bloques, reordenar, duplicar) | ⬜ |
| 5 | CSV → Matching Engine → Setlist automático | ⬜ |
| 6 | Performance Mode | ⬜ |
| 7 | Sincronización Supabase | ⬜ |

---

## 7. APRENDIZAJES OPERATIVOS NUEVOS (este chat)

1. **Un reporte de "sigue mal" después de un fix de UI puede significar que el diagnóstico fue incorrecto, no que falta un segundo parche en la misma dirección.** Pasó 2 veces seguidas con el mismo Form antes de cambiar de estrategia (ver sección 4). Ante la segunda falla del mismo tipo de fix, cambiar de mecanismo, no insistir con una variante.
2. **Pedir capturas de pantalla ANTES de reportar "arreglado" es lo que permitió ver el patrón real** (etiqueta hoisted afuera del VStack) — sin la captura hubiera seguido adivinando a ciegas sobre el comportamiento interno de `Form`.
3. **Diagnóstico con datos reales sigue siendo la regla #1 del proyecto**, y se extiende a bugs de UI, no solo de parser: el fix de "Born to be Wild" solo fue posible leyendo el `.txt` real de la nota, no la captura de pantalla del resultado.
4. **Reordenar un catálogo a mano (`paisesConocidos`) es un lugar fácil para meter un typo silencioso** — al alfabetizar la lista se duplicó por error la bandera de Chile en la fila de Perú (dos entradas con el mismo `id`, que rompería el Picker). Se detectó releyendo el archivo completo después del edit, no asumiendo que el diff se veía bien. Cualquier edición manual de una lista de valores únicos (flags, códigos, IDs) debe releerse completa después, buscando duplicados, no solo revisando el diff de la línea tocada.

---

## 8. PENDIENTES REALES

**Heredados de v0.6/v0.7/v0.8 (sin tocar):** P1 (limpieza de prefijos de título), P2 (regla multi-artista), P3 ("115_" en detalle de nota), P5 (deshacer granular por canción en un lote), P6 (alert de "Deshacer lote" sigue simple), P7 (tamaños de ventana arbitrarios en el importador), P8 (pulido visual general, pospuesto a propósito), P10 (¿simplificar "Confirmar artista" del flujo manual?), P11 (edición real de letra/acordes — bloqueado por identidad del AST), P12 (StyleSheet + marks inline — bloqueado por identidad del AST), P13 (Biblioteca de acordes — bloqueado por identidad del AST, ver v0.8 sección 8 para las preguntas de diseño pendientes).

**P9 (v0.8) — CERRADO este chat.** Ruta de actualizar-sin-perder-datos implementada y probada.

**P14 (v0.8) — sigue abierto, pero ahora es seguro resolverlo:** auditar canciones ya importadas por el bug de espacios U+00A0 (fix de v0.7, no retroactivo). Antes esto era riesgoso porque reimportar perdía el enriquecimiento manual — con P9 resuelto, ya se puede reimportar/actualizar una canción sospechosa sin ese riesgo. Sigue pendiente decidir cómo encontrar cuáles canciones están afectadas (¿reimportar todo el lote de 217 y comparar? ¿revisar visualmente las que tienen muchas líneas en gris?).

**Nuevo — primer paso técnico del próximo chat:**

| # | Item | Detalle | Prioridad |
|---|---|---|---|
| P15 | Implementar identidad estable del AST (Opción B) | Diseñar structs espejo `Identifiable` (`EditableSongContent`, `EditableSection`, `EditableLine`, `EditableSegment`, `EditableChord` o nombres similares) + funciones de conversión ida (`ParsedSongContent` → editable, asigna UUIDs) y vuelta (editable → `ParsedSongContent`, descarta UUIDs) para guardar. Sin tocar `NotesImportParser.swift`, `ChordChartView.swift` (solo lectura) ni el `Codable` existente | **Alta — bloquea P11/P12/P13 completos** |

---

## 9. ENTORNO — VERIFICADO ✅ (sin cambios este chat)

MacBook Pro 14", Apple ID `paul.oncoy@gmail.com`. macOS 26.5.2, Xcode 26.6, Swift 6.3.3, GRDB 7.11.1. Ver sección 1 para paths de Filesystem.

---

## 10. REGLA DE TRABAJO

Antes de escribir código: analiza, identifica riesgos, explica decisiones. Después implementa.
Antes de modificar código existente: lee el archivo real vía Filesystem, analiza dependencias, evita breaking changes.
Cada funcionalidad nueva es un módulo independiente.
No introducir dependencias externas si Swift/SwiftUI resuelve el problema.
Validar lógica compleja (parsers, heurísticas) contra datos reales antes de asumir que un fix es correcto.
Actualizar el header `Modificado:` (fecha + hora) de cada archivo tocado, sin que el usuario tenga que pedirlo.
Si una zona de la app tuvo 2+ rondas de fix-roto-fix en el mismo chat, no insistir con una variante del mismo mecanismo — cambiar de estrategia por completo y decirlo explícitamente (ver sección 4).
Ante un reporte de "esto está mal" sobre una canción ya importada, preguntar primero si se reimportó/actualizó después del último fix de parser relevante — ya no hay excusa para no hacerlo: la ruta de actualizar sin perder datos (P9) existe.
Después de editar a mano cualquier lista de valores únicos (catálogos, IDs, flags), releer el archivo completo buscando duplicados antes de dar el cambio por bueno.
**SIEMPRE terminar cada respuesta con una línea de % de chat usado y tokens estimados — sin excepción, sin que el usuario tenga que recordarlo.**
