# LA SED MUSIC APP — PROMPT DE CONTINUIDAD

**Versión:** 0.3
**Fecha:** 09/09/2026
**Chat de origen:** `1 - Base de datos y modelos`
**Siguiente chat:** `2 - Song Library (Fase 2)` — *solo si el ⌘U de la sección 9 salió verde. Si no, este mismo prompt sirve para cerrar Fase 1 primero.*

> **INSTRUCCIÓN:** Pega este documento completo al inicio de un chat nuevo de Claude para retomar el proyecto exactamente donde quedó.

---

## 1. CÓMO DEBES RESPONDERME

- Soy ingeniero de datos. Conozco GCP nivel básico-intermedio, entiendo código pero **nunca he programado en Swift ni usado Xcode**. Necesito instrucciones explícitas de dónde hacer clic, un paso por línea — no comprimir varias acciones en una sola oración.
- **No empieces dándome la razón.** Tu primera frase debe cuestionar mi suposición o señalar lo que estoy pasando por alto.
- Etiqueta tu nivel de confianza: **(seguro)** con pruebas sólidas, **(probable)** si es inferencia fuerte, **(suposición)** si completas información faltante. Si la mayor parte de la respuesta es suposición, dilo desde el inicio.
- **Sé breve.** No entregues nada que no te haya pedido. Nada de "buena pregunta", "tienes razón", "de acuerdo contigo".
- Al final de cada respuesta, **una sola línea** con el % de chat usado y tokens estimados.

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
| **Sync tracking** | `rev`, `lastEditedBy`, `updatedAt` en toda tabla + tabla `syncOutbox` | Implementado en la migración v1 desde Fase 1 (ver sección 13). |

---

## 4. ERRORES DEL PROMPT ORIGINAL YA CORREGIDOS

1. `content` + `formatting` opacos → `contentAST` estructurado (secciones → líneas → segmentos con ancla de acorde).
2. Negrita/cursiva vs. transposición → 3 capas separadas: AST + StyleSheet + `marks` inline. El estilo nunca vive en el texto.
3. CSV mal entendido → es un **BUSCARV** contra la biblioteca existente, no un importador. Renombrado `SetlistBuilderFromCSV`.
4. Tono en el lugar equivocado → vive en `SetlistItem.keyOverride`, no en `Song`.
5. Sincronización sin diseñar → `updatedAt`, `deletedAt`, `rev`, `lastEditedBy` + `SyncOutbox` desde el esquema inicial (**ya implementado**, ver sección 13).
6. 10,000 canciones → bajado a 1,000.

---

## 5. IDENTIFICADORES

**Regla crítica:** un solo generador a la vez. Yo genero los IDs en Excel para lo existente; la app arranca su contador después de mi último número.

### `song_code` (obligatorio, clave real)
- Formato: `LS-0001`, `LS-0002`… Generado en Excel con `="LS-"&TEXTO(FILA()-1;"0000")`, pegado como valores. No se toca, no se reordena, no se reutiliza.

### `spotify_id` (opcional, enriquecedor)
- 22 caracteres. Distingue vivo vs. estudio (tracks distintos).
- Manual: Spotify escritorio → clic derecho → Compartir → Copiar enlace → 22 chars entre `/track/` y `?`. Fórmula Excel: `=EXTRAE(B2;ENCONTRAR("track/";B2)+6;22)`
- Masiva: **exportify.app** (CSV UTF-8, Track URI, duración, popularidad, ISRC). Alternativas sin OAuth: Spotlistr, Chosic.
- Temas propios de La Sed: queda vacío, la app nunca lo exige.

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
3. Cruza por `song_code` → `spotify_id` → `matchKey` (título+artista normalizado)
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

