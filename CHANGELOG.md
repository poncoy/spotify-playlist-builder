# Changelog

## v3.9.0
- Campo opcional `Versión` en `canciones.txt` (6ta columna, después de País):
  si vale `Vivo`, fuerza que la búsqueda traiga la versión en vivo del tema
  en vez de la de estudio. Vacío (el caso normal) sigue detectando la
  versión automáticamente del propio título, como antes.
- Ampliadas las palabras clave de "vivo" con "gira"/"tour" — sin esto, temas
  como "... Me Verás Volver Gira 2007" (la gira de reunión de Soda Stereo)
  no se detectaban como en vivo ni con el override explícito, porque el
  título no dice literalmente "vivo"/"concierto".
- Revisado el setlist real (`setlists/canciones.txt`) y marcadas explícitamente
  las 7 canciones en vivo (Queen "Live at Wembley", los 2 temas de "El Último
  Concierto" y los 4 de "Me Verás Volver Gira 2007" de Soda Stereo);
  el resto queda en estudio (incluye las 3 "Remasterizado 2007", que son
  estudio, no vivo).
- Al arrancar, avisa cuándo se modificó el setlist por última vez (hoy a tal
  hora, o hace cuántos días) y si está vacío o tiene menos de 10 canciones.

## v3.8.0
- Bug: la búsqueda en Spotify a veces devolvía la versión "En Vivo"/acústica/
  remix de un tema en vez de la de estudio, sin que el setlist la pidiera
  (reportado con "Te vi en un tren"). `buscar_track` ahora puntúa todos los
  candidatos con `_score_track`, penalizando etiquetas de versión (vivo,
  remix, acústico, unplugged, demo, karaoke, remaster) que no estén también
  en el texto de `canciones.txt` — si vos pedís explícitamente "... - En
  Vivo" (como varios temas de Soda Stereo en el setlist real), se respeta
  igual. Si solo existe la versión no pedida en Spotify, se usa esa antes
  que no encontrar nada.
- De paso, unificó las dos búsquedas (exacta + laxa) en una sola función de
  scoring reusada por ambas, sacando más código duplicado.

## v3.7.1
- Generalizado el aviso de rotación (antes solo Spotify) a `verificar_rotacion()`,
  reutilizado también para la API key de GetSongBPM (`GETSONGBPM_KEY_ROTATED_AT`
  / `GETSONGBPM_KEY_ROTATION_DAYS`). GetSongBPM no documenta que sus keys
  expiren — esto es un recordatorio de buena práctica, no algo que exija el
  proveedor.

## v3.7.0
- Fallback de BPM/Tonalidad vía [GetSongBPM](https://getsongbpm.com) cuando el
  `audio-features` de Spotify da 403 (endpoint verificado en vivo contra la
  API real: `type=both&lookup=song:<título> artist:<artista>`). Solo cubre
  BPM y Tonalidad — Energía/Compás/Bailabilidad/Vivacidad no tienen
  reemplazo gratuito conocido y quedan vacías si Spotify no las da.
- `LaSedlist.command`: launcher de doble clic para macOS, reemplaza el
  flujo de "F5 en Jupyter".
- Repo pasado a público (verificado que nunca tuvo secretos en el
  historial) para poder cumplir el requisito de backlink de GetSongBPM.

## v3.6.0
- Scraper híbrido de reproducciones: primero busca la canción (por ID exacto)
  en la sección "Popular" del artista, cacheada por artista para no recargar
  esa página por cada canción; si no está ahí, cae al scraping por página
  individual de siempre. Nueva columna "Método" en el CSV/reporte indica cuál
  se usó para cada canción.
- Agregado "ID Spotify" al CSV.
- Refactor: eliminada la duplicación de lógica repetida en scraper.py,
  spotify_api.py, playlist.py y main.py (ver commits para el detalle). Se
  corrigió además un bug real: "Con reproducciones" en el reporte final
  contaba mal las canciones no encontradas en Spotify.

## v3.5.0
- BPM, Popularidad, Energía, Compás, Año de lanzamiento, Bailabilidad y Vivacidad
  agregados al CSV (mismo costo de API que la Tonalidad, que ya se pedía).
- Reporte final: hora de inicio, hora de fin y duración total del proceso.
- Reporte final: duración total del setlist, BPM promedio y popularidad promedio.

## v3.4.0
- Aviso de rotación del Client Secret de Spotify (15/7/3 días antes del vencimiento
  configurado en `SPOTIFY_SECRET_ROTATED_AT`).

## v3.3.0
- Reescritura del notebook original ("Arma Playlist en Spotify - v.3.4") como paquete
  Python (`spotify_playlist_builder/`), sin cambios de funcionalidad.
- Credenciales movidas a `.env` (antes en texto plano en `credenciales.txt`).
