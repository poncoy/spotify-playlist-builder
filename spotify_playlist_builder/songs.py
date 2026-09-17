"""Lectura y parseo del archivo de setlist (canciones.txt)."""

import os
import re
from dataclasses import dataclass

SEPARADORES = [";", ",", ":", "/", "\t", "|"]
NOMBRES_SEPARADOR = {
    ",": "coma",
    ";": "punto y coma",
    ":": "dos puntos",
    "/": "barra",
    "\t": "tabulación",
    "|": "pipe",
}


@dataclass
class Cancion:
    bloque: str
    orden: int
    cancion: str
    artista: str
    version: str = ""  # "vivo" para forzar esa versión; vacío = detección automática


def _detectar_separador(linea: str) -> tuple[list[str], str | None]:
    for sep in SEPARADORES:
        if sep in linea:
            partes = [p.strip() for p in linea.split(sep)]
            if len(partes) >= 4:
                return partes, sep
    return [], None


def cargar_canciones(ruta: str) -> tuple[list[Cancion], str | None]:
    """Carga canciones con información de bloque y orden desde `ruta`.

    Formato esperado por línea: Bloque;Orden;Canción;Artista[;País][;Versión]
    (el separador se detecta automáticamente entre ; , : / | o tab). País se
    ignora; Versión es opcional y solo se usa si vale "vivo" (fuerza esa
    versión en la búsqueda de Spotify en vez de la de estudio).
    La primera línea puede declarar el evento: `# Evento: Nombre`.
    """
    if not os.path.exists(ruta):
        carpeta = os.path.dirname(ruta) or "."
        print(f"❌ Archivo '{ruta}' no encontrado")
        print(f"📂 Archivos .txt disponibles en '{carpeta}':")
        for archivo in os.listdir(carpeta) if os.path.isdir(carpeta) else []:
            if archivo.endswith(".txt"):
                print(f"   - {archivo}")
        return [], None

    canciones: list[Cancion] = []
    nombre_evento = None
    separador_detectado = None

    with open(ruta, "r", encoding="utf-8") as f:
        lineas = f.read().strip().split("\n")

    print(f"📄 Leyendo '{ruta}' ({len(lineas)} líneas)...")

    for i, linea in enumerate(lineas):
        linea = linea.strip()
        if not linea:
            continue

        if linea.startswith("# Evento") or linea.startswith("#Evento"):
            nombre_evento = re.sub(r"#\s*Evento\s*:?\s*", "", linea).strip()
            print(f"   ✅ Evento encontrado: '{nombre_evento}'")
            continue

        if linea.startswith("#"):
            continue

        if "Bloque" in linea and "Orden" in linea and "Canción" in linea:
            continue

        partes, separador_usado = _detectar_separador(linea)

        if len(partes) < 4:
            if i <= 5:
                print(f"   ⚠️ Línea {i + 1} ignorada (formato incorrecto): '{linea}'")
            continue

        if separador_detectado is None and separador_usado:
            separador_detectado = separador_usado
            nombre_sep = NOMBRES_SEPARADOR.get(separador_usado, "otro")
            print(f"   🔍 Separador detectado: '{separador_usado}' ({nombre_sep})")

        bloque, orden, cancion, artista = partes[0], partes[1], partes[2], partes[3]
        version = partes[5].strip() if len(partes) >= 6 else ""

        try:
            orden_num = int(orden)
        except ValueError:
            orden_num = 999

        if cancion and artista:
            canciones.append(
                Cancion(bloque=bloque, orden=orden_num, cancion=cancion, artista=artista, version=version)
            )

    print(f"   ✅ {len(canciones)} canciones cargadas correctamente")
    return canciones, nombre_evento
