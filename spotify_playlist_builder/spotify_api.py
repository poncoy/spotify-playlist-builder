"""Cliente de la API de Spotify: búsqueda de tracks, género, tonalidad, BPM y demás
audio-features, y auth OAuth."""

from dataclasses import asdict, dataclass

import spotipy
from spotipy.oauth2 import SpotifyClientCredentials, SpotifyOAuth

from .config import Credenciales
from .song_cache import clave_cache

NOTAS = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

# Géneros "crudos" de Spotify normalizados a una etiqueta legible en español.
GENERO_POR_PRIORIDAD = {
    "latin pop": "Pop Latino",
    "pop": "Pop",
    "ballad": "Balada",
    "latin ballad": "Balada Latina",
    "classic rock": "Rock Clásico",
    "rock": "Rock",
    "hard rock": "Hard Rock",
    "arena rock": "Arena Rock",
    "reggaeton": "Reggaeton",
    "latin hip hop": "Hip Hop Latino",
    "hip hop": "Hip Hop",
    "rap": "Rap",
    "trap": "Trap",
    "salsa": "Salsa",
    "cumbia": "Cumbia",
    "merengue": "Merengue",
    "bachata": "Bachata",
    "tropical": "Tropical",
    "mariachi": "Mariachi",
    "electronic": "Electrónica",
    "dance": "Dance",
    "jazz": "Jazz",
    "blues": "Blues",
    "country": "Country",
    "folk": "Folk",
    "classical": "Clásica",
    "ska": "Ska",
    "punk": "Punk",
}

PUERTOS_OAUTH = [8888, 8889, 9090, 9091, 8765, 8766]
SCOPE_PLAYLIST = "playlist-modify-public playlist-modify-private user-read-private user-read-email"

# Etiquetas de versión que Spotify suele agregar al título. Si el título
# pedido en canciones.txt (o el campo opcional Versión) no las menciona, se
# penalizan para priorizar la versión de estudio.
MARCADORES_VIVO = (
    "vivo", "live", "en directo", "en concierto", "concierto", "unplugged", "gira", "tour",
)
MARCADORES_OTRA_VERSION = ("remix", "demo", "instrumental", "karaoke", "remaster", "acustic", "acústic")

VALORES_VERSION_VIVO = ("vivo", "en vivo", "live")


@dataclass
class TrackInfo:
    id: str
    url: str
    artist_url: str
    nombre: str
    artista: str
    duracion_ms: int
    uri: str
    genero: str
    tonalidad: str
    popularidad: int
    anio_lanzamiento: str
    bpm: float | None
    energia: float | None
    compas: int | None
    bailabilidad: float | None
    vivacidad: float | None


def ms_a_hhmss(milisegundos: int | None) -> str:
    """Convierte milisegundos a formato HH:MM:SS."""
    if not milisegundos:
        return "00:00:00"
    segundos_totales = int(milisegundos / 1000)
    horas = segundos_totales // 3600
    minutos = (segundos_totales % 3600) // 60
    segundos = segundos_totales % 60
    return f"{horas:02d}:{minutos:02d}:{segundos:02d}"


def _tonalidad_desde_key_mode(key: int | None, mode: int | None) -> str:
    if key is None or mode is None or not (0 <= key < len(NOTAS)):
        return "Desconocida"
    nota = NOTAS[key]
    return nota if mode == 1 else nota + "m"  # mode 1 = mayor, 0 = menor


def _artistas_legibles(track: dict) -> str:
    return ", ".join(a["name"] for a in track["artists"])


def _nombre_y_artistas(track: dict) -> tuple[str, list[str]]:
    return track["name"].lower(), [a["name"].lower() for a in track["artists"]]


def _tiene_alguno(texto: str, marcadores: tuple[str, ...]) -> bool:
    return any(marcador in texto for marcador in marcadores)


def _quiere_vivo(cancion_lower: str, version_pedida: str) -> bool:
    """El campo Versión (si viene) manda; si no, se infiere del propio título
    pedido (p. ej. si ya dice "... - En Vivo" o "... Gira 2007")."""
    version_pedida = version_pedida.strip().lower()
    if version_pedida:
        return version_pedida in VALORES_VERSION_VIVO
    return _tiene_alguno(cancion_lower, MARCADORES_VIVO)


