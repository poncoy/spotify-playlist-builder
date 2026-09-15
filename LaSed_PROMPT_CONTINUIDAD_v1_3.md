# LA SED MUSIC APP — PROMPT DE CONTINUIDAD

**Versión:** 1.3
**Fecha:** 12/09/2026
**Chat de origen:** `🔟 - F3-cont: multi-artista + backlog Fase 2 + StyleSheet`
**Siguiente chat:** por definir (Fase 4: Setlists, o pulir StyleSheet si algo sale mal en prueba real)

> Pega este documento completo al inicio de un chat nuevo para retomar donde quedó.

---

## 1. CÓMO RESPONDERME

Igual que v1.2: paso a paso, cuestionar antes de dar la razón, etiquetas (seguro)/(probable)/(suposición), breve. **Nuevo: los documentos de continuidad deben ser MÁS CORTOS — no repetir código completo, solo qué cambió y por qué.**

---

## 2. PUNTO EXACTO DONDE QUEDASTE

**Backlog de Fase 2 (v1.2 sección 4) — CERRADO completo este chat:**
1. ✅ Multi-artista: `ArtistSuggestionService.artistaAlternativo` ya existía en código pero sin UI real. Ahora en `SeleccionLoteView` hay sección separada "Coinciden con 2 artistas distintos" y en `DetalleNotaParseadaView` son 2 botones reales (uno por candidato) en vez de un TextField con aviso de texto.
2. ✅ "115_" en nombre de archivo: se limpia solo para MOSTRAR (`nombreArchivoParaMostrar`/`nombreArchivo`), `archivoOriginal` como clave interna no se toca.
3. ✅ Undo-batch: pasó de `.alert()` de texto corrido a `.sheet(item:)` con lista real (`ResumenDeshacer`/`ResumenDeshacerView`), mismo patrón que `ResumenLoteView`.
4. ✅ **StyleSheet por canción (Fase 3, pendiente desde v1.0):** nuevo, ver sección 3.

**Pendiente inmediato al abrir el próximo chat:**
1. Confirmar ⌘B limpio (última corrección: `.foregroundStyle` con tipos mixtos `Color`/`HierarchicalShapeStyle` en `ResumenDeshacerView`, ya arreglado).
2. Probar en pantalla real: StyleSheet por canción (activar override, cambiar tamaño/espaciado, confirmar que solo afecta esa canción). Autocompletar de artista al escribir a mano. Botones de artista ambiguo.
3. Decidir: ¿saltar a Fase 4 (Setlists) o seguir puliendo algo de lo de arriba?

---

## 3.1 BPM + METRÓNOMO — NUEVO, AL CIERRE DE ESTE CHAT

- Spotify deprecó `audio-features` (tempo/BPM) el 27/nov/2024 para apps nuevas — confirmado por búsqueda, NO es problema de sincronización de tu Premium. No hay reemplazo oficial gratis; alternativas si algún día se automatiza: Apple Music API (paga, $99/año) o Essentia (open-source, corre sobre el audio local).
- **Por ahora: BPM manual.** Migración v5 agrega `Song.bpm: Int?`. Campo nuevo en pestaña "Datos" → "Datos adicionales".
- **Metrónomo real:** archivo nuevo `MetronomeView.swift` — clic del sistema (`AudioServicesPlaySystemSound`, AudioToolbox) al tempo exacto + pulso visual. Botón nuevo (ícono `metronome`) en "Letra y acordes", deshabilitado si la canción no tiene BPM.
- **Pendiente futuro explícito (pedido por el usuario, NO implementado):** usar `Song.bpm` para un scroll automático de la letra sincronizado al tempo. Solo existe el dato base por ahora.

## 3. STYLESHEET POR CANCIÓN — NUEVO ESTE CHAT

Decisión: **fuente + tamaño + 3 espacios** (acorde↔letra, entre líneas, entre estrofas). Mayúsculas/minúsculas se dejó FUERA a propósito — casi no varía por canción, se queda global.

