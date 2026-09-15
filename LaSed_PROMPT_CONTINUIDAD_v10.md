# LA SED MUSIC APP — PROMPT DE CONTINUIDAD

**Versión:** 1.0
**Fecha:** 10/09/2026
**Chat de origen:** `3 - Song Editor (P11 + Librería de acordes)`
**Siguiente chat:** `4 - Marks (negrita/cursiva/color) + alineación`

> **INSTRUCCIÓN:** Pega este documento completo al inicio de un chat nuevo de Claude para retomar el proyecto exactamente donde quedó.

---

## 1. CÓMO DEBES RESPONDERME

- Soy ingeniero de datos. Conozco GCP nivel básico-intermedio, entiendo código pero **nunca he programado en Swift ni usado Xcode**. Instrucciones explícitas, un paso por línea — no comprimir varias acciones en una sola oración.
- **No empieces dándome la razón.** Tu primera frase debe cuestionar mi suposición o señalar lo que estoy pasando por alto.
- Etiqueta tu nivel de confianza: **(seguro)**, **(probable)**, **(suposición)**.
- **Sé breve.** Nada de "buena pregunta", "tienes razón", "de acuerdo contigo".
- **Antes de escribir código que dependa de archivos existentes, lee el archivo real primero.** No adivinar structs ni firmas de función.
- Al final de cada respuesta, una línea con % de chat usado y tokens estimados.

---

## 2. QUÉ ES EL PROYECTO

App multiplataforma (iPhone, iPad, Mac — Swift + SwiftUI, target único) para gestionar canciones, letras, acordes y setlists de la banda **La Sed**. Reemplaza Apple Notes.

```
CANCIONES → LETRAS/ACORDES → CSV → SETLISTS → BLOQUES → PERFORMANCE
```

Prioridad: **ESTABILIDAD > ARQUITECTURA > VELOCIDAD > FUNCIONALIDADES**

---

## 3. DECISIONES YA CERRADAS

| Tema | Decisión |
|---|---|
| Persistencia | GRDB/SQLite (no SwiftData, migración a Android abierta) |
| Formato de canción | AST propio en JSON (`ParsedSongContent`); ChordPro solo import/export |
| Soft delete | Nunca `DELETE` físico |
| Sync tracking | `rev`, `lastEditedBy`, `syncOutbox` desde el esquema inicial |
| Normalización | Una sola función `normalizeForMatching()` |
| Escala objetivo | 1,000 canciones |
| **Editor de contenido (P11)** | **Texto plano (`TextEditor` único), reparseo completo al Guardar con el mismo algoritmo del importador.** Se abandonó un editor por segmentos con `Binding`s anidados — colgaba la app en canciones reales largas. |
| **Espacio entre estrofas** | **Dos controles independientes:** cantidad de Enters = tamaño del espacio; línea de `---` = raya visible. Nunca un conteo que se acumule silenciosamente entre ediciones. |
| **Librería de acordes (guitarra)** | Cobertura v1: mayor/menor/séptima dominante en las 12 raíces (abierta o cejilla CAGED). Todo lo demás: "no disponible", nunca una digitación inventada. |

---

## 4. ARQUITECTURA DEL AST (actualizada este chat)

```swift
struct ParsedSongContent { sections: [ParsedSection], notacionDetectada: NotacionAcorde }
struct ParsedSection {
    lines: [ParsedLine]
    separacionPrevia: Int      // Enters reales antes de esta sección (tamaño del espacio)
    separadorVisible: Bool     // true si el usuario escribió "---" (raya)
}
struct ParsedLine { type: TipoLinea, segments: [LineSegment] }
struct LineSegment { chord: Chord?, text: String }
struct Chord { root, accidental, quality, extensionNumero, bassRoot, raw, notacionOrigen }
```

**`ParsedSection` tiene `init(from:)`/`encode(to:)` manuales** — decodifica JSON viejo sin `separacionPrevia`/`separadorVisible` con valores por defecto (1 / false). Sin esto, cualquier canción guardada antes de este chat rompe al abrirla.

**Todos los tipos de este archivo están marcados `nonisolated`** (fix de este chat) — el proyecto tiene aislamiento a `MainActor` por defecto (Swift 6), y sin el modificador explícito estos modelos heredaban ese aislamiento, generando warnings de concurrencia al llamarlos desde `NotesImportParser` (que sí es `nonisolated`).

**`EditableSongContent.swift` (P15, chat anterior) quedó SIN CONSUMIDOR REAL** — se construyó para un editor por segmentos que se abandonó. Sigue en el proyecto por si sirve para una futura edición estructurada (arrastrar para reordenar). No se borró.

