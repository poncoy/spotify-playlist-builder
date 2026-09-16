"""Creación de playlist(s) en la cuenta del usuario a partir de los resultados procesados."""

import random
import time
from collections import defaultdict
from datetime import datetime

from .spotify_api import SpotifyPlaylistClient

LOTE_MAXIMO = 100


def _uris_validos(canciones_data: list[dict]) -> list[str]:
    return [c["URI"] for c in canciones_data if c.get("URI") and c["Reproducciones"] != "No encontrada"]


def _agregar_items_en_lotes(client: SpotifyPlaylistClient, playlist_id: str, uris: list[str]) -> None:
    for i in range(0, len(uris), LOTE_MAXIMO):
        lote = uris[i : i + LOTE_MAXIMO]
        client.sp_user.playlist_add_items(playlist_id, lote)
        if i + LOTE_MAXIMO < len(uris):
            time.sleep(1)


def crear_playlist_unica(client: SpotifyPlaylistClient, nombre_evento: str, canciones_data: list[dict]) -> bool:
    uris = _uris_validos(canciones_data)
    if not uris:
        print("❌ No hay canciones válidas para agregar a la playlist")
        return False

    user_id = client.sp_user.current_user()["id"]
    timestamp = datetime.now().strftime("%d-%m-%Y")
    nombre = f"{nombre_evento} - La Sed ({timestamp})"

    print(f"🎵 Creando playlist única: {nombre}")
    playlist = client.sp_user.user_playlist_create(
        user=user_id,
        name=nombre,
        public=False,
        description=f"Playlist creada automáticamente el {timestamp} con {len(uris)} canciones",
    )
    _agregar_items_en_lotes(client, playlist["id"], uris)

    print(f"\n🎉 ¡Playlist creada! {nombre} — {playlist['external_urls']['spotify']}")
    return True


def crear_playlists_por_bloque(client: SpotifyPlaylistClient, nombre_evento: str, canciones_data: list[dict]) -> bool:
    por_bloque = defaultdict(list)
    for cancion in canciones_data:
        if cancion.get("URI") and cancion["Reproducciones"] != "No encontrada":
            por_bloque[cancion["Bloque"]].append(cancion)

    if not por_bloque:
        print("❌ No hay canciones válidas para crear playlists")
        return False

    user_id = client.sp_user.current_user()["id"]
    print(f"\n🎵 Creando {len(por_bloque)} playlists por bloque...")
    creadas = []

    for bloque, canciones in por_bloque.items():
        if bloque.lower() != "sin bloque":
            canciones_ordenadas = sorted(canciones, key=lambda c: c["Orden"])
        else:
            canciones_ordenadas = canciones.copy()
            random.shuffle(canciones_ordenadas)

        nombre = f"{bloque} - {nombre_evento} - La Sed"
        print(f"\n📁 Creando playlist: {nombre}")

        playlist = client.sp_user.user_playlist_create(
            user=user_id,
            name=nombre,
            public=False,
            description=f"Playlist del {bloque} - Evento: {nombre_evento} - {len(canciones_ordenadas)} canciones",
        )
        uris = [c["URI"] for c in canciones_ordenadas]
        _agregar_items_en_lotes(client, playlist["id"], uris)

        print(f"✅ '{nombre}' creada con {len(uris)} canciones — {playlist['external_urls']['spotify']}")
        creadas.append({"nombre": nombre, "url": playlist["external_urls"]["spotify"], "canciones": len(uris)})
        time.sleep(2)

    print(f"\n🎉 ¡{len(creadas)} playlists creadas!")
    for p in creadas:
        print(f"   🎵 {p['nombre']} - {p['canciones']} canciones — {p['url']}")
    return True


def crear_playlist_spotify(
    client: SpotifyPlaylistClient, nombre_evento: str | None, canciones_data: list[dict], multiples_playlists: bool = False
) -> bool:
    """Crea una playlist única o una por bloque, según `multiples_playlists`."""
    if not client.sp_user:
        print("❌ No hay conexión de usuario para crear playlist")
        return False
    if not nombre_evento:
        print("❌ No se encontró nombre del evento en el archivo de canciones")
        return False

    try:
        if multiples_playlists:
            return crear_playlists_por_bloque(client, nombre_evento, canciones_data)
        return crear_playlist_unica(client, nombre_evento, canciones_data)
    except Exception as e:
        print(f"❌ Error creando playlist(s): {e}")
        return False
