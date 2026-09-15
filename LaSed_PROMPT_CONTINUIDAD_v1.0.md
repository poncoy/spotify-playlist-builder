# LA SED MUSIC APP — PROMPT DE CONTINUIDAD

**Versión:** 1.0
**Fecha:** 09/09/2026
**Chat de origen:** `0 - Relevamiento`
**Siguiente chat:** `1 - Base de datos y modelos`

> **INSTRUCCIÓN:** Pega este documento completo al inicio de un chat nuevo de Claude para retomar el proyecto exactamente donde quedó.

---

## 1. CÓMO DEBES RESPONDERME

- Soy ingeniero de datos. Conozco GCP nivel básico-intermedio, entiendo código pero **nunca he programado en Swift ni usado Xcode**. Necesito instrucciones explícitas de dónde hacer clic, no atajos asumidos.
- **No empieces dándome la razón.** Tu primera frase debe cuestionar mi suposición o señalar lo que estoy pasando por alto.
- Etiqueta tu nivel de confianza: **(seguro)** con pruebas sólidas, **(probable)** si es inferencia fuerte, **(suposición)** si completas información faltante. Si la mayor parte de la respuesta es suposición, dilo desde el inicio.
- **Sé breve.** No entregues nada que no te haya pedido. Nada de "buena pregunta", "tienes razón", "de acuerdo contigo".
- Al final de cada respuesta, **una sola línea** con el % de chat usado y tokens.

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
| **Persistencia** | **GRDB / SQLite** | SwiftData es Apple-only, obliga a clases `@Model` en el dominio y no migra a Android. GRDB da FTS5 y control real. |
| **Formato de canción** | **AST propio en JSON** | JSON lo parsea cualquier lenguaje. ChordPro queda solo como códec de import/export. |
| **Orden de fases** | **Importador de Apple Notes ANTES que CSV** | El CSV no puebla la biblioteca; la consume. |
| **Android futuro** | Posible. UI se reescribe; **esquema SQLite, AST y reglas de matching sí sobreviven** | Por eso nada propietario de Apple en persistencia. |
| **Escala objetivo** | **1,000 canciones**, no 10,000 | Evitar sobre-ingeniería. FTS5 sí, paginación no. |

---

## 4. ERRORES DEL PROMPT ORIGINAL YA CORREGIDOS

1. **`content` + `formatting` opacos** → reemplazados por `contentAST` estructurado (secciones → líneas → segmentos con ancla de acorde).
2. **Negrita/cursiva vs. transposición** → se resuelve con **3 capas separadas**: contenido semántico (AST) + StyleSheet (fuente, tamaño, justificado, interlineado) + `marks` inline por segmento. El estilo **nunca** se guarda dentro del texto.
3. **CSV mal entendido** → NO es importador de biblioteca, es un **BUSCARV** contra la base existente que genera Setlist + bloques automáticamente. Renombrado a `SetlistBuilderFromCSV`.
4. **Tono en el lugar equivocado** → el tono es propiedad de la **ejecución**, no de la obra. Vive en `SetlistItem.keyOverride`, no en `Song`.
5. **Sincronización sin diseñar** → toda tabla lleva `updatedAt`, `deletedAt` (tombstone, jamás DELETE físico), `rev` y `lastEditedBy`. Más tabla `SyncOutbox`. Definido desde el esquema inicial.
6. **10,000 canciones** → bajado a 1,000.

---

## 5. IDENTIFICADORES

**Regla crítica:** un solo generador a la vez. Yo genero los IDs en Excel para lo existente; la app arranca su contador **después** de mi último número.

### `song_code` (obligatorio, clave real)
- Formato: `LS-0001`, `LS-0002`…
- Lo genero yo en Excel con `="LS-"&TEXTO(FILA()-1;"0000")` y **pego como valores**.
- Una vez escrito, **no se toca jamás**. No se reordena, no se reutiliza. Números huérfanos son correctos.
- Canciones propias de La Sed también lo llevan.

### `spotify_id` (opcional, enriquecedor)
- 22 caracteres. Distingue nativamente **vivo vs. estudio** (son tracks distintos).
- Obtención manual: Spotify escritorio → clic derecho → Compartir → Copiar enlace → los 22 chars entre `/track/` y `?`.
  - Fórmula Excel: `=EXTRAE(B2;ENCONTRAR("track/";B2)+6;22)`
- Obtención masiva: **https://exportify.app/** exporta playlists a CSV en UTF-8 con Track URI, duración (ms), popularidad e ISRC. Ya tengo playlists por bloque en Spotify creadas por mi script de Python.
- Alternativas sin OAuth: Spotlistr, Chosic.
- Temas propios de La Sed: queda vacío. **La app nunca lo exige.**

### Origen de los datos
| Automático (API Spotify) | Manual (mío) |
|---|---|
| spotify_id, duración, título oficial, artista, año, popularidad | Country, Level (complejidad), idioma, tono |

---

## 6. MI CSV REAL (el que ya uso con la banda)

Cabecera actual: `Bloque;Orden;Canción;banda/artista;País`
(el Excel completo tiene además: idioma, Country, Level, país, duración)

**Comportamiento esperado del importador:**
1. Agrupa por `Bloque` (A, B, C, SUP — nombres dinámicos, no fijos)
2. Ordena por `Orden`
3. Cruza contra la biblioteca por `song_code` → `spotify_id` → `matchKey` (título+artista normalizado)
4. Lo que no matchea va a **"Revisión requerida"**, nunca se importa en silencio
5. Genera Setlist + bloques automáticamente

