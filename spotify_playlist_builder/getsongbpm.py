"""Fallback de BPM y tonalidad vía GetSongBPM.com.

Se usa cuando el audio-features de Spotify no está disponible (403 para apps
sin Extended Quota Mode, ver README). Requiere una API key gratuita propia
registrada en https://getsongbpm.com/api (GETSONGBPM_API_KEY en .env).

Atribución de datos: https://getsongbpm.com
"""

import requests

BASE_URL = "https://api.getsong.co/search/"


def _mejor_resultado(resultados: list[dict], cancion: str, artista: str) -> dict | None:
    """Entre los resultados, prioriza los que tienen tempo real (no nulo) y
    coinciden con el artista buscado; entre esos, el título más parecido."""
    candidatos = [r for r in resultados if r.get("tempo")]
    if not candidatos:
        return None

    exactos = [r for r in candidatos if r["artist"]["name"].strip().lower() == artista.strip().lower()]
    pool = exactos or candidatos
    pool.sort(key=lambda r: r["title"].strip().lower() != cancion.strip().lower())
    return pool[0]


def buscar_bpm_y_tonalidad(api_key: str, cancion: str, artista: str) -> tuple[float | None, str | None]:
    """Devuelve (bpm, tonalidad) desde GetSongBPM, o (None, None) si no hay dato."""
    try:
        respuesta = requests.get(
            BASE_URL,
            params={"api_key": api_key, "type": "both", "lookup": f"song:{cancion} artist:{artista}"},
            timeout=10,
        )
        respuesta.raise_for_status()
        datos = respuesta.json()
    except Exception as e:
        print(f"   ⚠️ Error consultando GetSongBPM: {e}")
        return None, None

    resultados = datos.get("search")
    if not isinstance(resultados, list):
        return None, None

    mejor = _mejor_resultado(resultados, cancion, artista)
    if not mejor:
        return None, None

    bpm = float(mejor["tempo"]) if mejor.get("tempo") else None
    tonalidad = mejor.get("key_of") or None
    return bpm, tonalidad
