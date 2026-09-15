# LA SED MUSIC APP — PROMPT DE CONTINUIDAD

**Versión:** 0.6
**Fecha:** 10/09/2026
**Chat de origen:** `4 - F2b: Pulido y cierre`
**Siguiente chat:** `5 - Fase 3: Song Editor`

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
- Antes de escribir código que dependa de archivos existentes, pide el archivo tal cual está — no lo adivines.
- **Nuevo en este chat:** tienes acceso de lectura/escritura directo a mi Mac vía el conector Filesystem, en particular a `/Users/pauloncoy/Library/CloudStorage/OneDrive-Personal/La Sed/2026/App/LaSed/` (el proyecto Xcode completo) y a `LaSed_Notas_Export/` (las 217 notas .txt reales). Úsalo para leer archivos reales antes de escribir código, y para aplicar ediciones directas con `edit_file` en vez de pedirme que pegue código en Xcode — pero **sigues sin poder compilar ni ejecutar**. Todo cambio tuyo requiere que yo corra ⌘B y te confirme.
- **Actualiza la fecha/hora del header `Modificado:` de cada archivo que edites**, con hora real (no solo fecha) — se te pidió explícitamente en este chat.
- Cuando reporto un bug con captura de pantalla, antes de proponer un fix a ciegas, diagnostica con datos reales (lee el archivo/nota real involucrado) si el bug depende de contenido específico.

---

## 2. QUÉ ES EL PROYECTO

App multiplataforma (Swift/SwiftUI, GRDB/SQLite) para canciones, letras, acordes y setlists de la banda **La Sed**. Reemplaza Apple Notes.

```
CANCIONES → LETRAS/ACORDES → CSV → SETLISTS → BLOQUES → PERFORMANCE
```
Prioridad: **ESTABILIDAD > ARQUITECTURA > VELOCIDAD > FUNCIONALIDADES**

---

## 3. DECISIONES CERRADAS (no volver a discutir)

Heredadas de v0.1–v0.5: GRDB/SQLite, AST propio en JSON, Apple Notes antes que CSV, Android futuro posible, escala 1,000 canciones, soft delete, sync tracking desde v1, song_code `LS-XXXX`, `normalizeForMatching()` única función de normalización, UI tipo NavigationSplitView, notación de acordes decidida una vez por archivo completo, AppleScript de exportación bulk, `contentASTJson` (migración v3).

**Nuevas de este chat (cierre de Fase 2b):**