def _score_track(track: dict, cancion: str, artista: str, version_pedida: str = "") -> int:
    """Puntúa qué tan bien matchea un track. 0 = descartado (sin coincidencia
    de artista). Penaliza vivo/estudio si no coincide con lo pedido (Versión o
    el propio título), y penaliza más liviano otras variantes no pedidas
    (remix, acústico, karaoke, etc.), sin descartarlas del todo por si son lo
    único disponible en Spotify."""
    track_name, track_artists = _nombre_y_artistas(track)
    cancion_lower, artista_lower = cancion.lower(), artista.lower()

    if track_name == cancion_lower:
        score = 4
    elif cancion_lower in track_name:
        score = 2
    elif track_name in cancion_lower:
        score = 1
    else:
        return 0

    if not any(artista_lower in a or a in artista_lower for a in track_artists):
        return 0
    score += 2

    if _tiene_alguno(track_name, MARCADORES_VIVO) != _quiere_vivo(cancion_lower, version_pedida):
        score -= 3
    elif _tiene_alguno(track_name, MARCADORES_OTRA_VERSION) and not _tiene_alguno(cancion_lower, MARCADORES_OTRA_VERSION):
        score -= 2

    return score


def _mejor_track(tracks: list[dict], cancion: str, artista: str, version_pedida: str = "") -> dict | None:
    puntuados = [(track, _score_track(track, cancion, artista, version_pedida)) for track in tracks]
    candidatos = [(track, score) for track, score in puntuados if score > 0]
    if not candidatos:
        return None
    return max(candidatos, key=lambda par: par[1])[0]


def _metricas_desde_audio_features(audio_features: dict | None) -> dict:
    if not audio_features:
        return {"tonalidad": "Desconocida", "bpm": None, "energia": None, "compas": None, "bailabilidad": None, "vivacidad": None}
    return {
        "tonalidad": _tonalidad_desde_key_mode(audio_features["key"], audio_features["mode"]),
        "bpm": round(audio_features["tempo"]),
        "energia": audio_features["energy"],
        "compas": audio_features["time_signature"],
        "bailabilidad": audio_features["danceability"],
        "vivacidad": audio_features["liveness"],
    }


def _genero_desde_lista(genres: list[str]) -> str:
    if not genres:
        return "Desconocido"

    for genre in genres:
        genre_lower = genre.lower()
        if genre_lower in GENERO_POR_PRIORIDAD:
            return GENERO_POR_PRIORIDAD[genre_lower]

    for genre in genres:
        genre_lower = genre.lower()
        for clave, valor in GENERO_POR_PRIORIDAD.items():
            if clave in genre_lower or genre_lower in clave:
                return valor

    return genres[0].title()