- **Migración v4** (`AppDatabase.swift`): 5 columnas nuevas en `song`, todas nullable (`styleFontFamily/FontSize/LineSpacing/LineGap/SectionGap`). `nil` = hereda el ajuste global.
- **`Models.swift`**: campos + extensión `Song.effectiveFontFamily()/effectiveFontSize()/etc.` que resuelven canción→global.
- **Archivo nuevo `SongStyleSheetView.swift`**: toggle "Personalizar" + 5 controles. Escribe a la BD en cada cambio de slider (sin botón "Guardar" aparte) — si se siente lento al arrastrar, la solución es debounce, no lo contrario.
- **`ChordChartView`, `SongContentEditorView`, `EditSongView`**: ya no leen `@AppStorage` directo — resuelven `song?.effectiveX() ?? global`. El botón de tipografía en "Letra y acordes" ahora abre `SongStyleSheetView`, no los ajustes globales.
- `DisplaySettingsView` (ajustes GLOBALES de la app) sigue existiendo intacta — es el fallback y el editor de contenido (`SongContentEditorView`) sigue usándola para su propio botón de ajustes rápidos mientras escribes.

⚠️ Ningún archivo de este bloque se compiló por Claude (sin toolchain). Prioridad #1 del próximo chat: ⌘B.

---

## 4. OTROS APRENDIZAJES DE ESTE CHAT

1. **Un `.sheet` modal no tiene acceso visual al panel izquierdo del padre.** Texto tipo "selecciónala en la lista de notas (panel izquierdo)" dentro de un sheet confunde — mejor un botón real que cierre el sheet y navegue (`onAbrirNota` callback).
2. **Ternario dentro de `.foregroundStyle()` con `.secondary` y `.green` no compila** — `.secondary` es `HierarchicalShapeStyle`, `.green` es `Color`, tipos no unifican. Forzar ambos a `Color.x`.
3. **`OneDrive Files On-Demand` puede romper la resolución de paquetes SPM sin avisar con un error claro** — "Missing package product 'GRDB'" cascadeó a 21 errores falsos de "cannot find type". Diagnóstico: los archivos de `.xcodeproj` (no solo el código) pueden estar "en la nube" sin descargar. Se resuelve forzando la descarga + Reset Package Caches + Resolve Package Versions.
4. **Los `Song(...)` en 5+ archivos distintos** hacen que agregar campos nuevos al struct sea riesgoso si no llevan valor por defecto (`= nil`) — con default, el init memberwise sintetizado no rompe ningún call site existente. Patrón a repetir en cualquier campo nuevo futuro de `Song`.
5. **`create_file` (herramienta de Claude) escribe en el contenedor de Claude, NO en la Mac del usuario** — para archivos nuevos reales del proyecto, usar `Filesystem:write_file` (el conector de la computadora del usuario). Error cometido y corregido en este chat.

---

## 5. LO QUE NO CAMBIÓ

Arquitectura (GRDB/SQLite, AST JSON, soft delete, `song_code` LS-XXXX, `normalizeForMatching()`), identificadores, CSV real, entorno (macOS 26.5.2 / Xcode 26.6 / Swift 6.3.3 / GRDB 7.11.1), convención de cabecera por archivo. Detalle completo de Fase 1-2 en v0.3/v0.4 si hace falta.

## 6. ROADMAP

| Fase | Contenido | Estado |
|---|---|---|
| 0-2 | Arquitectura, Song Library, Importador de notas | ✅ |
| 2 (backlog) | P14, títulos, multi-artista, undo-batch, "115_" | ✅ **CERRADO ESTE CHAT** |
| 3 | Song Editor (marks, alineación, acordes, tipo de letra, **StyleSheet por canción**) | ✅ **CERRADO ESTE CHAT** (pendiente probar StyleSheet en real) |
| 4 | Setlists | ⬜ **SIGUIENTE** |
| 5 | CSV → Matching Engine → Setlist automático | ⬜ |
| 6 | Performance Mode | ⬜ |
| 7 | Sincronización Supabase | ⬜ |
