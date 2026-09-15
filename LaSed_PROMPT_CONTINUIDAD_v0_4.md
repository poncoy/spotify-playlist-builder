# LA SED MUSIC APP — PROMPT DE CONTINUIDAD

**Versión:** 0.4
**Fecha:** 09/09/2026
**Chat de origen:** `2 - Song Library (Fase 2)`
**Siguiente chat:** `2b - Importador de notas (Apple Notes → TXT)`

> **INSTRUCCIÓN:** Pega este documento completo al inicio de un chat nuevo de Claude para retomar el proyecto exactamente donde quedó.

---

## 1. CÓMO DEBES RESPONDERME

- Soy ingeniero de datos. Conozco GCP nivel básico-intermedio, entiendo código pero **nunca he programado en Swift ni usado Xcode**. Necesito instrucciones explícitas de dónde hacer clic, un paso por línea — no comprimir varias acciones en una sola oración.
- **No empieces dándome la razón.** Tu primera frase debe cuestionar mi suposición o señalar lo que estoy pasando por alto.
- Etiqueta tu nivel de confianza: **(seguro)** con pruebas sólidas, **(probable)** si es inferencia fuerte, **(suposición)** si completas información faltante. Si la mayor parte de la respuesta es suposición, dilo desde el inicio.
- **Sé breve.** No entregues nada que no te haya pedido. Nada de "buena pregunta", "tienes razón", "de acuerdo contigo".
- **Indica siempre en qué parte de la fase actual vamos** (checklist corto de lo hecho / pendiente), no solo al cerrar el chat.
- Al final de cada respuesta, **una sola línea** con el % de chat usado y tokens estimados.
- Cuando entregues código completo de un archivo, dilo explícitamente ("archivo completo, reemplázalo entero") — no des fragmentos sueltos sin decir en qué parte del archivo van, me cuesta ubicarlos.

---

## 2. QUÉ ES EL PROYECTO

App multiplataforma para gestionar canciones, letras, acordes y setlists de la banda **La Sed**. Reemplaza el uso actual de Apple Notes.

Plataformas: **iPhone, iPad, Mac** (Swift + SwiftUI, target único multiplataforma).

Flujo central que debe resolver:
```
CANCIONES → LETRAS/ACORDES → CSV → SETLISTS → BLOQUES → PERFORMANCE
```

Prioridad declarada: **ESTABILIDAD > ARQUITECTURA > VELOCIDAD > FUNCIONALIDADES**

---

## 3. DECISIONES YA CERRADAS (no volver a discutirlas)

| Tema | Decisión | Motivo |
|---|---|---|
| **Persistencia** | **GRDB / SQLite** | SwiftData es Apple-only, obliga a clases `@Model` y no migra a Android. GRDB da FTS5 y control real. |
| **Formato de canción** | **AST propio en JSON** | JSON lo parsea cualquier lenguaje. ChordPro queda solo como códec de import/export. |
| **Orden de fases** | **Importador de Apple Notes ANTES que CSV** | El CSV no puebla la biblioteca; la consume. |
| **Android futuro** | Posible. UI se reescribe; **esquema SQLite, AST y reglas de matching sí sobreviven** | Por eso nada propietario de Apple en persistencia. |
| **Escala objetivo** | **1,000 canciones**, no 10,000 | Evitar sobre-ingeniería. FTS5 sí, paginación no. |
| **Soft delete** | Nunca `DELETE` físico. Tombstone vía `deletedAt`. | Necesario para sync futura y para no perder historial. |
| **Sync tracking** | `rev`, `lastEditedBy`, `updatedAt` en toda tabla + tabla `syncOutbox` | Implementado desde la migración v1. |
| **Generador de song_code en la app** | Sugerido automático (MAX+1 sobre todos los `LS-XXXX`, incluyendo borrados) pero **editable** antes de guardar; validado con regex `^LS-\d{4}$` | Evita choque entre el generador de la app y el de tu Excel; nunca reutiliza un número huérfano |
| **Normalización de texto** | Una sola función `normalizeForMatching()` en `Repository.swift`, usada por `Song.matchKey` y `SongAlias.normalizedAlias` | Si usaran normalizaciones distintas, un alias podría no matchear su propia canción por una tilde o mayúscula |
| **UI de la biblioteca** | `NavigationSplitView`: lista a la izquierda, detalle a la derecha, ancho ajustable | Pedido explícito (estilo Notas de Mac); además resuelve solo el comportamiento en iPhone (colapsa a una columna) |
| **Alcance del importador de notas (Fase 2b)** | Procesa archivos `.txt` exportados manualmente desde Apple Notes, solo notas de texto (no fotos de notas a mano), con pantalla de revisión obligatoria | No existe API pública para leer la app Notas en vivo; ver sección 9 para el detalle completo |

