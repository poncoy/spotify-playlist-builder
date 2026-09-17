# Changelog

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
