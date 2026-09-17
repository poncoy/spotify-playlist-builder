"""Extracción del número de reproducciones directamente de la página web de Spotify.

La API pública de Spotify no expone el contador de reproducciones de un track,
así que lo leemos con Selenium. Dos caminos, de más a menos confiable:

1. La sección "Popular" de la página del artista: lista sus ~10 temas más
   escuchados junto con las reproducciones, en un HTML estable
   (data-testid="tracklist-row" / "internal-track-link"). Una sola carga de
   página cubre todas las canciones del setlist de ese artista.
2. La página individual del track, para lo que no aparece en "Popular"
   (covers menos conocidos). El HTML ahí es mucho menos estable, así que se
   prueban varias estrategias de más a menos específica.

(La columna "Reproducciones" que se ve en el álbum dentro de la app de
escritorio de Spotify no existe en el reproductor web, así que no es una
fuente disponible para este scraper.)
"""

import re
import time

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

RANGO_REPRODUCCIONES_VALIDO = (50_000, 5_000_000_000)
NUMERO_CON_COMAS = re.compile(r"^\d{1,3}(?:,\d{3})+$")
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)


def _crear_driver() -> webdriver.Chrome:
    options = Options()
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    options.add_experimental_option("useAutomationExtension", False)
    options.add_argument(f"--user-agent={USER_AGENT}")
    options.add_argument("--disable-web-security")
    options.add_argument("--allow-running-insecure-content")

    driver = webdriver.Chrome(options=options)
    driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
    return driver


def _es_reproduccion_valida(numero: int) -> bool:
    return RANGO_REPRODUCCIONES_VALIDO[0] <= numero <= RANGO_REPRODUCCIONES_VALIDO[1]


def _parsear_numero_valido(texto: str) -> int | None:
    """Convierte '1,234,567' en 1234567 si matchea el formato y cae en el rango esperado."""
    if not NUMERO_CON_COMAS.match(texto):
        return None
    numero = int(texto.replace(",", ""))
    return numero if _es_reproduccion_valida(numero) else None


def _primer_numero_de_elementos(elementos, requiere_visible: bool = False) -> int | None:
    for elemento in elementos:
        try:
            texto = elemento.text.strip()
        except Exception:
            continue
        if requiere_visible and not elemento.is_displayed():
            continue
        numero = _parsear_numero_valido(texto)
        if numero:
            return numero
    return None


def _esperar_reproducciones(driver, timeout: float = 12, intervalo: float = 0.5) -> int | None:
    """Sondea la página cada `intervalo` segundos hasta encontrar el número de
    reproducciones o agotar `timeout`, en vez de esperar un tiempo fijo
    (algunas páginas cargan en 2s, otras tardan bastante más)."""
    limite = time.time() + timeout
    while time.time() < limite:
        numero = _buscar_en_selectores_especificos(driver)
        if numero:
            return numero
        time.sleep(intervalo)
    return None


def _buscar_en_selectores_especificos(driver) -> int | None:
    try:
        main_container = driver.find_element(By.CSS_SELECTOR, "main")
    except Exception:
        return None

    selectores = [
        'div[data-testid="track-page"] span',
        ".main-trackInfo-container span",
        ".main-trackInfo-name + * span",
        '[data-testid="entityTitle"] + * span',
        ".Type__TypeElement-sc-goli3j-0",
    ]

    for selector in selectores:
        numero = _primer_numero_de_elementos(main_container.find_elements(By.CSS_SELECTOR, selector))
        if numero:
            return numero
    return None


def _buscar_en_elementos_de_estadisticas(driver) -> int | None:
    stat_elements = driver.find_elements(
        By.XPATH, "//span[contains(@class, 'Type') or contains(@class, 'text')]"
    )
    return _primer_numero_de_elementos(stat_elements, requiere_visible=True)


def _buscar_por_contexto_en_page_source(driver) -> int | None:
    driver.execute_script("window.scrollTo(0, 200);")
    time.sleep(1)

    palabras_relevantes = ("play", "stream", "listen", "track", "song")
    page_source = driver.page_source

    for match in re.finditer(r"\b(\d{1,3}(?:,\d{3})+)\b", page_source):
        numero = int(match.group(1).replace(",", ""))
        if not _es_reproduccion_valida(numero):
            continue
        start, end = max(0, match.start() - 100), min(len(page_source), match.end() + 100)
        contexto = page_source[start:end].lower()
        if any(palabra in contexto for palabra in palabras_relevantes):
            return numero
    return None


