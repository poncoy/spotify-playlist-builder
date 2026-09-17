# Changelog

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