class SpotifyPlaylistClient:
    """Envuelve los dos clientes de Spotify que necesita la app: búsqueda (app-only)
    y usuario (OAuth, necesario para crear playlists y leer audio-features)."""

    def __init__(self, credenciales: Credenciales, cache: dict | None = None):
        self._credenciales = credenciales
        auth = SpotifyClientCredentials(
            client_id=credenciales.client_id, client_secret=credenciales.client_secret
        )
        self.sp_search = spotipy.Spotify(auth_manager=auth)
        self.sp_user: spotipy.Spotify | None = None
        self._cache = cache if cache is not None else {}
        self._audio_features_bloqueado = False

    def autenticar_usuario(self) -> bool:
        """Autentica con OAuth de usuario, probando varios puertos de redirect locales
        (útil cuando el usuario ya tiene otro proceso ocupando el puerto por defecto)."""
        for puerto in PUERTOS_OAUTH:
            redirect_uri = f"http://127.0.0.1:{puerto}"
            print(f"\n🔐 Intentando autenticación OAuth en puerto {puerto}...")
            print(f"⚠️  Asegurate de tener esta Redirect URI en tu Spotify Dashboard: {redirect_uri}")

            auth = SpotifyOAuth(
                client_id=self._credenciales.client_id,
                client_secret=self._credenciales.client_secret,
                redirect_uri=redirect_uri,
                scope=SCOPE_PLAYLIST,
                cache_path=f".cache_playlist_{puerto}",
                show_dialog=True,
                open_browser=True,
            )

            try:
                sp_user = spotipy.Spotify(auth_manager=auth)
                user = sp_user.current_user()
                print(f"✅ ¡Conexión exitosa! Usuario: {user['display_name']}")
                self.sp_user = sp_user
                return True
            except Exception as e:
                print(f"⚠️  Falló en puerto {puerto}: {e}")
                continue

        print("\n❌ No se pudo establecer conexión OAuth en ningún puerto")
        return False

    def _cliente_para_audio_features(self) -> spotipy.Spotify:
        return self.sp_user if self.sp_user else self.sp_search

    def _audio_features_de_track(self, track_id: str) -> dict | None:
        if self._audio_features_bloqueado:
            return None
        try:
            audio_features = self._cliente_para_audio_features().audio_features([track_id])[0]
        except Exception as e:
            print(f"   ⚠️ Error obteniendo audio features: {e}")
            print("   ⏭️  Tu app no tiene acceso a audio-features — no se vuelve a intentar en esta corrida")
            self._audio_features_bloqueado = True
            return None
        return audio_features

    def _genero_de_artista(self, artist_id: str) -> str:
        try:
            artist_info = self._cliente_para_audio_features().artist(artist_id)
        except Exception as e:
            print(f"   ⚠️ Error obteniendo género: {e}")
            return "Desconocido"
        return _genero_desde_lista(artist_info.get("genres", []))

    def _track_a_info(self, track: dict) -> TrackInfo:
        artist_id = track["artists"][0]["id"]
        metricas = _metricas_desde_audio_features(self._audio_features_de_track(track["id"]))
        release_date = track.get("album", {}).get("release_date", "")

        return TrackInfo(
            id=track["id"],
            url=track["external_urls"]["spotify"],
            artist_url=track["artists"][0]["external_urls"]["spotify"],
            nombre=track["name"],
            artista=_artistas_legibles(track),
            duracion_ms=track["duration_ms"],
            uri=track["uri"],
            genero=self._genero_de_artista(artist_id),
            popularidad=track.get("popularity", 0),
            anio_lanzamiento=release_date[:4] if release_date else "Desconocido",
            **metricas,
        )

    def _popularidad_actual(self, track_id: str, respaldo: int) -> int:
        """Popularidad SIEMPRE se pide fresca (fluctúa con el tiempo), incluso
        cuando el resto del track viene del caché."""
        try:
            return self.sp_search.track(track_id)["popularity"]
        except Exception as e:
            print(f"   ⚠️ No se pudo refrescar la popularidad, se usa la del caché: {e}")
            return respaldo

    def buscar_track(self, cancion: str, artista: str, version_pedida: str = "") -> TrackInfo | None:
        """Busca una canción, primero con match exacto y luego con una búsqueda más
        laxa; en ambos casos se queda con el track de mejor score (ver _mejor_track),
        que prioriza la versión de estudio salvo que `version_pedida="vivo"` o el
        propio título ya pida otra cosa.

        Los datos estables (BPM, tonalidad, duración, género, etc.) se cachean
        entre corridas — no cambian entre un evento y otro. La popularidad sí
        se vuelve a pedir siempre, ya sea de un track nuevo o de uno cacheado."""
        clave = clave_cache(cancion, artista, version_pedida)
        if clave in self._cache:
            datos = dict(self._cache[clave])
            datos["popularidad"] = self._popularidad_actual(datos["id"], datos.get("popularidad", 0))
            info = TrackInfo(**datos)
            print(f"   ⚡ Encontrada en caché: {info.nombre} - {info.artista}")
            return info

        query = f'track:"{cancion}" artist:"{artista}"'
        resultados = self.sp_search.search(q=query, type="track", limit=10)["tracks"]["items"]
        mejor = _mejor_track(resultados, cancion, artista, version_pedida)

        if not mejor:
            print("   ⚠️ Búsqueda exacta fallida, intentando búsqueda general...")
            resultados = self.sp_search.search(q=f"{cancion} {artista}", type="track", limit=10)["tracks"]["items"]
            mejor = _mejor_track(resultados, cancion, artista, version_pedida)

        if not mejor:
            print(f"   ❌ No se encontró coincidencia para: {cancion} - {artista}")
            return None

        print(f"   ✅ Encontrada: {mejor['name']} - {_artistas_legibles(mejor)}")
        info = self._track_a_info(mejor)
        self._cache[clave] = asdict(info)
        return info