def _ultimo_intento(driver) -> int | None:
    time.sleep(2)
    elementos = driver.find_elements(By.XPATH, "//*[text()[contains(., ',')]]")
    return _primer_numero_de_elementos(elementos[:10])


TRACK_ID_EN_HREF = re.compile(r"/track/([A-Za-z0-9]+)")
METODO_POPULAR = "Popular del artista"
METODO_PAGINA_INDIVIDUAL = "Página individual"
METODO_NO_ENCONTRADO = "No encontrado"


class ReproduccionesScraper:
    """Scrapea reproducciones reutilizando un único Chrome headless para todo el
    setlist, y cacheando la sección "Popular" de cada artista ya visitado."""

    def __init__(self):
        self._driver: webdriver.Chrome | None = None
        self._cache_popular: dict[str, dict[str, int]] = {}

    def cerrar(self) -> None:
        if self._driver is not None:
            self._driver.quit()
            self._driver = None

    def _driver_activo(self) -> webdriver.Chrome:
        if self._driver is None:
            self._driver = _crear_driver()
        return self._driver

    def _populares_del_artista(self, artist_url: str) -> dict[str, int]:
        """Devuelve {track_id: reproducciones} de la sección "Popular" del
        artista, cacheado para no volver a cargar la página por cada canción."""
        if artist_url in self._cache_popular:
            return self._cache_popular[artist_url]

        populares: dict[str, int] = {}
        driver = self._driver_activo()
        try:
            driver.get(artist_url)
            WebDriverWait(driver, 15).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, '[data-testid="tracklist-row"]'))
            )
            for row in driver.find_elements(By.CSS_SELECTOR, '[data-testid="tracklist-row"]'):
                try:
                    link = row.find_element(By.CSS_SELECTOR, 'a[data-testid="internal-track-link"]')
                    match = TRACK_ID_EN_HREF.search(link.get_attribute("href") or "")
                except Exception:
                    continue
                if not match:
                    continue
                numero = _primer_numero_de_elementos(row.find_elements(By.CSS_SELECTOR, '[role="gridcell"]'))
                if numero:
                    populares[match.group(1)] = numero
        except Exception as e:
            print(f"   ⚠️ No se pudo leer 'Popular' del artista: {e}")

        self._cache_popular[artist_url] = populares
        return populares

    def _de_pagina_individual(self, spotify_url: str, cancion_nombre: str) -> int | None:
        driver = self._driver_activo()
        try:
            print(f"   → Accediendo a Spotify para '{cancion_nombre}'...")
            driver.get(spotify_url)
            WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.TAG_NAME, "main")))

            reproducciones = _esperar_reproducciones(driver)
            if reproducciones:
                return reproducciones

            for metodo in (_buscar_en_elementos_de_estadisticas, _buscar_por_contexto_en_page_source, _ultimo_intento):
                reproducciones = metodo(driver)
                if reproducciones:
                    return reproducciones
            return None
        except Exception as e:
            print(f"   ❌ Error: {e}")
            return None

    def obtener(self, track_id: str, spotify_url: str, artist_url: str, cancion_nombre: str) -> tuple[int | None, str]:
        """Busca primero en el "Popular" del artista (rápido, por ID exacto) y
        recién si no está ahí, scrapea la página individual del track."""
        populares = self._populares_del_artista(artist_url)
        if track_id in populares:
            reproducciones = populares[track_id]
            print(f"   ✅ {reproducciones:,} reproducciones para '{cancion_nombre}' ({METODO_POPULAR})")
            return reproducciones, METODO_POPULAR

        reproducciones = self._de_pagina_individual(spotify_url, cancion_nombre)
        if reproducciones:
            print(f"   ✅ {reproducciones:,} reproducciones para '{cancion_nombre}' ({METODO_PAGINA_INDIVIDUAL})")
            return reproducciones, METODO_PAGINA_INDIVIDUAL

        print(f"   ❌ No se encontraron reproducciones para '{cancion_nombre}'")
        return None, METODO_NO_ENCONTRADO