**Detalle:** Excel para Mac guarda CSV en Mac Roman, no UTF-8. El importador debe **detectar encoding**, no asumirlo.

**Columnas a agregar a mi Excel:** `song_code`, `spotify_id`, `titulo_display`, `titulo_spotify` (no tocar, alimenta mi script de Spotify), `is_live`, `tono`.

---

## 7. ENTORNO — YA INSTALADO Y VERIFICADO ✅

MacBook Pro 14", Apple ID `paul.oncoy@gmail.com`. Dispositivos disponibles: iPhone 17 Pro Max, iPad Air.

```
macOS         26.5.2 (Tahoe, build 25F84)
Xcode         26.6 (17F113)
xcode-select  /Applications/Xcode.app/Contents/Developer  ✅
iOS runtime   26.5 (23F77)  ✅
Swift         6.3.3
Git           2.49.0
Homebrew      6.0.22
DB Browser for SQLite  3.13.1
```

**Apple ID en Xcode: NO registrado todavía.** Solo se necesita para correr en iPhone/iPad. Para Mac no hace falta.

---

## 8. PROYECTO XCODE — YA CREADO ✅

```
Template:      Multiplatform → App
Product Name:  LaSed
Org ID:        com.poncoy
Testing:       Swift Testing with XCTest UI Tests
Storage:       None
Git:           repositorio local creado
```

Estructura actual:
```
LaSed/
├── LaSed/
│   ├── Assets.xcassets
│   ├── ContentView.swift
│   ├── LaSedApp.swift
│   └── Models.swift          ← recién creado
├── LaSedTests/
└── LaSedUITests/
Package Dependencies:
└── GRDB 7.11.1               ✅ target: LaSed
```

**Estado:** `import GRDB` compila. **Build Succeeded** confirmado.

### Comandos de Xcode que ya conozco
| Acción | Atajo |
|---|---|
| Compilar | ⌘B |
| Compilar y ejecutar | ⌘R |
| Detener | ⌘. |
| Ver errores (Issue Navigator) | icono ⚠️ lateral |
| Ver historial de builds | ⌘9 |
| Consola | ⌘⇧C |

---
## 8.1 CONVENSIÓN
//
//  Models.swift
//  LaSed
//
//  Versión app:  0.1.0
//  Doc:          v0.2
//  Fase:         1 — Base de datos y modelos
//  Modificado:   09/09/2026

La versión del documento de continuidad y la versión de la app no son lo mismo: el documento se actualiza cada vez que cierras un chat (puede pasar 3 veces en un día sin que la app cambie), y la app avanza por fases.


## 9. PUNTO EXACTO DONDE ME QUEDÉ

Acabo de crear `Models.swift` con 4 structs GRDB: `Song`, `Setlist`, `SetBlock`, `SetlistItem`.

Campos clave ya definidos:
- `Song`: id (song_code), spotifyId?, titleDisplay, titleSpotify?, artist, matchKey, isLive, originalKey?, durationSec?, country?, language?, level?, notes?, createdAt, updatedAt, deletedAt?
- `SetBlock`: id, setlistId, name ("A"/"B"/"C"/"SUP"), position
- `SetlistItem`: id, blockId, songId, position (=Orden del CSV), keyOverride (=Tono), capoOverride?, notes?

**Pendiente inmediato:** verificar que `Models.swift` compila (⌘B), luego crear el **Archivo 2: el esquema SQL** (`AppDatabase.swift` con migraciones GRDB) y el **Archivo 3: los repositorios**.

---

## 10. LO QUE SIGUE — ROADMAP CORREGIDO

| Fase | Contenido | Estado |
|---|---|---|
| **0** | Relevamiento, decisiones de arquitectura, entorno, proyecto creado | ✅ **COMPLETADO** |
| **1** | Esquema SQLite + migraciones + repositorios + tests base | 🔵 **AQUÍ ESTOY** |
| **2** | Song Library (CRUD, búsqueda FTS5, matchKey, SongAlias) | ⬜ |
| **2b** | Importador Apple Notes → TXT → parser con pantalla de revisión | ⬜ |
| **3** | Song Editor (AST, secciones, acordes, StyleSheet) | ⬜ |
| **4** | Setlists (bloques, reordenar, duplicar) | ⬜ |
| **5** | CSV → Matching Engine → Setlist automático | ⬜ |
| **6** | Performance Mode (lectura, navegación, modo oscuro, pantalla activa) | ⬜ |
| **7** | Sincronización Supabase | ⬜ |

**Nota sobre PDF:** importar letras desde PDF queda **fuera del MVP**. Extraer acordes alineados desde PDF es OCR posicional, es otro proyecto. TXT sí.

---

## 11. PRUEBA DE ACEPTACIÓN INMEDIATA (mi objetivo de corto plazo)

Quiero validar el flujo con **solo 5 canciones**:
1. Cargar 5 canciones con `song_code` y `spotify_id` en la base
2. Importar un CSV que las agrupe en 2 o 3 bloques
3. Verificar que el matching **por código** funciona realmente
4. Ver el setlist generado con sus bloques y orden

Si eso funciona, escalo al repertorio completo.

---

## 12. REGLA DE TRABAJO

Antes de escribir código: analiza, identifica riesgos, explica decisiones. Después implementa.
Antes de modificar código existente: analiza dependencias, identifica impacto, evita breaking changes.
Cada funcionalidad nueva debe ser un módulo independiente.
No introducir dependencias externas si Swift/SwiftUI resuelve el problema.
