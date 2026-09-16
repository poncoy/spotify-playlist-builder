"""Aviso de vencimiento del Client Secret de Spotify.

Spotify no expira el secret automáticamente, pero es buena práctica rotarlo
cada cierto tiempo. Esto avisa en cada corrida, con urgencia creciente, cuando
se acerca la fecha en la que vos decidiste rotarlo (SPOTIFY_SECRET_ROTATED_AT
+ SPOTIFY_SECRET_ROTATION_DAYS en el .env).
"""

from datetime import date, timedelta

from .config import Credenciales

DASHBOARD_URL = "https://developer.spotify.com/dashboard"


def dias_hasta_rotacion(rotado_en: date, rotacion_dias: int, hoy: date | None = None) -> int:
    """Días que faltan hasta la fecha de rotación (negativo si ya venció)."""
    vencimiento = rotado_en + timedelta(days=rotacion_dias)
    return (vencimiento - (hoy or date.today())).days


def verificar_rotacion_secreto(credenciales: Credenciales, hoy: date | None = None) -> None:
    """Imprime un aviso si faltan <=15, <=7 o <=3 días para la rotación, o si ya venció."""
    if credenciales.secreto_rotado_en is None:
        return

    dias = dias_hasta_rotacion(credenciales.secreto_rotado_en, credenciales.rotacion_dias, hoy)

    if dias <= 0:
        print(f"🔴 URGENTE: el Client Secret de Spotify venció hace {-dias} día(s). Rotalo en {DASHBOARD_URL}")
    elif dias <= 3:
        print(f"🔴 Quedan {dias} día(s) para rotar tu Client Secret de Spotify ({DASHBOARD_URL})")
    elif dias <= 7:
        print(f"🟠 Quedan {dias} día(s) para rotar tu Client Secret de Spotify ({DASHBOARD_URL})")
    elif dias <= 15:
        print(f"🟡 Quedan {dias} día(s) para rotar tu Client Secret de Spotify ({DASHBOARD_URL})")