---

## 4. ERRORES DEL PROMPT ORIGINAL YA CORREGIDOS

1. `content` + `formatting` opacos → `contentAST` estructurado (secciones → líneas → segmentos con ancla de acorde).
2. Negrita/cursiva vs. transposición → 3 capas separadas: AST + StyleSheet + `marks` inline. El estilo nunca vive en el texto.
3. CSV mal entendido → es un **BUSCARV** contra la biblioteca existente, no un importador. Renombrado `SetlistBuilderFromCSV`.
4. Tono en el lugar equivocado → vive en `SetlistItem.keyOverride`, no en `Song`.
5. Sincronización sin diseñar → `updatedAt`, `deletedAt`, `rev`, `lastEditedBy` + `SyncOutbox` desde el esquema inicial.
6. 10,000 canciones → bajado a 1,000.

---

## 5. IDENTIFICADORES

**Regla crítica:** un solo generador a la vez. Yo genero los IDs en Excel para lo existente; la app arranca su contador después de mi último número.

### `song_code` (obligatorio, clave real)
- Formato: `LS-0001`, `LS-0002`… Generado en Excel con `="LS-"&TEXTO(FILA()-1;"0000")`, pegado como valores. No se toca, no se reordena, no se reutiliza. Números huérfanos son correctos.
- **Implementado en Fase 2:** al agregar una canción desde la app, el campo sugiere el siguiente número libre (`suggestNextCode()`, MAX+1 incluyendo borrados) pero es editable — si la canción ya tiene código en tu Excel, lo pegas y pisas la sugerencia. Se valida formato (`^LS-\d{4}$`) y duplicados antes de guardar. Una vez creado, **no es editable** en la pantalla de edición (solo lectura).

### `spotify_id` (opcional, enriquecedor)
- 22 caracteres. Distingue vivo vs. estudio (tracks distintos).
- Manual: Spotify escritorio → clic derecho → Compartir → Copiar enlace → 22 chars entre `/track/` y `?`. Fórmula Excel: `=EXTRAE(B2;ENCONTRAR("track/";B2)+6;22)`
- Masiva: **exportify.app** (CSV UTF-8, Track URI, duración, popularidad, ISRC). Alternativas sin OAuth: Spotlistr, Chosic.
- Temas propios de La Sed: queda vacío, la app nunca lo exige.

### Dónde escuchar la canción (nuevo en Fase 2)
- Campos simples en `Song`: `youtubeUrl` (texto, opcional) y `physicalNotes` (texto libre, ej. "tengo el CD en casa").
- Decisión explícita: no es una tabla relacional ni participa en matching, es solo referencia para el usuario.

### Origen de los datos
| Automático (API Spotify) | Manual (mío) |
|---|---|
| spotify_id, duración, título oficial, artista, año, popularidad | Country, Level, idioma, tono |

---

## 6. MI CSV REAL

Cabecera: `Bloque;Orden;Canción;banda/artista;País` (Excel completo agrega: idioma, Country, Level, país, duración).

**Comportamiento del importador (aún no implementado — Fase 5):**
1. Agrupa por `Bloque` (A, B, C, SUP — dinámicos, no fijos)
2. Ordena por `Orden`
3. Cruza por `song_code` → `spotify_id` → `matchKey` (título+artista normalizado, vía `normalizeForMatching()`)
4. Sin match → "Revisión requerida", nunca se importa en silencio
5. Genera Setlist + bloques automáticamente

**Detalle:** Excel para Mac guarda CSV en Mac Roman, no UTF-8. El importador debe detectar encoding, no asumirlo.

**Columnas a agregar a mi Excel:** `song_code`, `spotify_id`, `titulo_display`, `titulo_spotify` (no tocar), `is_live`, `tono`.

---

## 7. ENTORNO — VERIFICADO ✅

MacBook Pro 14", Apple ID `paul.oncoy@gmail.com`. Dispositivos: iPhone 17 Pro Max, iPad Air.

```
macOS         26.5.2 (Tahoe, build 25F84)
Xcode         26.6 (17F113)
iOS runtime   26.5 (23F77)  ✅
Swift         6.3.3
Git           2.49.0
Homebrew      6.0.22
DB Browser for SQLite  3.13.1
GRDB          7.11.1  ✅ target: LaSed
```

