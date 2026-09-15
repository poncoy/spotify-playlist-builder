# LA SED MUSIC APP — PROMPT DE CONTINUIDAD

**Versión:** 0.8
**Fecha:** 10/09/2026
**Chat de origen:** `6️⃣ F2b/F3: cierre de pendientes menores`
**Siguiente chat:** `7️⃣ F3: Song Editor — edición real de acordes + StyleSheet + Biblioteca de acordes`

> Pega este documento completo al inicio de un chat nuevo de Claude para retomar el proyecto exactamente donde quedó. Reemplaza al v0.7 — todo lo de acá incluye lo de ese doc más lo cerrado después.

---

## 1. CÓMO DEBES RESPONDERME

- Ingeniero de datos. Nunca he programado en Swift/Xcode. Instrucciones explícitas, un paso por línea, sin comprimir varias acciones en una oración.
- No empieces dándome la razón. Cuestiona mi suposición o señala lo que paso por alto, antes de cualquier otra cosa.
- Etiqueta confianza: **(seguro)** / **(probable)** / **(suposición)**.
- Sé breve. Nada de "buena pregunta", "tienes razón".
- Indica en qué parte de la fase vamos (checklist), no solo al cerrar el chat.
- Al final de cada respuesta, una línea con % de chat usado y tokens estimados.
- Código completo de un archivo: dilo explícito ("archivo completo, reemplázalo entero").
- Antes de escribir código que dependa de archivos existentes, **lee el archivo real** vía Filesystem — no lo adivines.
- Tienes acceso de lectura/escritura directo a mi Mac vía el conector Filesystem: `/Users/pauloncoy/Library/CloudStorage/OneDrive-Personal/` (proyecto Xcode en `La Sed/2026/App/LaSed/LaSed/`, notas en `LaSed_Notas_Export/`, docs de continuidad en `La Sed/2026/App/LaSed/`), además de `/Users/pauloncoy/Desktop/ordenar ya` y `/Users/pauloncoy/Downloads`. Hay DOS conectores: "Filesystem" (mayúscula, da el OneDrive) y "filesystem" (minúscula, solo Desktop/Downloads) — si uno falla con "Access denied", probar el otro.
- Sigues sin poder compilar ni ejecutar. Todo cambio tuyo requiere que yo corra ⌘B y te confirme.
- **Disciplina de cambios de layout:** cuando un fix de UI no probado se encadena con otro fix no probado, para y pide confirmación de que el anterior funcionó antes de apilar el siguiente.
- **Orden de argumentos de `.frame()`:** Swift exige el orden exacto `minWidth, idealWidth, maxWidth, minHeight, idealHeight, maxHeight`. Nombrar bien los parámetros no alcanza si el orden está mezclado.
- **Diagnóstico con datos reales sigue siendo la regla.** Cada bug de parser resuelto en este proyecto (Hotel California, Guitarras Blancas, Atado a un Setimiento) se resolvió leyendo el `.txt` real de la nota, nunca adivinando por una captura de pantalla.
- **Nuevo — fixes de parser no son retroactivos.** Un fix al `NotesImportParser` solo aplica a notas que se importen DESPUÉS del fix. Canciones ya guardadas conservan el `contentASTJson` viejo hasta que se borren y reimporten. Esto va a seguir generando reportes de "esto está mal" que en realidad son "esto es de antes del fix" — antes de tocar el parser de nuevo por un reporte así, preguntar si la canción se reimportó después del último fix relevante.

---

## 2. QUÉ ES EL PROYECTO

App multiplataforma (Swift/SwiftUI, GRDB/SQLite) para canciones, letras, acordes y setlists de la banda **La Sed**. Reemplaza Apple Notes.

```
CANCIONES → LETRAS/ACORDES → CSV → SETLISTS → BLOQUES → PERFORMANCE
```
Prioridad: **ESTABILIDAD > ARQUITECTURA > VELOCIDAD > FUNCIONALIDADES**

---

## 3. DECISIONES CERRADAS (no volver a discutir)