| Tema | Decisión | Motivo |
|---|---|---|
| **Importación en lote** | Nunca todo-o-nada silencioso. Botón "Importar lote" abre pantalla de selección previa (`SeleccionLoteView`), con checkbox por nota, agrupado por artista sugerido, con acción "Todas/Ninguna" global y por grupo | Pedido explícito: "no hay confirmación previa donde se puede seleccionar cuáles se importan" |
| **Confianza de sugerencia como filtro del lote** | El lote (auto o con selección) SOLO acepta notas con `sugerirArtista()` ≥60% (umbral ya existente en el servicio). Sin sugerencia confiable, la nota queda fuera, se resuelve nota por nota | Nunca inventar un artista a ciegas en lote |
| **Confirmación explícita de artista (pendiente #4 de v0.5)** | En el flujo manual (nota por nota), el campo de artista/banda empieza editable con la sugerencia prellenada; requiere clic en "Confirmar artista" para bloquearse a solo-lectura antes de habilitar "Importar". Botón "Editar" para reabrir | Cierra el pendiente #4 de v0.5: sugerencia ≠ dato confirmado, necesitaba una acción explícita para pasar de un estado a otro |
| **Deshacer lote** | Botón "Deshacer lote (N)" — SOLO deshace el último lote corrido (no acumulativo), vía soft-delete de cada canción creada en esa corrida. Requiere confirmación explícita, deja claro que es soft-delete (no recuperable desde la UI) | Pedido explícito; coherente con la regla de tombstone ya cerrada en sección 3 heredada |
| **Recordar última carpeta** | Bookmark de seguridad (`URL.bookmarkData(options: .withSecurityScope)`) guardado en `UserDefaults`, se autocarga en `.onAppear` si existe y sigue siendo válido | Reabrir el importador pedía elegir la carpeta cada vez |
| **Orden de la lista de notas** | Primero las que requieren revisión, luego las que no; alfabético dentro de cada grupo. Se calcula una vez al cargar la carpeta | Antes quedaba en orden de archivo (001_, 002_...), sin relación con el contenido |
| **Resumen ejecutivo del lote (vista previa)** | Antes de importar: gráficos de barra (Swift Charts) por artista (top 6) y por idioma aproximado, con conteo al final de cada barra. Ubicados DEBAJO de la lista de selección, no encima | El idioma se infiere de la bandera de país detectada — **es una aproximación, no un dato verificado**, mapeo manual (`idiomaPorBandera`) cubre las banderas reales del repertorio |
| **Resumen de motivos de revisión (pantalla principal)** | Botón ⓘ junto al contador inferior abre un popover con el desglose por tipo de aviso (sin acordes anclados, contenido perdido, nota casi vacía, notación ambigua), contando notas únicas por tipo | Pedido explícito: "no se muestra un resumen de las observaciones y cuál es el motivo principal" |
| **Resultado de importación como pantalla, no `.alert()`** | `ResumenLoteView`: pantalla con scroll, cada categoría (importadas/ya en biblioteca/sin sugerencia/con error) como grupo con ícono y color, agrupado por artista y ordenado alfabéticamente (artista y canción) | Un `.alert()` con 100+ nombres en un párrafo corrido es ilegible — reportado explícitamente como "mensaje cochinado" |
| **Mensajes de resultado más honestos** | "0 importadas" ahora dice "No se importó ninguna canción nueva"; "omitidas por posible duplicado" ahora dice "ya estaban en tu biblioteca (mismo título y artista), no se tocaron" | El texto anterior sonaba a fallo cuando en realidad era la protección de duplicados funcionando |
| **Cálculo de sugerencias en background** | El cálculo de sugerencia de artista para todas las candidatas del lote corre en `DispatchQueue.global`, con `ProgressView` mientras tanto, nunca bloqueante en el hilo principal | Corriendo en el hilo principal se sentía como un freeze al abrir la pantalla de selección |
| **Bug real de rendimiento resuelto** | `sugerirArtista()` (Levenshtein contra ~200 filas) se calculaba en un computed property referenciado dentro de un `List` — SwiftUI lo recalculaba en cada redibujo (cada toggle), causando ~25s de freeze por checkbox. Fix: calcular una sola vez en `.onAppear`, guardar en diccionario, los toggles solo leen | Lección: nunca poner una función costosa dentro de un `computed property` que SwiftUI puede re-evaluar en cada render |
| **Bug real de parser resuelto** | Líneas de un solo acorde con evidencia fuerte (ej. "Em", "F#7" solas antes de un verso — caso real en Hotel California) cae en `.letraPlana` (gris) porque el umbral pedía mínimo 2 tokens significativos. Fix: se acepta 1 solo token, pero SOLO para notación inglesa y SOLO con evidencia fuerte (alteración/calidad explícita) — nunca para solfeo, ahí "Do"/"Mi"/"La" sueltas son palabras españolas reales | Diagnosticado leyendo el `.txt` real de la nota, no adivinado |
| **Control explícito de columnas del NavigationSplitView** | `columnVisibility` con botón de sidebar en la toolbar + `.navigationSplitViewStyle(.balanced)` | El divisor de columnas se podía arrastrar hasta hacer desaparecer la lista, sin forma de recuperarla |

---

## 4. ARCHIVOS MODIFICADOS ESTE CHAT

```
LaSed/LaSed/
├── LaSedApp.swift              ← raíz vuelve a SongLibraryView()
├── SongLibraryView.swift       ← + botón "Importar notas" en toolbar, sheet con onDismiss que refresca la lista
├── NotesImportParser.swift     ← fix: tipoDeLineaAcorde() acepta 1 solo token con evidencia fuerte (solo notación inglesa)
└── NotesImportPreviewView.swift ← el más tocado hoy:
    - Botón "Cerrar", ventana redimensionable (antes fija/reducida)
    - Recordar última carpeta (bookmark de seguridad)
    - Importación en lote CON pantalla de selección previa (SeleccionLoteView, nuevo struct privado)
    - Deshacer último lote (soft delete)
    - Artista con confirmación explícita en flujo manual (pendiente #4 cerrado)
    - Resumen visual (Swift Charts) por artista e idioma aproximado
    - ResumenLoteView (nuevo struct privado) reemplaza el .alert() de resultado
    - Resumen de motivos de revisión (popover) en pantalla principal
    - Orden de lista: avisos primero, alfabético dentro de cada grupo
    - Control de columnas (sidebar toggle) + .navigationSplitViewStyle(.balanced)
```

**Nada de esto fue compilado por Claude** — todas las ediciones se aplicaron directo en disco vía Filesystem MCP, pero sin toolchain de Swift del lado de Claude. Falta el primer ⌘B/⌘U de toda la sesión acumulada.

---

## 5. PENDIENTES REALES (sin tocar, no bloqueantes)

| # | Item | Detalle | Prioridad |
|---|---|---|---|
| P1 | Limpieza de prefijos de título antes de sugerir artista | "12.BABY I LOVE YOUR WAY", "11.LOSING MY RELIGIÓN" — `limpiarTitulo()` solo quita el patrón `^[A-Z]-\d+\s*`, no prefijos tipo "12." | Media — pendiente #5 de v0.5, sigue abierto |
| P2 | Regla multi-artista (Excel manda) | `ArtistSuggestionService` ya solo lee del CSV, así que probablemente ya se cumple de facto — nunca se confirmó con un caso real de conflicto (ej. "Baby I Love Your Way": Big Mountain vs. Peter Frampton) | Baja |
| P3 | "115_" / "009_" antes del título en el detalle de nota | Se ve mal (cosmético), decisión explícita de dejarlo por ahora | Baja |
| P4 | Selección múltiple manual en la lista PRINCIPAL (fuera del lote) | Lo que el usuario confundió con un checkbox al inicio del chat — el ícono de estado no es interactivo. No se construyó, sigue siendo solo una idea a validar alcance | Media — a definir si hace falta con la selección de lote ya resuelta |
| P5 | Deshacer granular por canción dentro de un lote | Hoy solo se puede deshacer el lote completo, no una canción suelta de ese lote | Baja |
| P6 | Mensaje de "Deshacer lote" sigue siendo `.alert()` simple | Si alguna vez lista muchos errores, tendrá el mismo problema de legibilidad ya resuelto en el resumen de importación — aplicar el mismo patrón si hace falta | Baja |
| P7 | Tamaños de ventana (SeleccionLoteView, importador) son valores arbitrarios de Claude | No validados exhaustivamente contra pantallas reales distintas | Baja |
| P8 | Pulido visual general | Pospuesto explícitamente por el usuario desde v0.5 | Pospuesto a propósito |

---

## 6. ROADMAP

| Fase | Contenido | Estado |
|---|---|---|
| 0 | Relevamiento, arquitectura, entorno | ✅ |
| 1 | Esquema SQLite + repositorios + tests | ✅ |
| 2 | Song Library (CRUD, FTS5, matchKey, alias, UI) | ✅ |
| 2b | Importador Apple Notes (.txt → AST → revisión → SongRepository) | 🔵 **funcional, pulido mayor cerrado — quedan P1-P8 menores, sección 5** |
| 3 | Song Editor (AST completo, StyleSheet, marks inline) | ⬜ **AQUÍ EMPIEZA EL PRÓXIMO CHAT** |
| 4 | Setlists (bloques, reordenar, duplicar) | ⬜ |
| 5 | CSV → Matching Engine → Setlist automático | ⬜ |
| 6 | Performance Mode | ⬜ |
| 7 | Sincronización Supabase | ⬜ |

---

## 7. APRENDIZAJES OPERATIVOS NUEVOS (este chat)

1. **Nunca poner una función costosa (Levenshtein, cualquier O(n×m)) dentro de un `computed property` referenciado por un `List` o por interpolación de texto visible.** SwiftUI puede re-evaluar computed properties en cada redibujo — un solo toggle puede disparar la función decenas de veces. Calcular una vez (`.onAppear`, guardado en `@State` como diccionario) y leer de ahí.
2. **Cualquier cálculo que tome más de ~100ms debe correr en `DispatchQueue.global`, no en el hilo principal dentro de `.onAppear`**, y mostrar un `ProgressView` mientras tanto — si no, se siente como un freeze aunque técnicamente "funcione".
3. **`.alert()` de SwiftUI no sirve para listas de más de ~5-10 items.** Un párrafo con 100+ nombres separados por comas es ilegible por diseño de la API, no por falta de esfuerzo en el texto. Para cualquier resultado con una lista potencialmente larga, usar una pantalla real (`.sheet`) con `List`/`ScrollView`, no un `.alert()`.
4. **Contenido de altura variable (gráficos, listas dinámicas) dentro de un `VStack` sin límite puede empujar a un `List` hermano fuera del área visible**, sin error ni warning — simplemente el `List` se queda con 0 espacio visible. Siempre encerrar contenido de altura variable en un `.frame(height:)` fijo (con su propio `ScrollView` si hace falta) cuando comparte espacio con un elemento flexible como `List`; usar `.layoutPriority(1)` en el elemento que debe quedarse con el espacio sobrante.
5. **`ToolbarItem(placement: .principal)` dentro de un `.sheet()` simple en macOS no se renderiza de forma confiable.** Para controles críticos (como "Seleccionar todo") dentro de un sheet, usar una fila normal en el cuerpo de la vista, no el toolbar.
6. **Bookmarks de seguridad (`URL.bookmarkData(options: .withSecurityScope)`) son la forma correcta de "recordar" una carpeta elegida por `fileImporter` entre sesiones** — un `String` de ruta guardado en `UserDefaults` no sobrevive de forma confiable si la app está sandboxed.
7. **Diagnosticar con datos reales antes de proponer un fix, incluso bajo presión de tiempo.** El bug del "F#7 en gris" se resolvió leyendo el `.txt` real de la nota (`115_🇺🇸 HOTEL CALIFORNIA.txt`) y trazando la lógica del parser línea por línea contra ese contenido exacto — adivinar hubiera costado varias iteraciones más.
8. **Acceso directo de Claude al filesystem del Mac (vía conector Filesystem) elimina el paso de copiar/pegar archivos completos**, pero no reemplaza la necesidad de compilar: Claude edita, el usuario compila. Mantener el hábito de pedir ⌘B después de cada tanda de cambios antes de seguir apilando.

---

## 8. REGLA DE TRABAJO

Antes de escribir código: analiza, identifica riesgos, explica decisiones. Después implementa.
Antes de modificar código existente: pide o lee el archivo real, analiza dependencias, evita breaking changes.
Cada funcionalidad nueva es un módulo independiente.
No introducir dependencias externas si Swift/SwiftUI resuelve el problema.
Validar lógica compleja (parsers, heurísticas de clasificación, algoritmos de similitud) contra datos reales antes de asumir que un fix es correcto — no hay toolchain de Swift disponible para Claude, así que la validación contra datos reales es la única red de seguridad.
Actualizar el header `Modificado:` (fecha + hora) de cada archivo tocado, sin que el usuario tenga que pedirlo.