Apple ID en Xcode: NO registrado (solo necesario para correr en iPhone/iPad, no en Mac).

### Comandos de Xcode ya conocidos
| Acción | Atajo |
|---|---|
| Compilar | ⌘B |
| Compilar y ejecutar | ⌘R |
| Correr tests | ⌘U |
| Detener | ⌘. |
| Clean Build Folder | ⇧⌘K |
| Issue Navigator (errores) | icono ⚠️ lateral |
| Consola / Debug Area | ⌘⇧Y |
| File Inspector (ver ruta de archivo) | ⌥⌘1 |

⚠️ **Hay DOS carpetas llamadas "LaSed" en el proyecto.** La correcta para todo el código de la app es la interna, la que tiene `Assets.xcassets` al lado — en la ruta completa del archivo (File Inspector, ⌥⌘1) debe aparecer `LaSed` **dos veces seguidas**. Los tests van en `LaSedTests`, no en `LaSed`.

⚠️ **`⌘B` compila la app; `⌘U` compila además el target de tests.** Un cambio en `Models.swift` puede romper `RepositoryTests.swift` sin que `⌘B` lo detecte — correr `⌘U` después de cualquier cambio a los structs.

---

## 8. PROYECTO XCODE

```
Template:      Multiplatform → App
Product Name:  LaSed
Org ID:        com.poncoy
Testing:       Swift Testing (no XCTest)
Git:           repositorio local
```

Estructura actual (carpeta interna `LaSed/LaSed/`):
```
LaSed/
├── LaSed/
│   ├── Assets.xcassets
│   ├── LaSedApp.swift             ← WindowGroup muestra SongLibraryView() (antes ContentView())
│   ├── ContentView.swift          ← ya no es la pantalla inicial, queda como scratch de Fase 1
│   ├── Models.swift               ← Song (+youtubeUrl, physicalNotes), Setlist, SetBlock, SetlistItem, SyncOutboxEntry, SongAlias
│   ├── AppDatabase.swift          ← migración v1 (esquema inicial) + v2 (alias, fuentes, FTS5 + triggers)
│   ├── Repository.swift           ← protocolo SyncedRecord + logOutbox() + normalizeForMatching()
│   ├── SongRepository.swift       ← CRUD + search (FTS5) + suggestNextCode() + fetchAllIncludingDeleted()
│   ├── SongAliasRepository.swift  ← create (bloquea conflicto entre canciones)/update/softDelete/restore/fetchBySong/findByNormalized
│   ├── SongLibraryView.swift      ← NavigationSplitView: lista + búsqueda (izquierda) + detalle (derecha)
│   ├── AddSongView.swift          ← formulario agregar canción (código sugerido+editable, valida formato y duplicados)
│   ├── EditSongView.swift         ← editar/borrar canción + gestión de alias; código de solo lectura
│   ├── SetlistRepository.swift    ← sin cambios desde Fase 1
│   ├── SetBlockRepository.swift   ← sin cambios desde Fase 1
│   ├── SetlistItemRepository.swift← sin cambios desde Fase 1
│   └── DeviceID.swift             ← sin cambios desde Fase 1
├── LaSedTests/
│   └── RepositoryTests.swift      ← 13 tests (4 de Fase 1 + 9 de Fase 2), todos en verde
└── LaSedUITests/
Package Dependencies:
└── GRDB 7.11.1
```

**Estado:** compila y corre en Mac (⌘R). Los 13 tests pasan en ⌘U. Base de datos real reiniciada limpia el 09/09/2026 (se borró `lased.sqlite` físico para eliminar datos de prueba, siguiendo la lección de la sección 13, punto 5) — no hay repertorio real cargado todavía.

---

## 8.1 CONVENCIÓN DE CABECERA POR ARCHIVO

```swift
//
//  NombreDelArchivo.swift
//  LaSed
//
//  Versión app:  0.2.0
//  Doc:          v0.4
//  Fase:         2 — Song Library
//  Modificado:   09/09/2026
//
```

La versión del documento de continuidad y la versión de la app **no son lo mismo**: el documento se actualiza cada vez que cierras un chat; la app avanza por fases (0.1.0 = Fase 1, 0.2.0 = Fase 2...).

---

## 9. PUNTO EXACTO DONDE QUEDASTE