Heredadas de v0.1–v0.7: GRDB/SQLite, AST propio en JSON, Apple Notes antes que CSV, Android futuro posible, escala 1,000 canciones, soft delete, sync tracking desde v1, song_code `LS-XXXX`, `normalizeForMatching()` única función de normalización, notación de acordes decidida una vez por archivo completo, `contentASTJson` (migración v3), importador con lote+selección previa+deshacer+resumen visual+buscador, `EditSongView` con pestañas "Datos"/"Letra y acordes", `ChordChartView.swift` compartido (solo scroll horizontal, sin altura fija propia), Idioma como `Picker` de opciones fijas, `ModuleHeaderBar.swift` en las 4 pantallas principales.

**Nuevas de este chat:**

| Tema | Decisión | Motivo |
|---|---|---|
| **Selección múltiple + eliminar en lote (Biblioteca)** | `SongLibraryView` usa `Set<String>` para selección (⌘-clic/⇧-clic nativo de macOS). Botón "Eliminar (N)" en la toolbar abre `EliminarCancionesView`: lista con título+artista+código de cada una, confirmación explícita, soft delete de todas | Pedido explícito: "NO HAY OPCIÓN DE ELIMINAR MÁS DE UNA CANCIÓN" |
| **Orden alfabético de la biblioteca** | `SongLibraryView.loadSongs()` ordena el resultado con `localizedStandardCompare` antes de asignarlo a `songs` | `SongRepository.fetchAllActive()`/`.search()` no tienen `ORDER BY` — SQLite devolvía en orden arbitrario. Se corrigió del lado de la vista (Swift), no tocando el SQL de GRDB, para no arriesgar un error de sintaxis que no puedo compilar |
| **Fix de parser: alteraciones entre paréntesis cuentan como evidencia fuerte** | `tieneAlteracionOCalidad()` ahora acepta `resto.hasPrefix("(")` como evidencia válida | Caso real ("ATADO A UN SETIMIENTO"): la nota usa `D(#5)` como único marcador de alteración; sin este fix, `detectarNotacion()` no encontraba evidencia fuerte en NINGÚN acorde de la nota entera y la clasificaba como `.ninguna` ("Sin acordes"), aunque D, G, A, G/B, A/C# son acordes perfectamente válidos una vez decidida la notación |
| **"Biblioteca de acordes" queda anotada como decisión de arquitectura para el próximo chat, no se construye ahora** | Ver sección 8, pendiente P13 | Pedido explícito del usuario de anotarlo; requiere decidir qué guarda (¿solo nombre canónico? ¿digitación de guitarra? ¿enarmónicos C#/Db?), de dónde sale el catálogo, y cómo se conecta con el struct `Chord` — mismo nivel de decisión que StyleSheet, no un ajuste menor |
| **Etiqueta "Inglés"/"Solfeo" aclarada** | Ahora dice "Acordes: letras (C, D, E…)" / "Acordes: solfeo (Do, Re, Mi…)" en `ChordChartView.swift` y `NotesImportPreviewView.swift` | No era bug: describe la NOTACIÓN de los acordes, no el idioma de la letra — confundía porque una canción en español con acordes C/D/E mostraba "Inglés" |
| **Fix real y grave: espacios no separables (U+00A0)** | `NotesImportParser.parse()` normaliza `\u{00A0}` → espacio regular ANTES de cualquier otra cosa (título, detección de notación, líneas) | Caso real ("COME AS YOU ARE"): Apple Notes exporta espacios múltiples consecutivos como U+00A0, no como espacio normal. El parser separaba tokens por espacio normal (`" "`), así que estas líneas quedaban como UN token gigante sin separar — `linea.contains("  ")` (el chequeo de "línea anclable") nunca daba true. **Sospecha fuerte, sin confirmar: puede afectar más notas de las 217 de forma silenciosa** (sin aviso, cayendo a texto plano gris en vez de acorde azul, porque si otras líneas de la misma nota sí anclaban, la nota nunca se marcaba `requiereRevision`) |

---

## 4. ADVERTENCIA RECURRENTE: "esto no tiene acordes pero sí tiene"

Pasó dos veces en este chat (Guitarras Blancas, Atado a un Setimiento) y va a seguir pasando: una canción **ya importada** muestra "Sin acordes" o acordes mal anclados porque el parser tenía un bug **en el momento en que se importó**, no porque el bug siga vivo hoy. El fix nunca es retroactivo. Ante un reporte así:
1. Preguntar (o confirmar) si esa canción se importó ANTES o DESPUÉS del último fix relevante de `NotesImportParser.swift`.
2. Si fue antes: la solución es borrar esa canción (ya se puede en lote, ver sección 3) y reimportarla desde el `.txt` original — no es un bug nuevo que arreglar en el parser.
3. Solo si el `.txt` real de la nota muestra un patrón de acorde que el parser TODAVÍA no reconoce (como pasó con `D(#5)`), ahí sí es un fix de parser nuevo — y siempre se diagnostica leyendo el `.txt` real primero.

**Pendiente relacionado (P9, ver sección 8):** una función de "reprocesar sin borrar" evitaría este ciclo de borrar+reimportar cada vez que se ajusta el parser.

---

## 5. ARCHIVOS MODIFICADOS/CREADOS ESTE CHAT (además de los de v0.7)

```
LaSed/LaSed/
├── SongLibraryView.swift       ← Reescrito: selección múltiple (Set<String>), botón Eliminar (N),
│                                   EliminarCancionesView (resumen previo), orden alfabético en loadSongs().
├── NotesImportParser.swift     ← Fix: tieneAlteracionOCalidad() acepta paréntesis; normaliza U+00A0→espacio
│                                   al inicio de parse() (bug grave, ver sección 3).
├── ChordChartView.swift        ← Etiqueta de notación aclarada ("Acordes: letras/solfeo", no "Inglés"/"Solfeo").
└── NotesImportPreviewView.swift ← Misma aclaración de etiqueta en DetalleNotaParseadaView.
```

(Ver v0.7 para la lista completa de archivos de la sesión anterior: `ChordChartView.swift`, `ModuleHeaderBar.swift`, `EditSongView.swift`, `AddSongView.swift`, `NotesImportPreviewView.swift`, todos siguen vigentes sin cambios adicionales en esta sesión salvo lo listado arriba.)

---

## 6. ROADMAP

| Fase | Contenido | Estado |
|---|---|---|
| 0 | Relevamiento, arquitectura, entorno | ✅ |
| 1 | Esquema SQLite + repositorios + tests | ✅ |
| 2 | Song Library (CRUD, FTS5, matchKey, alias, UI, selección múltiple) | ✅ |
| 2b | Importador Apple Notes (.txt → AST → revisión → SongRepository) | ✅ funcional — quedan pendientes menores (sección 8), ninguno bloqueante |
| 3 | Song Editor (AST completo, StyleSheet, marks inline) | 🔵 **EN PROGRESO** — visualización de solo lectura lista; edición real, StyleSheet/marks y biblioteca de acordes **no empezados** |
| 4 | Setlists (bloques, reordenar, duplicar) | ⬜ |
| 5 | CSV → Matching Engine → Setlist automático | ⬜ |
| 6 | Performance Mode | ⬜ |
| 7 | Sincronización Supabase | ⬜ |

---

## 7. APRENDIZAJES OPERATIVOS NUEVOS (este chat)

1. **Sin `ORDER BY` explícito, SQLite no garantiza ningún orden** — ni de importación, ni alfabético. Cualquier lista mostrada al usuario necesita un orden explícito, puesto ahí a propósito (en SQL o en Swift), nunca asumido.
2. **Ordenar en Swift (`localizedStandardCompare`) es más seguro que agregar collation en GRDB/SQL cuando no hay forma de compilar para verificarlo** — maneja tildes/eñe correctamente, que la colación `NOCASE` nativa de SQLite no cubre (es solo ASCII).
3. **Un fix de parser resuelve el caso diagnosticado, no "todos los acordes posibles".** La meta "detectar todos los acordes posibles" no tiene punto final — el patrón sano es: reportar un caso real → leer el `.txt` → fix quirúrgico → repetir cuando aparezca el siguiente caso real.
4. **Los reportes de "esto está mal" sobre contenido ya importado necesitan primero la pregunta "¿se importó antes o después del último fix?"** antes de asumir que hay un bug nuevo — mitiga falsas alarmas de parser cuando en realidad es el AST viejo de una canción no reimportada.

---

## 8. PENDIENTES REALES

**Heredados de v0.6/v0.7 (sin tocar):** P1 (limpieza de prefijos de título), P2 (regla multi-artista), P3 ("115_" en detalle de nota), P5 (deshacer granular por canción en un lote), P6 (alert de "Deshacer lote" sigue simple), P7 (tamaños de ventana arbitrarios), P8 (pulido visual general, pospuesto a propósito), P10 (¿simplificar el paso "Confirmar artista" del flujo manual?), P11 (edición real de letra/acordes), P12 (StyleSheet + marks inline).

**Nuevo de este chat:**

| # | Item | Detalle | Prioridad |
|---|---|---|---|
| P13 | Biblioteca de acordes | Catálogo de nombres canónicos de acordes ("es fundamental saber qué acordes son y cómo se llaman"). Decisiones pendientes: ¿solo nombre, o también digitación de guitarra? ¿maneja enarmónicos (C#=Db)? ¿catálogo fijo o se arma solo con lo que aparece en las notas reales? ¿cómo se conecta con el struct `Chord` de `NotesImportParser.swift` — campo nuevo, o tabla aparte con FK? | Alta — pedido explícito, para decidir junto con StyleSheet/marks en el próximo chat |
| P9 (ya existía, sigue abierto) | Reprocesar/reimportar sin borrar | Cada fix de parser deja canciones viejas con AST desactualizado hasta que se borran y reimportan a mano. **Confirmado en este chat: reimportar NO actualiza en el mismo lugar, crea una canción nueva con código distinto** — borrar y reimportar pierde Spotify ID, YouTube, alias, país/idioma/nivel y notas manuales de esa canción. No hacerlo a la ligera en canciones ya enriquecidas a mano | **Alta** (subida de media-alta: no es solo comodidad, es riesgo real de perder datos) |
| P14 | Auditar notas ya importadas por el bug de U+00A0 | El fix de espacios no separables no es retroactivo. No hay forma de saber cuántas de las canciones ya importadas caían en texto plano gris por este bug SIN mostrar ningún aviso (si otra línea de la misma nota sí anclaba, la nota nunca se marcó `requiereRevision`). Posible acción: reimportar todo el lote de nuevo y comparar, o revisar visualmente notas con muchas líneas en gris que deberían tener acordes | Alta — puede haber más canciones "silenciosamente rotas" que las dos ya detectadas |

---

## 9. ENTORNO — VERIFICADO ✅ (sin cambios este chat)

MacBook Pro 14", Apple ID `paul.oncoy@gmail.com`. macOS 26.5.2, Xcode 26.6, Swift 6.3.3, GRDB 7.11.1. Ver v0.7 sección 9 para detalle completo de paths de Filesystem.

---

## 10. REGLA DE TRABAJO

Antes de escribir código: analiza, identifica riesgos, explica decisiones. Después implementa.
Antes de modificar código existente: lee el archivo real vía Filesystem, analiza dependencias, evita breaking changes.
Cada funcionalidad nueva es un módulo independiente.
No introducir dependencias externas si Swift/SwiftUI resuelve el problema.
Validar lógica compleja (parsers, heurísticas) contra datos reales antes de asumir que un fix es correcto.
Actualizar el header `Modificado:` (fecha + hora) de cada archivo tocado, sin que el usuario tenga que pedirlo.
Si una zona de la app tuvo 2+ rondas de fix-rotos-fix en el mismo chat, proponer UN cambio a la vez y pedir confirmación antes de apilar el siguiente.
**Nuevo:** ante un reporte de "esto está mal" sobre una canción ya importada, preguntar primero si se reimportó después del último fix de parser relevante — no asumir bug nuevo sin leer el `.txt` real primero.
