"""Punto de entrada: procesa el setlist, obtiene datos de Spotify y arma la(s) playlist(s)."""

import time
from datetime import datetime

import pandas as pd

from . import __version__
from .config import CANCIONES_FILE, cargar_credenciales
from .playlist import crear_playlist_spotify
from .scraper import obtener_reproducciones
from .songs import Cancion, cargar_canciones
from .spotify_api import SpotifyPlaylistClient, ms_a_hhmss

COLUMNAS_RESUMEN = [
    "Bloque",
    "Orden",
    "Canción",
    "Artista",
    "Reproducciones",
    "Duración (HH:MM:SS)",
    "Género",
    "Tonalidad",
]


def procesar_cancion(client: SpotifyPlaylistClient, cancion: Cancion) -> dict:
    """Busca una canción en Spotify y le suma el conteo de reproducciones scrapeado."""
    print(f"🔍 Buscando: '{cancion.cancion}' por '{cancion.artista}'")

    track = client.buscar_track(cancion.cancion, cancion.artista)
    if not track:
        return {
            "Bloque": cancion.bloque,
            "Orden": cancion.orden,
            "Canción": cancion.cancion,
            "Artista": cancion.artista,
            "Reproducciones": "No encontrada",
            "Duración (HH:MM:SS)": "00:00:00",
            "Género": "Desconocido",
            "Tonalidad": "Desconocida",
            "URI": None,
        }

    print(f"   📍 {track.nombre} - {track.artista} | Género: {track.genero} | Tonalidad: {track.tonalidad}")
    reproducciones = obtener_reproducciones(track.url, track.nombre)

    return {
        "Bloque": cancion.bloque,
        "Orden": cancion.orden,
        "Canción": track.nombre,
        "Artista": track.artista,
        "Reproducciones": f"{reproducciones:,}" if reproducciones else "No disponible",
        "Duración (HH:MM:SS)": ms_a_hhmss(track.duracion_ms),
        "Género": track.genero,
        "Tonalidad": track.tonalidad,
        "URL": track.url,
        "URI": track.uri,
    }


def _preguntar_si_no(mensaje: str) -> bool:
    return input(mensaje).strip().lower() in ("s", "si", "y", "yes")


def _resumen_bloques(canciones: list[Cancion]) -> dict[str, int]:
    resumen: dict[str, int] = {}
    for c in canciones:
        resumen[c.bloque] = resumen.get(c.bloque, 0) + 1
    return resumen


def main() -> pd.DataFrame | None:
    print(f"🎵 Spotify Playlist Builder v{__version__}")

    credenciales = cargar_credenciales()
    if not credenciales:
        return None

    canciones, nombre_evento = cargar_canciones(CANCIONES_FILE)
    if not canciones:
        print(f"❌ No se pudieron cargar canciones desde '{CANCIONES_FILE}'")
        print("📝 Formato esperado:")
        print("   # Evento: Nombre del Evento")
        print("   Bloque;Orden;Canción;Artista")
        print("   B1;1;Nombre canción;Nombre artista")
        return None

    print(f"✅ {len(canciones)} canciones cargadas | Evento: {nombre_evento or 'sin nombre'}")
    for bloque, cantidad in sorted(_resumen_bloques(canciones).items()):
        print(f"   - {bloque}: {cantidad} canciones")

    client = SpotifyPlaylistClient(credenciales)

    print("\n🔐 Para crear la(s) playlist(s) hace falta autorizar tu cuenta de Spotify.")
    spotify_user_ok = False
    if _preguntar_si_no("¿Continuar con la autenticación? (s/n): "):
        spotify_user_ok = client.autenticar_usuario()
    else:
        print("⚠️  Continuando solo con extracción de datos (sin crear playlist)")

    multiples_playlists = False
    if spotify_user_ok:
        opcion = input("\n¿Playlist única (1) o una por bloque (2)?: ").strip()
        multiples_playlists = opcion == "2"

    print("\n🔍 Procesando canciones (Chrome headless para leer reproducciones)...")
    start_time = time.time()
    resultados = [procesar_cancion(client, c) for c in canciones]
    total_time = time.time() - start_time

    df = pd.DataFrame(resultados)
    print("\n" + "=" * 100)
    print(df[COLUMNAS_RESUMEN].to_string(index=False))

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    minutos, segundos = divmod(int(total_time), 60)
    tiempo_str = f"{minutos}min{segundos}seg" if minutos else f"{segundos}seg"
    archivo_salida = f"spotify_direct_{__version__}_{timestamp}_{tiempo_str}.csv"
    df.to_csv(archivo_salida, index=False, encoding="utf-8")
    print(f"\n💾 Guardado en: {archivo_salida}")

    if spotify_user_ok:
        crear_playlist_spotify(client, nombre_evento, resultados, multiples_playlists)

    encontradas = (df["Reproducciones"] != "No encontrada").sum()
    con_numeros = (df["Reproducciones"] != "No disponible").sum()
    print(f"\n📈 Encontradas: {encontradas}/{len(df)} | Con reproducciones: {con_numeros}/{len(df)}")

    return df


if __name__ == "__main__":
    main()