**Fase 2 (Song Library) está completa y cerrada:**
- Backend: migración v2 (alias, `youtubeUrl`/`physicalNotes`, FTS5 + triggers), `matchKey` automático (ignora cualquier valor manual), `SongAlias` con bloqueo de conflictos entre canciones distintas y `restore()`. 13/13 tests en verde.
- UI: `SongLibraryView` (lista + búsqueda), `AddSongView` (agregar, valida formato y duplicados de código), `EditSongView` (editar, borrar con confirmación explícita de que no hay recuperación visual, gestión de alias). Todo probado a mano por el usuario en Mac.
- Navegación: panel dividido tipo Notas (`NavigationSplitView`), ancho ajustable confirmado, borrar una canción abierta limpia el panel derecho correctamente (`onDeleted` callback, sin `dismiss()`).

**Pendiente inmediato al abrir el próximo chat — Fase 2b (Importador de notas):**

El usuario preguntó qué tan literal es "importar Apple Notes" — quedó aclarado en este chat que **no es una importación masiva**. Antes de escribir código en el próximo chat:

1. **No es importar toda la app Notas.** El usuario tiene ~2,762 notas en iCloud, la mayoría sin relación con canciones. El importador solo debe procesar notas de letras/acordes — candidatas vistas en pantallazo: carpeta "La Sed" (21 notas) y/o "Canciones para s..." (217 notas). **Confirmar con el usuario cuáles carpetas son realmente repertorio antes de asumirlo.**
2. **El mecanismo de entrada es TXT, no una conexión directa a Notas.** No hay API pública de Apple Notes para terceros. El usuario exporta o copia el texto de cada nota relevante a un archivo `.txt` (Notas → Compartir → Guardar en Archivos, o copiar/pegar).
3. **Notas manuscritas (fotos) no se pueden procesar.** El usuario mostró un ejemplo real ("Ásele co mulos, que no soleé muy de") que es una foto de una hoja escrita a mano, no texto. Quedan fuera del importador automático — habría que volver a tipearlas primero. Preguntar cuántas notas reales son fotos vs texto antes de estimar el alcance del trabajo.
4. **Formato real de acordes+letra confirmado por el usuario** (ejemplo real, nota "Si no escribió"):
   ```
   C                    Am
   Si no escribió, qué puedo hacer
   El último llamado, lo hice yo
   ```
   Acorde en una línea, letra en la línea de abajo, alineado aproximadamente sobre la sílaba. El parser tiene que anclar cada acorde a una posición de carácter dentro de la línea de letra siguiente — no son líneas independientes entre sí.
5. Recordar que el importador necesita **pantalla de revisión manual** (decidido desde Fase 0) — nada se importa en silencio, igual que el CSV.

---

## 10. ROADMAP

| Fase | Contenido | Estado |
|---|---|---|
| **0** | Relevamiento, decisiones de arquitectura, entorno, proyecto creado | ✅ COMPLETADO |
| **1** | Esquema SQLite + migraciones + repositorios + tests base | ✅ COMPLETADO |
| **2** | Song Library (CRUD, búsqueda FTS5, matchKey, SongAlias, UI completa) | ✅ COMPLETADO |
| **2b** | Importador Apple Notes (.txt) → parser con pantalla de revisión | 🔵 **AQUÍ ESTOY** — alcance por confirmar, ver sección 9 |
| **3** | Song Editor (AST, secciones, acordes, StyleSheet) | ⬜ |
| **4** | Setlists (bloques, reordenar, duplicar) | ⬜ |
| **5** | CSV → Matching Engine → Setlist automático | ⬜ |
| **6** | Performance Mode (lectura, navegación, modo oscuro, pantalla activa) | ⬜ |
| **7** | Sincronización Supabase — reemplazar `DeviceID` por `userId` real, drenar `syncOutbox` | ⬜ |

**Nota sobre PDF:** importar letras desde PDF queda fuera del MVP. TXT sí.

---

## 11. PRUEBA DE ACEPTACIÓN (objetivo de corto plazo)

Validar el flujo con solo 5 canciones:
1. Cargar 5 canciones con `song_code` y `spotify_id` — **mecanismo ya existe y probado (`AddSongView`)**
2. Importar un CSV que las agrupe en 2-3 bloques — pendiente, Fase 5
3. Verificar matching por código — pendiente, Fase 5
4. Ver el setlist generado con bloques y orden — pendiente, Fase 4/5

Si funciona, escalar al repertorio completo.

---

## 12. REGLA DE TRABAJO

Antes de escribir código: analiza, identifica riesgos, explica decisiones. Después implementa.
Antes de modificar código existente: analiza dependencias, identifica impacto, evita breaking changes.
Cada funcionalidad nueva es un módulo independiente.
No introducir dependencias externas si Swift/SwiftUI resuelve el problema.
Cuando el usuario reporta un comportamiento raro, antes de asumir que es un bug, pedir una confirmación concreta y verificable (qué ve exactamente, cuántas veces, qué dato muestra) — puede ser un error de uso, no del código.

