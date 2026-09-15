# LA SED MUSIC APP — PROMPT DE CONTINUIDAD

**Versión:** 1.2
**Fecha:** 11/09/2026
**Chat de origen:** `9️⃣ - Marks (cont.) — terminar de compilar y probar en dispositivo real`
**Siguiente chat:** por definir (backlog Fase 2 restante, o Fase 4: Setlists)

> Pega este documento completo al inicio de un chat nuevo para retomar donde quedó.

---

## 1. CÓMO RESPONDERME

Igual que v1.1: instrucciones explícitas paso a paso, cuestionar mi suposición antes de dar la razón, etiquetas (seguro)/(probable)/(suposición), breve, sin floro. **Nuevo en este chat: el usuario pidió explícitamente MENOS floro y respuestas más cortas — sostener eso.**

---

## 2. DECISIONES NUEVAS DE ESTE CHAT

| Tema | Decisión |
|---|---|
| **Negrita/cursiva — fuente de verdad** | Nunca `Font.Resolved.isBold/isItalic` (se contamina con "Texto en negrita" de Accesibilidad). Atributos propios `laSed.bold`/`laSed.italic` (`LaSedBoldKey`/`LaSedItalicKey`, `AttributeScopes.LaSedAttributes`) en `NotesImportParser.swift`. |
| **Tipo de letra** | `ChordFontFamily` (enum en `DisplaySettingsView.swift`): `sistema, menlo, monaco, courierNew, courier, andaleMono, ocrA`. **Siempre monoespaciada** — es requisito duro del anclaje de acordes por columna, nunca ofrecer una proporcional. Usuario confirmó que no tiene fuentes de terceros instaladas — lista cerrada en 7 opciones. |
| **Negrita "más fuerte"** | `.weight(.heavy)` en vez de `.bold()` para la fuente Sistema. Para fuentes con nombre fijo (Menlo, Courier...), negrita/cursiva son archivos de fuente DISTINTOS (`Menlo-Bold`, etc.) — no modifiers encadenables. |
| **Selector de color** | `Menu` nativo reemplazado por `.popover()` + `Circle().fill()` — un `Menu`/`Label` con `Image(systemName:)` renderiza sus íconos en modo plantilla (monocromo), ignora `.foregroundStyle()`. |
| **`Font.Context`/`fontResolutionContext`** | Eliminado por completo (`SongContentEditorView`, `EditSongView`, `NotesImportParser`) — quedó sin uso real tras el fix de arriba; era la causa de 2 errores de compilación de la sesión anterior. |
| **Estructura del proyecto Xcode** | **CORRECCIÓN a un aprendizaje viejo, ya no válido:** el proyecto usa `PBXFileSystemSynchronizedRootGroup` (carpetas sincronizadas, Xcode 16+), verificado en `project.pbxproj`. Cualquier archivo `.swift` escrito directo en `LaSed/LaSed/` (por Claude o a mano) queda incluido en el target automáticamente — **"Add Files to LaSed" nunca fue necesario, bórralo de tus notas.** |

---

## 3. ARCHIVOS TOCADOS ESTE CHAT

```
LaSed/LaSed/
├── NotesImportParser.swift    v0.4.11 — LaSedBoldKey/LaSedItalicKey + AttributeScope,
│                               segmentoAAttributed resuelve negrita+cursiva juntas
│                               (fuentes con nombre fijo), limpiarTitulo() quita
│                               prefijos numerados ("12.BABY..."), parseCuerpo/
│                               extraerMarcasGlobales sin Font.Context
├── SongContentEditorView.swift v0.4.10 — toggleNegrita/Cursiva usan laSed.bold/
│                               italic; Menu→popover; botón nuevo "textformat.size"
│                               abre Ajustes sin salir del editor; ícono "quitar
│                               formato" cambiado a eraser (xmark.circle no decía
│                               nada al tacto en iOS, .help() no se ve sin mouse)
├── ChordChartView.swift       v0.4.10 — usa fontFamily en vez de .monospaced fijo
├── EditSongView.swift         v0.4.10 — onSave/guardarContenidoEditado sin
│                               Font.Context; pasa fontFamily a astToAttributedString
├── DisplaySettingsView.swift  v0.4.10 — ChordFontFamily (nonisolated!, se me
│                               olvidó la primera vez → error de MainActor) +
│                               picker que se auto-demuestra en su propia fuente
├── ArtistSuggestionService.swift v0.3.1 — normalizar() reemplaza puntuación por
│                               espacio en vez de borrarla (defensa extra)
├── SongLibraryView.swift      v0.5.1 — botón "Auditoría Unicode" en el toolbar
└── AuditoriaUnicodeView.swift  NUEVO v0.5.1 — P14: escanea título/artista/
                                contenido de toda la biblioteca activa buscando
                                U+00A0, limpia con un clic
```

---

## 4. PUNTO EXACTO DONDE QUEDASTE

**Fase 3 (Song Editor: marks + alineación + librería de acordes + tipo de letra) — CERRADA.** Usuario confirmó en pantalla real: negrita, cursiva, color, resaltado, tipo de letra, quitar formato, canción vieja sin `marks` abre bien.