---

## 5. IDENTIFICADORES

`song_code`: `LS-XXXX`, generado en Excel, inmutable una vez creado. La app sugiere el siguiente número libre (editable) al agregar una canción; no editable después.

`spotify_id`: opcional, 22 caracteres, distingue vivo/estudio.

---

## 6. MI CSV REAL

`Bloque;Orden;Canción;banda/artista;País` — importador aún no implementado (Fase 5). Detección de encoding pendiente (Excel Mac guarda en Mac Roman).

---

## 7. ENTORNO

```
macOS 26.5.2 (Tahoe) · Xcode 26.6 · Swift 6.3.3 · GRDB 7.11.1
DB Browser for SQLite 3.13.1
```

⚠️ Dos carpetas "LaSed" en el proyecto — la correcta tiene `LaSed` repetido dos veces en la ruta (File Inspector, ⌥⌘1).
⚠️ `⌘U` compila el target de tests además de la app — correrlo tras cualquier cambio a `Models.swift` o `NotesImportParser.swift`, no solo `⌘B`.
⚠️ Proyecto con **aislamiento a MainActor por defecto** (Swift 6) — cualquier modelo/tipo puro que se use fuera de contexto de UI debe marcarse `nonisolated` explícitamente.

---

## 8. ARCHIVOS TOCADOS ESTE CHAT

```
LaSed/LaSed/
├── NotesImportParser.swift     ← parseCuerpo()/aTextoPlano() extraídos y reutilizados;
│                                  separacionPrevia + separadorVisible; nonisolated en todo
├── EditableSongContent.swift   ← sin cambios de lógica, header limpiado (SIN CONSUMIDOR REAL)
├── SongContentEditorView.swift ← REESCRITO: un solo TextEditor de texto plano
├── EditSongView.swift          ← pestaña "Letra y acordes": botones de acordes/ajustes/editar
├── ChordChartView.swift        ← lee DisplayPreferenceKeys; separador con tamaño+raya independientes
├── DisplaySettingsView.swift   ← NUEVO: tamaño de letra, 3 espacios, mayúsculas/minúsculas (global, no por canción)
├── GuitarChordShapes.swift     ← NUEVO: digitaciones guitarra (mayor/menor/7, abiertas + CAGED)
├── ChordDiagramView.swift      ← NUEVO: dibuja el diagrama de trastes
├── SongChordReferenceView.swift← NUEVO: hoja con todos los acordes distintos de la canción
└── ModuleHeaderBar.swift       ← sin cambios de lógica, header limpiado (venía de chat anterior)
```

**Pendiente de tu lado, en este orden:**
1. Agregar al proyecto Xcode los 3 archivos nuevos (`DisplaySettingsView`, `GuitarChordShapes`, `ChordDiagramView`, `SongChordReferenceView` — 4 en total).
2. Clean Build Folder (⇧⌘K), luego ⌘U (7 tests de `NotesImportParserTests` no deberían moverse — no se tocó la lógica de detección/anclaje, solo se extrajo a `parseCuerpo` y se agregó `nonisolated`).
3. Abrir varias canciones **guardadas antes de este chat** (no solo las de prueba) para confirmar que decodifican bien — el fix del punto 4 de la sección "Aprendizajes" fue urgente y afecta a toda la biblioteca real.
4. Probar: editar contenido, `---` para raya, varios Enters para espacio, botón de guitarra para diagramas.

---

## 9. PUNTO EXACTO DONDE QUEDASTE

**Fase 3 avanza así:**
- **P15 (identidad estable del AST):** cerrado técnicamente, pero su output (`EditableSongContent`) quedó sin usar tras el rediseño de P11. No es un problema, solo una nota para no buscar ese código en vano.
- **P11 (edición real de letra/acordes):** **cerrado y estabilizado** tras varias iteraciones dolorosas (ver Aprendizajes). Editor de texto plano, reparseo al guardar.
- **Librería de acordes (guitarra) v1:** **cerrada.** Botón "Acordes de esta canción" muestra diagramas de todos los acordes de la canción; cobertura mayor/menor/7 en las 12 raíces.
- **Ajustes de visualización:** tamaño de letra, 3 espacios (acorde↔letra, entre líneas, entre estrofas) y mayúsculas/minúsculas — preferencia global de la app.