---

## 13. DECISIONES Y APRENDIZAJES DE FASE 1

1. **`rev`, `lastEditedBy`, `syncOutbox` se implementaron en la migración v1**, no diferidos a Fase 7. Cualquier cambio de esquema futuro con datos reales cargados debe ir en una migración nueva, nunca editando una migración ya aplicada en sitio.
2. **`lastEditedBy` usa un `DeviceID`** (UUID persistido en `UserDefaults`), no un usuario real — placeholder hasta Fase 7 (Supabase).
3. **El `ON DELETE CASCADE` del esquema SQL es letra muerta** porque nunca se hace `DELETE` físico. La cascada de soft-delete se implementa a mano en cada `softDelete()`.
4. **Toda mutación escribe una fila en `syncOutbox`** dentro de la misma transacción, vía `logOutbox()`.
5. **Cambiar el código de una migración GRDB ya aplicada no la vuelve a ejecutar** — el nombre de la migración es la clave. Durante desarrollo, sin datos reales, se puede borrar el `.sqlite` físico para forzar que corra de cero. Con datos reales, usar una migración nueva.
6. **Por la carpeta "LaSed" duplicada**, verificar siempre con Cmd+F + File Inspector (⌥⌘1) que se está editando el archivo correcto antes de asumir que un cambio se guardó.
7. **El botón "Probar base de datos" de Fase 1 hacía upsert real**, sirvió de humo-test manual antes de tener UI de verdad.

---

## 14. DECISIONES Y APRENDIZAJES DE FASE 2 (nuevos en este chat)

1. **`⌘B` no detecta errores en el target de tests.** Agregar campos a `Song` rompió los 4 tests viejos (constructores incompletos) sin que `⌘B` lo señalara — solo apareció al correr `⌘U`. Correr `⌘U` después de cualquier cambio a los structs de `Models.swift`, no solo `⌘B`.
2. **`.textInputAutocapitalization` no existe en macOS**, solo en iOS/iPadOS. En un target multiplataforma hay que envolverlo en `#if os(iOS) ... #endif`. El error del compilador no menciona la plataforma, hay que reconocerlo por experiencia ("Cannot infer contextual base...").
3. **`normalizeForMatching(_:)` en `Repository.swift` es la única función de normalización de texto del proyecto.** La usan `Song.matchKey` (automático, ignora cualquier valor manual pasado a `create`/`update`) y `SongAlias.normalizedAlias`. Cualquier comparación de texto nueva en el proyecto debe reusar esta función, nunca duplicar la lógica.
4. **`song_code` es inmutable también en la UI, no solo en la base de datos.** En `EditSongView` se muestra de solo lectura (`LabeledContent`), nunca en un `TextField` — intencional, por la regla de la sección 5.
5. **`suggestNextCode()` incluye canciones borradas en el cálculo de MAX+1**, a propósito — nunca reutiliza un número huérfano. Si el usuario ve un salto de números después de borrar canciones de prueba, es comportamiento esperado, no bug. La única forma limpia de "reiniciar" el contador es borrar el `.sqlite` físico completo, válido solo mientras no haya repertorio real cargado.
6. **El campo de código en `AddSongView` solo validaba duplicados, no formato** — se agregó regex `^LS-\d{4}$`. Cualquier campo de identificador editable a mano debe validar formato Y duplicados, no solo uno de los dos.
7. **`EditSongView` no usa `dismiss()`.** Desde que la navegación es `NavigationSplitView`, el panel de detalle nunca se cierra, solo cambia su contenido. Avisa al padre (`SongLibraryView`) por callbacks (`onChanged`, `onDeleted`); el padre decide qué mostrar. Cualquier vista nueva en el panel de detalle debe seguir este mismo patrón.
8. **Falsa alarma descartada en este chat:** el usuario reportó que una canción borrada "volvía a aparecer" — al indagar con preguntas concretas (cuántas veces aparece, qué código muestra), confirmó que fue una marca accidental suya, no un bug real. Vale la pena pedir detalles verificables antes de asumir un bug y ponerse a escribir código de corrección.
9. **Alcance real del importador de Apple Notes (Fase 2b) aclarado con el usuario** — no es una importación masiva de la app Notes, es un parser de archivos `.txt` exportados manualmente, limitado a notas de texto (no fotos de notas a mano), con pantalla de revisión obligatoria. Detalle completo en la sección 9.