**Backlog viejo de Fase 2 — en progreso, este chat:**
1. ✅ Prefijo numérico en título → corregido (`limpiarTitulo`)
2. ✅ `normalizar()` reforzado (defensa en profundidad)
3. ✅ P14 Unicode → herramienta lista (`AuditoriaUnicodeView`), **pendiente que el usuario la corra sobre su biblioteca real**
4. ⬜ Reglas multi-artista — **datos reales ya entregados por el usuario, diseño pendiente:**
   - Caso real: "Quedate" — Christian Meier vs. "Quédate" — Zen. Con acentos
     distintos pero `normalizar()` los deja IDENTICOS (`diacriticInsensitive`
     folding quita la tilde) — ambos matchean 100% contra el mismo título
     normalizado, artista distinto. Hoy `sugerirArtista()` devuelve solo el
     de mejor score sin avisar que había otro empatado.
   - Caso futuro anticipado por el usuario: "Te quiero" (Hombres G) va a
     chocar con "Te quiero" (Amén) cuando la agregue al CSV.
   - **Regla a implementar el próximo chat:** si `sugerirArtista()` encuentra
     2+ artistas DISTINTOS con score por encima del umbral (o muy cerca del
     mejor score, ej. diferencia < 0.05), no debe auto-elegir uno — debe
     devolver la ambigüedad (nuevo campo o método, ej.
     `alternativas: [SugerenciaArtista]`) para que la UI pregunte cuál es,
     tanto en `DetalleNotaParseadaView` (manual) como en el lote
     (`importarLote`/`SeleccionLoteView` — un título ambiguo NO debería
     auto-aceptarse al lote, mismo criterio que "sin sugerencia").
5. ⬜ "115_" en nombre de archivo en detalle de nota — no tocado
6. ⬜ Undo-batch (`mensajeDeshacer`) sigue en `.alert()`, no en sheet con lista — no tocado
7. ⬜ StyleSheet completo — no tocado
8. ✅ Selección múltiple en lista principal — ya estaba resuelta desde antes (v0.5.0, `selectedSongIds: Set<String>`)

**Pendiente inmediato al abrir el próximo chat:**
1. ⌘B (debería salir limpio, ya confirmado en este chat).
2. Correr "Auditoría Unicode" sobre la biblioteca real y confirmar cuántas canciones tenían U+00A0.
3. Implementar la regla de multi-artista con los datos reales de la sección 4 arriba (Quedate/Quédate, Te quiero).
4. Decidir: ¿seguir con el resto del backlog (#5, #6, #7) o saltar a Fase 4 (Setlists)?

---

## 5. ROADMAP

| Fase | Contenido | Estado |
|---|---|---|
| 0-2b | Arquitectura, Song Library, Importador de notas | ✅ COMPLETADO |
| 3 | Song Editor completo (marks, alineación, acordes, tipo de letra) | ✅ **COMPLETADO ESTE CHAT** |
| 2 (backlog) | P14, títulos, multi-artista, undo-batch UI, "115_" | 🔵 **AQUÍ ESTOY** — parcial |
| 4 | Setlists | ⬜ |
| 5 | CSV → Matching Engine → Setlist automático | ⬜ |
| 6 | Performance Mode | ⬜ |
| 7 | Sincronización Supabase | ⬜ |

---

## 6. LO QUE NO CAMBIÓ (sigue igual que v1.1)

Arquitectura (GRDB/SQLite, AST JSON, soft delete, `song_code` LS-XXXX, `normalizeForMatching()`), identificadores, CSV real, entorno (macOS 26.5.2 / Xcode 26.6 / Swift 6.3.3 / GRDB 7.11.1), convención de cabecera por archivo, aprendizajes de Fase 1-2 (ver v0.3/v0.4 si hace falta el detalle completo).

---

## 7. APRENDIZAJES NUEVOS DE ESTE CHAT

1. **Nunca usar traits resueltos del sistema (`Font.Resolved.isBold/isItalic`) como estado propio de la app** — accesibilidad del usuario puede contaminarlos silenciosamente. Trackear con un atributo custom propio.
2. **Fuentes con nombre fijo (Menlo, Courier...) no responden a `.weight()`/`.italic()` como la fuente Sistema** — negrita/cursiva ahí son archivos con OTRO nombre PostScript, hay que resolverlos completos de una vez, no encadenar modifiers.
3. **`Menu`/`Label` con `Image(systemName:)` fuerza modo plantilla (monocromo)** en macOS/iOS, ignora `.foregroundStyle()`. Para mostrar colores reales, usar formas (`Circle()`) fuera de un `Menu`.
4. **`.help()` no muestra nada en iPhone/iPad** (es tooltip de mouse/hover) — en un toolbar táctil, el ícono tiene que ser autoexplicativo por sí solo.
5. **Verificar SIEMPRE `project.pbxproj` antes de asumir que hace falta "Add Files to LaSed"** — este proyecto usa `PBXFileSystemSynchronizedRootGroup`, así que nunca hizo falta. Aprendizaje viejo descartado.
6. **Un tipo/función nuevo puede quedar aislado a MainActor por default del proyecto sin querer** — si se usa desde un módulo `nonisolated` (como `NotesImportParser`), hay que marcarlo `nonisolated` explícitamente o el compilador tira error de actor-isolation.
