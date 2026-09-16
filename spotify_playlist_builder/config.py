"""Carga de configuración y credenciales desde variables de entorno (.env)."""

import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


@dataclass
class Credenciales:
    client_id: str
    client_secret: str


def cargar_credenciales() -> Credenciales | None:
    """Carga CLIENT_ID/CLIENT_SECRET desde el entorno (.env o variables exportadas)."""
    client_id = os.environ.get("SPOTIFY_CLIENT_ID")
    client_secret = os.environ.get("SPOTIFY_CLIENT_SECRET")

    if not client_id or not client_secret:
        print("⚠️  No se encontraron SPOTIFY_CLIENT_ID / SPOTIFY_CLIENT_SECRET.")
        print("    Copiá .env.example a .env y completá tus credenciales de Spotify.")
        return None

    return Credenciales(client_id=client_id, client_secret=client_secret)


CANCIONES_FILE = os.environ.get("CANCIONES_FILE", "canciones.txt")
