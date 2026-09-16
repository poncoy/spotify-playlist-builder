# Spotify Playlist Builder

Herramienta personal para armar playlists de Spotify a partir de un setlist de texto (pensada
para DJs/eventos organizados por bloques). Para cada canción del setlist:

- Busca el track en Spotify (API oficial) y obtiene género y tonalidad.
- Lee el número de reproducciones tal como aparece en la web de Spotify (la API pública no
  expone ese dato, así que se scrapea con Selenium/Chrome headless).
- Exporta todo a un CSV.
- Crea la playlist en tu cuenta de Spotify — una única con todo el setlist, o una por bloque.

## Setup

1. Cloná el repo e instalá las dependencias:

   ```bash
   pip install -r requirements.txt
   ```

   Selenium 4.20+ descarga el driver de Chrome automáticamente (Selenium Manager), no hace
   falta instalar `chromedriver` a mano — sí necesitás tener Google Chrome instalado.

2. Creá una app en el [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
   y agregá `http://127.0.0.1:8888` (y opcionalmente 8889, 9090, 9091, 8765, 8766) como
   Redirect URIs.

3. Copiá `.env.example` a `.env` y completá `SPOTIFY_CLIENT_ID` / `SPOTIFY_CLIENT_SECRET`. Si
   además completás `SPOTIFY_SECRET_ROTATED_AT` (fecha en que generaste el secret), la app te
   avisa en cada corrida cuando falten 15, 7 o 3 días para cumplirse `SPOTIFY_SECRET_ROTATION_DAYS`
   (90 por defecto) desde esa fecha, para que lo rotes en el dashboard de Spotify.

4. Copiá `canciones.ejemplo.txt` a `canciones.txt` y reemplazalo con tu setlist real.

## Formato de `canciones.txt`

```
# Evento: Nombre del evento
Bloque;Orden;Canción;Artista
A;1;Come Together;The Beatles
A;2;Black Magic Woman;Santana
B;1;Born to Be Wild;Steppenwolf
B;AUX;Crazy Little Thing Called Love;Queen
```

- El separador se detecta automáticamente (`;`, `,`, `:`, `/`, `|` o tab).
- `Orden` puede ser numérico o `AUX` (las AUX van al final del bloque).
- Las canciones de un bloque llamado `Sin Bloque` se agregan en orden aleatorio; el resto
  respeta el `Orden` indicado.

## Uso

```bash
python -m spotify_playlist_builder
```

El script es interactivo: pide confirmación para autenticar tu cuenta (necesario para crear
playlists) y para elegir entre una playlist única o una por bloque. Al terminar, guarda un CSV
`spotify_direct_<version>_<timestamp>_<duración>.csv` con reproducciones, duración, género y
tonalidad de cada canción encontrada.

## Notas

- El scraping de la página de Spotify puede romperse si Spotify cambia su HTML — es la única
  forma de obtener el conteo exacto de reproducciones, ya que la API oficial no lo expone.
- Es un proyecto personal para uso propio/bajo demanda, no pensado para correr en paralelo
  contra muchas cuentas ni a gran escala.