**Pendiente inmediato al abrir el próximo chat — orden acordado:**
1. **Marks (negrita/cursiva/color de palabras)** — mismo mecanismo para las tres cosas. Requiere agregar un campo `marks` a `LineSegment` (no rompe la base de datos, vive en el JSON). Falta decidir la sintaxis que el usuario escribe en el editor de texto plano (candidato: `**negrita**` estilo Markdown) para no repetir el error de un editor estructurado con botones.
2. **Alineación de párrafo (izquierda/centro/derecha)** — se resuelve con el mismo campo `marks`, no es un trabajo aparte.
3. Backlog no tocado este chat: P14 (normalización Unicode U+00A0 en notas ya importadas), limpieza de prefijos de título, confirmación de reglas multi-artista, selección múltiple en la lista principal, undo granular por canción en un lote, StyleSheet completo per-canción (esto es distinto de los "Ajustes de visualización" globales que sí se construyeron este chat).

---

## 10. ROADMAP

| Fase | Contenido | Estado |
|---|---|---|
| 0-2b | Arquitectura, Song Library, Importador de notas | ✅ COMPLETADO |
| **3** | Song Editor: identidad AST (P15), edición real (P11), Librería de acordes v1 | ✅ **P11 y Librería cerrados** — sigue Marks/alineación |
| 4 | Setlists | ⬜ |
| 5 | CSV → Matching Engine → Setlist automático | ⬜ |
| 6 | Performance Mode | ⬜ |
| 7 | Sincronización Supabase | ⬜ |

---

## 11. REGLA DE TRABAJO

Antes de escribir código: analiza, identifica riesgos, explica decisiones. Antes de modificar código existente: lee el archivo real, identifica impacto. Cada funcionalidad nueva es un módulo independiente. No introducir dependencias externas si Swift/SwiftUI resuelve el problema.

**Nueva regla de este chat:** antes de introducir un mecanismo que dependa de "contar" algo invisible entre sesiones de edición (ej. cuántas líneas en blanco, cuántas veces se hizo algo), preferir un marcador EXPLÍCITO y visible en el propio contenido que edita el usuario. Un conteo oculto es indistinguible de un bug para quien lo usa, y es más frágil de lo que parece al diseñarlo.

---

## 12. APRENDIZAJES DE ESTE CHAT (importante, no repetir estos errores)

1. **Un editor por segmentos con `Binding`s anidados 4 niveles + `withAnimation` sobre arrays grandes cuelga SwiftUI en canciones reales.** La solución correcta para editar texto con reconocimiento automático de patrones (acordes) es un editor de TEXTO PLANO que reparsea todo al guardar — no un formulario estructurado con botones por línea. Esto además resuelve gratis la selección/copiado de texto, que un editor por campos nunca da.
2. **Un campo `Codable` no-opcional con valor por defecto en Swift NO tolera JSON viejo sin esa clave.** El valor por defecto solo aplica al construir en código; para decodificar JSON antiguo hace falta `init(from:)` manual con `decodeIfPresent(...) ?? valorPorDefecto`. Esto rompió la biblioteca real completa una vez — cualquier campo nuevo en un struct que ya tiene datos guardados en producción necesita este patrón, no un simple `= valor` en la declaración.
3. **Contar líneas en blanco como mecanismo de control visual es frágil**, aunque matemáticamente el round-trip esté bien calculado — el usuario no puede verificar cuántas "cuenta" el sistema sin abrir el AST. Preferible: un marcador explícito visible en el texto (`---`) para lo que necesita ser una decisión deliberada (una raya), y dejar que la cantidad de Enters controle directamente algo proporcional y visible de inmediato (el tamaño del espacio) — nunca mezclar ambos en un solo número.
4. **Proyecto con aislamiento a MainActor por defecto (Swift 6):** cualquier modelo de datos puro usado fuera de vistas SwiftUI (parsers, structs Codable compartidos) debe marcarse `nonisolated` explícitamente, igual que ya se hacía con el enum contenedor. Si aparece un warning de "actor-isolated initializer... in a synchronous nonisolated context", la causa casi segura es esta, no un error de lógica.
5. **`GeometryReader` + `ZStack` + `.position()` para diagramas de acordes es la primera pasada visual, no algo garantizado a verse bien sin ajuste** — funcionó en la práctica (confirmado con capturas reales), pero cualquier diagrama nuevo de este tipo debe asumirse "por confirmar" hasta verlo corriendo.
6. **En un instrumento musical real, "no disponible" es siempre mejor que una digitación inventada.** La Librería de acordes cubre solo lo que se puede derivar de teoría real (CAGED) o de posiciones abiertas universalmente enseñadas — todo lo demás queda fuera a propósito.
