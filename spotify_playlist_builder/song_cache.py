"""Caché persistente de datos estables de una canción (ID, duración, género,
tonalidad, BPM, etc.) para no repetir búsquedas de Spotify/GetSongBPM en
setlists que reusan temas ya procesados en una corrida anterior.

Reproducciones y Popularidad NO se cachean acá — esos cambian con el tiempo,
así que siempre se vuelven a pedir frescos (ver SpotifyPlaylistClient).
"""

import json
import os

RUTA_DEFAULT = ".cache_canciones.json"


def clave_cache(cancion: str, artista: str, version: str) -> str:
    return f"{cancion.strip().lower()}|||{artista.strip().lower()}|||{version.strip().lower()}"


def cargar_cache(ruta: str = RUTA_DEFAULT) -> dict:
    if not os.path.exists(ruta):
        return {}
    try:
        with open(ruta, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"⚠️  No se pudo leer el caché de canciones ({e}), se arranca vacío")
        return {}


def guardar_cache(cache: dict, ruta: str = RUTA_DEFAULT) -> None:
    try:
        with open(ruta, "w", encoding="utf-8") as f:
            json.dump(cache, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"⚠️  No se pudo guardar el caché de canciones: {e}")
