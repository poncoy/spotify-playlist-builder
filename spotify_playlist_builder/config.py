"""Carga de configuración y credenciales desde variables de entorno (.env)."""

import os
from dataclasses import dataclass
from datetime import date

from dotenv import load_dotenv

load_dotenv()

ROTACION_DIAS_DEFAULT = 90


@dataclass
class Credenciales:
    client_id: str
    client_secret: str
    secreto_rotado_en: date | None = None
    rotacion_dias: int = ROTACION_DIAS_DEFAULT


def _parsear_fecha(valor: str | None) -> date | None:
    if not valor:
        return None
    try:
        return date.fromisoformat(valor.strip())
    except ValueError:
        print(f"⚠️  SPOTIFY_SECRET_ROTATED_AT='{valor}' no es una fecha válida (formato: AAAA-MM-DD)")
        return None


def cargar_credenciales() -> Credenciales | None:
    """Carga CLIENT_ID/CLIENT_SECRET desde el entorno (.env o variables exportadas)."""
    client_id = os.environ.get("SPOTIFY_CLIENT_ID")
    client_secret = os.environ.get("SPOTIFY_CLIENT_SECRET")

    if not client_id or not client_secret:
        print("⚠️  No se encontraron SPOTIFY_CLIENT_ID / SPOTIFY_CLIENT_SECRET.")
        print("    Copiá .env.example a .env y completá tus credenciales de Spotify.")
        return None

    rotacion_dias = int(os.environ.get("SPOTIFY_SECRET_ROTATION_DAYS", ROTACION_DIAS_DEFAULT))

    return Credenciales(
        client_id=client_id,
        client_secret=client_secret,
        secreto_rotado_en=_parsear_fecha(os.environ.get("SPOTIFY_SECRET_ROTATED_AT")),
        rotacion_dias=rotacion_dias,
    )


CANCIONES_FILE = os.environ.get("CANCIONES_FILE", "canciones.txt")
