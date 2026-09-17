"""Aviso de vencimiento de credenciales (Client Secret de Spotify, API key de GetSongBPM).

Ninguna de las dos tiene una expiración forzada por el proveedor, pero es
buena práctica revisarlas/rotarlas cada cierto tiempo. Esto avisa en cada
corrida, con urgencia creciente, cuando se acerca la fecha que vos elegiste
para hacerlo (`*_ROTATED_AT` + `*_ROTATION_DAYS` en el .env).
"""

from datetime import date, timedelta

from .config import Credenciales

SPOTIFY_DASHBOARD_URL = "https://developer.spotify.com/dashboard"
GETSONGBPM_DASHBOARD_URL = "https://getsongbpm.com/api"


def dias_hasta_rotacion(rotado_en: date, rotacion_dias: int, hoy: date | None = None) -> int:
    """Días que faltan hasta la fecha de rotación (negativo si ya venció)."""
    vencimiento = rotado_en + timedelta(days=rotacion_dias)
    return (vencimiento - (hoy or date.today())).days


def verificar_rotacion(nombre: str, rotado_en: date | None, rotacion_dias: int, url: str, hoy: date | None = None) -> None:
    """Imprime un aviso si faltan <=15, <=7 o <=3 días para la fecha elegida, o si ya pasó."""
    if rotado_en is None:
        return

    dias = dias_hasta_rotacion(rotado_en, rotacion_dias, hoy)

    if dias <= 0:
        print(f"🔴 URGENTE: pasaron {-dias} día(s) del plazo que te pusiste para revisar {nombre}. Revisalo en {url}")
    elif dias <= 3:
        print(f"🔴 Quedan {dias} día(s) para revisar {nombre} ({url})")
    elif dias <= 7:
        print(f"🟠 Quedan {dias} día(s) para revisar {nombre} ({url})")
    elif dias <= 15:
        print(f"🟡 Quedan {dias} día(s) para revisar {nombre} ({url})")


def verificar_rotacion_secreto(credenciales: Credenciales, hoy: date | None = None) -> None:
    verificar_rotacion(
        "el Client Secret de Spotify", credenciales.secreto_rotado_en, credenciales.rotacion_dias, SPOTIFY_DASHBOARD_URL, hoy
    )
    verificar_rotacion(
        "la API key de GetSongBPM",
        credenciales.getsongbpm_key_rotado_en,
        credenciales.getsongbpm_rotacion_dias,
        GETSONGBPM_DASHBOARD_URL,
        hoy,
    )
