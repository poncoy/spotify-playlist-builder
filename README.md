# Spotify Playlist Builder

Herramienta personal para armar playlists de Spotify a partir de un setlist de texto (pensada
para DJs/eventos organizados por bloques). Para cada canción del setlist:

- Busca el track en Spotify (API oficial) y obtiene género, tonalidad e ID — cacheado en
  `.cache_canciones.json`, así que un tema que ya tocaste en otro evento no se vuelve a buscar.
- Lee el número de reproducciones tal como aparece en la web de Spotify (la API pública no
  expone ese dato): primero revisa la sección "Popular" del artista (rápido, cubre varias
  canciones del mismo artista con una sola carga de página) y, si el tema no está ahí, cae al
  scraping de su página individual con Selenium/Chrome headless. Esto (y la Popularidad) se pide
  siempre fresco, incluso para canciones ya cacheadas, porque son los únicos datos que cambian
  con el tiempo.
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
   (90 por defecto) desde esa fecha, para que lo rotes en el dashboard de Spotify. Lo mismo aplica
   para `GETSONGBPM_KEY_ROTATED_AT` (ver más abajo) — ninguno de los dos proveedores fuerza una
   expiración, es solo un recordatorio de buena práctica con el plazo que vos elijas.

4. Copiá `setlists/canciones.ejemplo.txt` a `setlists/canciones.txt` y reemplazalo con tu
   setlist real (o apuntá `CANCIONES_FILE` en `.env` a otra ruta).

## Estructura del proyecto

```
Execute.command              # doble clic para correr todo (macOS)
spotify_playlist_builder/      # el paquete
setlists/
  canciones.ejemplo.txt        # plantilla de formato (versionada)
  canciones.txt                # tu setlist real (gitignored, la editás vos)
resultados/
  spotify_direct_*.csv         # se genera solo en cada corrida (gitignored)
```

## Formato de `canciones.txt`

```
# Evento: Nombre del evento
Bloque;Orden;Canción;Artista;País;Versión;Spotify
A;1;Come Together;The Beatles;United Kingdom;;
A;2;Black Magic Woman;Santana;Mexico;;
B;1;Born to Be Wild;Steppenwolf;United States;;
B;AUX;Crazy Little Thing Called Love;Queen;United Kingdom;Vivo;
A;3;El tiempo;Afrodisiaco;Peru;;https://open.spotify.com/track/6A7EtkhzaIAI0I5qCoVdMS
```

- El separador se detecta automáticamente (`;`, `,`, `:`, `/`, `|` o tab).
- `Orden` puede ser numérico o `AUX` (las AUX van al final del bloque).
- Las canciones de un bloque llamado `Sin Bloque` se agregan en orden aleatorio; el resto
  respeta el `Orden` indicado.
- `País`, `Versión` y `Spotify` son opcionales (podés tener solo 4 columnas, como antes). `País`
  no se usa para nada, es solo referencia.
- `Versión` solo importa cuando vale `Vivo`: fuerza que la búsqueda en Spotify traiga la versión
  en vivo del tema en vez de la de estudio. Dejalo vacío para la mayoría de las canciones — sin
  el campo, igual se detecta automáticamente cuando el propio título ya lo dice (p. ej.
  "... - En Vivo", "... Gira 2007", "... El Último Concierto").
- `Spotify` fija el track exacto pegando su URL (o URI, o solo el ID) — saltea la búsqueda por
  completo. Usalo cuando Spotify tiene varias copias idénticas del mismo tema con distinto ID
  (pasa seguido con catálogos viejos/regionales) y necesitás una en particular, o cuando la
  búsqueda automática se equivoca de forma persistente. Un pin siempre gana, incluso si había
  quedado guardado un match incorrecto en `.cache_canciones.json` de una corrida anterior.

## Uso

```bash
python -m spotify_playlist_builder
```

En macOS también podés hacer doble clic en `Execute.command` (abre la Terminal, se ubica en
la carpeta del proyecto y corre el comando de arriba solo).

Al arrancar, avisa cuándo se modificó `canciones.txt` por última vez (hoy a las HH:MM, o hace
cuántos días) y si está vacío o tiene menos de 10 canciones — para pescar a tiempo un setlist
viejo o incompleto antes de procesarlo entero.

El script es interactivo: pide confirmación para autenticar tu cuenta (necesario para crear
playlists) y para elegir entre una playlist única o una por bloque. Al terminar, guarda
`resultados/spotify_direct_<version>_<timestamp>_<duración>.csv` con, por canción:

- ID de Spotify, Reproducciones y duración
- Método usado para conseguir las reproducciones ("Popular del artista" / "Página individual")
- Género, Popularidad (0-100) y Año de lanzamiento (API de Spotify)
- BPM y Tonalidad (Spotify si tu app tiene acceso a `audio-features`, si no vía GetSongBPM)
- Energía, Compás, Bailabilidad, Vivacidad (solo si tu app tiene acceso a `audio-features`)

Pensado para bandas de covers: BPM/Energía ayudan a armar la curva del show, Popularidad da una
idea de qué temas reconoce más el público.

## Notas

- El scraping de la página de Spotify puede romperse si Spotify cambia su HTML — es la única
  forma de obtener el conteo exacto de reproducciones, ya que la API oficial no lo expone.
- El endpoint `audio-features` de Spotify (BPM, tonalidad, energía, compás, bailabilidad,
  vivacidad) devuelve 403 para apps sin "Extended Quota Mode" desde nov-2024 — confirmado con
  este proyecto, no es un bug. BPM y Tonalidad se recuperan vía [GetSongBPM](https://getsongbpm.com)
  como fuente alternativa (requiere `GETSONGBPM_API_KEY` en `.env`, ver `.env.example`); Energía,
  Compás, Bailabilidad y Vivacidad no tienen reemplazo gratuito y quedan vacías.
- Es un proyecto personal para uso propio/bajo demanda, no pensado para correr en paralelo
  contra muchas cuentas ni a gran escala.
- `.cache_canciones.json` (en la raíz del proyecto, gitignored) guarda los datos estables de
  cada canción ya procesada. Si algún dato quedó mal cacheado (p. ej. un tema mal identificado),
  borrá esa entrada del JSON o el archivo entero — se regenera solo en la próxima corrida.

---
Datos de BPM/tonalidad cuando Spotify los bloquea: [GetSongBPM.com](https://getsongbpm.com)