⚠️ **Hay DOS carpetas llamadas "LaSed" en el proyecto.** La correcta para todo el código de la app es la interna, la que tiene `Assets.xcassets` al lado — en la ruta completa del archivo (File Inspector, ⌥⌘1) debe aparecer `LaSed` **dos veces seguidas** (ej. `.../LaSed/LaSed/AppDatabase.swift`). Los tests van en la carpeta **`LaSedTests`**, no en `LaSed`.

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
│   ├── ContentView.swift          ← UI de prueba, ejercita SongRepository real
│   ├── LaSedApp.swift             ← sin tocar
│   ├── Models.swift               ← 4 structs GRDB + SyncOutboxEntry
│   ├── AppDatabase.swift          ← migraciones (esquema v1 completo, ver sección 13)
│   ├── Repository.swift           ← protocolo SyncedRecord + logOutbox()
│   ├── SongRepository.swift       ← create/update/softDelete/fetch×4
│   ├── SetlistRepository.swift    ← create/update/softDelete (cascada)/fetch×2
│   ├── SetBlockRepository.swift   ← create/update/softDelete (cascada)/fetch×2
│   ├── SetlistItemRepository.swift← create/update/softDelete/fetch×2
│   └── DeviceID.swift             ← UUID persistente en UserDefaults (placeholder de identidad)
├── LaSedTests/
│   └── RepositoryTests.swift      ← 4 tests (create/update, softDelete, cascada, outbox)
└── LaSedUITests/
Package Dependencies:
└── GRDB 7.11.1
```

**Estado:** compila (⌘B) sin errores. Runtime real (⌘R) probado y confirmado con `rev` subiendo en cada clic. Tests escritos, **pendiente confirmar ⌘U en verde** (ver sección 9).

---

## 8.1 CONVENCIÓN DE CABECERA POR ARCHIVO

```swift
//
//  NombreDelArchivo.swift
//  LaSed
//
//  Versión app:  0.1.0
//  Doc:          v0.3
//  Fase:         1 — Base de datos y modelos
//  Modificado:   09/09/2026
//
```

La versión del documento de continuidad y la versión de la app **no son lo mismo**: el documento se actualiza cada vez que cierras un chat (puede pasar varias veces en un día sin que la app cambie de versión); la app avanza por fases (0.1.0 = Fase 1, 0.2.0 = Fase 2...).

---

## 9. PUNTO EXACTO DONDE QUEDASTE

Los 4 repositorios están escritos y compilan. `RepositoryTests.swift` tiene 4 tests escritos usando `DatabaseQueue()` en memoria (aislados del `.sqlite` real). Se detectó y corrigió un `import Foundation` faltante en el archivo de tests (error "Cannot find 'Date' in scope").

**Pendiente inmediato al abrir el próximo chat:**
1. Confirmar que ⌘U corre los 4 tests en verde:
   - `songCreateUpdateFetch`
   - `songSoftDelete`
   - `setlistSoftDeleteCascades`
   - `outboxLogsEachMutation`
2. Si todos pasan → Fase 1 queda cerrada, avanzar a Fase 2 (Song Library: CRUD real en UI, búsqueda FTS5, `SongAlias`).
3. Si alguno falla → pegar el nombre del test y el mensaje exacto del Issue Navigator antes de intentar arreglarlo.

---

## 10. ROADMAP

| Fase | Contenido | Estado |
|---|---|---|
| **0** | Relevamiento, decisiones de arquitectura, entorno, proyecto creado | ✅ COMPLETADO |
| **1** | Esquema SQLite + migraciones + repositorios + tests base | 🔵 **AQUÍ ESTOY** — código completo, verificando ⌘U |
| **2** | Song Library (CRUD, búsqueda FTS5, matchKey, SongAlias) | ⬜ |
| **2b** | Importador Apple Notes → TXT → parser con pantalla de revisión | ⬜ |
| **3** | Song Editor (AST, secciones, acordes, StyleSheet) | ⬜ |
| **4** | Setlists (bloques, reordenar, duplicar) | ⬜ |
| **5** | CSV → Matching Engine → Setlist automático | ⬜ |
| **6** | Performance Mode (lectura, navegación, modo oscuro, pantalla activa) | ⬜ |
| **7** | Sincronización Supabase — reemplazar `DeviceID` por `userId` real, drenar `syncOutbox` | ⬜ |

**Nota sobre PDF:** importar letras desde PDF queda fuera del MVP. TXT sí.

---

## 11. PRUEBA DE ACEPTACIÓN (objetivo de corto plazo)

Validar el flujo con solo 5 canciones:
1. Cargar 5 canciones con `song_code` y `spotify_id`
2. Importar un CSV que las agrupe en 2-3 bloques
3. Verificar matching por código
4. Ver el setlist generado con bloques y orden

Si funciona, escalar al repertorio completo.

---

## 12. REGLA DE TRABAJO

Antes de escribir código: analiza, identifica riesgos, explica decisiones. Después implementa.
Antes de modificar código existente: analiza dependencias, identifica impacto, evita breaking changes.
Cada funcionalidad nueva es un módulo independiente.
No introducir dependencias externas si Swift/SwiftUI resuelve el problema.

---

## 13. DECISIONES Y APRENDIZAJES NUEVOS DE ESTE CHAT (no estaban en v0.1/v0.2)

1. **`rev`, `lastEditedBy`, `syncOutbox` se implementaron en la migración v1**, no diferidos a Fase 7, porque en el momento de la decisión no había datos reales (solo 1 canción de prueba) — el costo de agregarlos ahora era mínimo. Si hoy ya tienes repertorio real cargado, cualquier cambio de esquema futuro **debe** ir en una migración `v2` nueva, nunca editando `v1_esquema_inicial` en sitio.
2. **`lastEditedBy` usa un `DeviceID` (UUID persistido en `UserDefaults`)**, no un usuario real — no hay sistema de auth todavía. Es un placeholder correcto para Fase 1-6; en Fase 7 (Supabase) probablemente se reemplaza por `userId`.
3. **El `ON DELETE CASCADE` del esquema SQL es letra muerta.** Solo dispara con `DELETE` físico, y la decisión de arquitectura (sección 3) prohíbe el `DELETE` físico. La cascada de soft-delete (`Setlist` → `SetBlock` → `SetlistItem`) se implementó a mano dentro de `softDelete()` en cada repositorio.
4. **Toda mutación (`create`/`update`/`softDelete`) escribe una fila en `syncOutbox`** dentro de la misma transacción `db.dbWriter.write`, vía el helper `logOutbox()` en `Repository.swift`. Esto evita tener que instrumentar retroactivamente cada punto de escritura cuando llegue Fase 7.
5. **Lección operativa sobre el entorno de Xcode:** cambiar el código de una migración GRDB ya aplicada **no** la vuelve a ejecutar — el nombre de la migración (`"v1_esquema_inicial"`) es la clave que GRDB usa para saber si ya corrió. Durante desarrollo, si cambias el esquema de v1, hay que borrar el `.sqlite` físico (ruta se ve en consola con el print `📁 Base de datos en:`) para que la migración se aplique de cero. Esto es solo válido mientras no haya datos reales que proteger; con datos reales, usar migración `v2`.
6. **Lección operativa sobre archivos:** por la carpeta "LaSed" duplicada, hubo un ciclo completo donde el archivo editado no era el que compilaba el target. Verificación recomendada antes de asumir que un cambio se guardó: Cmd+F dentro del archivo buscando una cadena única del cambio (ej. `syncOutbox`), y revisar en File Inspector (⌥⌘1) que la ruta tenga `LaSed` repetido dos veces.
7. **El botón "Probar base de datos" de `ContentView.swift`** ya no hace un insert fijo (rompía con `UNIQUE constraint` al segundo clic). Ahora hace upsert real: `fetchById` → si existe, `update` (sube `rev`, cambia `notes` con timestamp); si no existe, `create`. Sirve como humo-test manual de `SongRepository` completo.
