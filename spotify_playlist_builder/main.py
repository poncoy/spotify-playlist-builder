"""Punto de entrada: procesa el setlist, obtiene datos de Spotify y arma la(s) playlist(s)."""

import time
from datetime import datetime

import pandas as pd

from . import __version__
from .config import CANCIONES_FILE, cargar_credenciales
from .playlist import crear_playlist_spotify
from .scraper import obtener_reproducciones
from .secret_rotation import verificar_rotacion_secreto
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
    "BPM",
    "Popularidad",
    "Energía",
    "Compás",
    "Año",
    "Bailabilidad",
    "Vivacidad",
]


def procesar_cancion(client: SpotifyPlaylistClient, cancion: Cancion) -> dict:
    """Busca una canción en Spotify y le suma el conteo de reproducciones scrapeado."""
    print(f"🔍 Buscando: '{cancion.cancion}' por '{cancion.artista}'")

    resultado = {
        "Bloque": cancion.bloque,
        "Orden": cancion.orden,
        "Canción": cancion.cancion,
        "Artista": cancion.artista,
        "Reproducciones": "No encontrada",
        "Duración (HH:MM:SS)": "00:00:00",
        "Género": "Desconocido",
        "Tonalidad": "Desconocida",
        "BPM": None,
        "Popularidad": None,
        "Energía": None,
        "Compás": None,
        "Año": "Desconocido",
        "Bailabilidad": None,
        "Vivacidad": None,
        "URL": None,
        "URI": None,
    }

    track = client.buscar_track(cancion.cancion, cancion.artista)
    if not track:
        return resultado

    print(
        f"   📍 {track.nombre} - {track.artista} | Género: {track.genero} | Tonalidad: {track.tonalidad} "
        f"| BPM: {track.bpm} | Popularidad: {track.popularidad}"
    )
    reproducciones = obtener_reproducciones(track.url, track.nombre)

    resultado.update(
        Canción=track.nombre,
        Artista=track.artista,
        Reproducciones=f"{reproducciones:,}" if reproducciones else "No disponible",
        Género=track.genero,
        Tonalidad=track.tonalidad,
        BPM=track.bpm,
        Popularidad=track.popularidad,
        Energía=track.energia,
        Compás=track.compas,
        Año=track.anio_lanzamiento,
        Bailabilidad=track.bailabilidad,
        Vivacidad=track.vivacidad,
        URL=track.url,
        URI=track.uri,
    )
    resultado["Duración (HH:MM:SS)"] = ms_a_hhmss(track.duracion_ms)
    return resultado


def _preguntar_si_no(mensaje: str) -> bool:
    return input(mensaje).strip().lower() in ("s", "si", "y", "yes")


def _resumen_bloques(canciones: list[Cancion]) -> dict[str, int]:
    resumen: dict[str, int] = {}
    for c in canciones:
        resumen[c.bloque] = resumen.get(c.bloque, 0) + 1
    return resumen


def _formato_duracion(segundos: float, separador: str = " ") -> str:
    """Formatea una duración en segundos como 'Xh Ym Zs', escalando a horas si hace falta."""
    segundos = int(segundos)
    horas, resto = divmod(segundos, 3600)
    minutos, segs = divmod(resto, 60)
    partes = []
    if horas:
        partes.append(f"{horas}h")
    if horas or minutos:
        partes.append(f"{minutos}min")
    partes.append(f"{segs}seg")
    return separador.join(partes)


def _hhmss_a_segundos(hhmmss: str) -> int:
    try:
        horas, minutos, segundos = (int(p) for p in hhmmss.split(":"))
        return horas * 3600 + minutos * 60 + segundos
    except (ValueError, AttributeError):
        return 0


def main() -> pd.DataFrame | None:
    print(f"🎵 Spotify Playlist Builder v{__version__}")

    credenciales = cargar_credenciales()
    if not credenciales:
        return None
    verificar_rotacion_secreto(credenciales)

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
    hora_inicio = datetime.now()
    start_time = time.time()
    resultados = [procesar_cancion(client, c) for c in canciones]
    total_time = time.time() - start_time
    hora_fin = datetime.now()

    df = pd.DataFrame(resultados)
    print("\n" + "=" * 100)
    print(df[COLUMNAS_RESUMEN].to_string(index=False))

    timestamp = hora_fin.strftime("%Y%m%d_%H%M%S")
    archivo_salida = f"spotify_direct_{__version__}_{timestamp}_{_formato_duracion(total_time, separador='')}.csv"
    df.to_csv(archivo_salida, index=False, encoding="utf-8")
    print(f"\n💾 Guardado en: {archivo_salida}")

    if spotify_user_ok:
        crear_playlist_spotify(client, nombre_evento, resultados, multiples_playlists)

    sin_dato = {"No encontrada", "No disponible"}
    encontradas = (df["Reproducciones"] != "No encontrada").sum()
    con_numeros = (~df["Reproducciones"].isin(sin_dato)).sum()

    print("\n" + "=" * 100)
    print("📋 REPORTE FINAL")
    print("=" * 100)
    print(f"🕐 Inicio:    {hora_inicio.strftime('%d/%m/%Y %H:%M:%S')}")
    print(f"🕐 Fin:       {hora_fin.strftime('%d/%m/%Y %H:%M:%S')}")
    print(f"⏱️  Duración:  {_formato_duracion(total_time)} para {len(df)} canciones")
    print(f"📈 Encontradas: {encontradas}/{len(df)} | Con reproducciones: {con_numeros}/{len(df)}")

    duracion_setlist_seg = sum(_hhmss_a_segundos(d) for d in df["Duración (HH:MM:SS)"])
    print(f"🎼 Duración total del setlist: {_formato_duracion(duracion_setlist_seg)}")

    bpm_promedio = df["BPM"].dropna()
    if len(bpm_promedio):
        print(f"🥁 BPM promedio: {bpm_promedio.mean():.0f} (min {bpm_promedio.min():.0f} / max {bpm_promedio.max():.0f})")

    popularidad_promedio = df["Popularidad"].dropna()
    if len(popularidad_promedio):
        print(f"🔥 Popularidad promedio: {popularidad_promedio.mean():.0f}/100")

    return df


if __name__ == "__main__":
    main()
