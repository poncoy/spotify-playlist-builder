"""Extracción del número de reproducciones directamente de la página web de Spotify.

La API pública de Spotify no expone el contador de reproducciones de un track,
así que lo leemos con Selenium desde la página del track (mismo número que ves
en la app/web de Spotify).
"""

import random
import re
import time

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

RANGO_REPRODUCCIONES_VALIDO = (50_000, 5_000_000_000)
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
        for elemento in main_container.find_elements(By.CSS_SELECTOR, selector):
            texto = elemento.text.strip()
            if re.match(r"^\d{1,3}(?:,\d{3})+$", texto):
                numero = int(texto.replace(",", ""))
                if _es_reproduccion_valida(numero):
                    return numero
    return None


def _buscar_en_elementos_de_estadisticas(driver) -> int | None:
    stat_elements = driver.find_elements(
        By.XPATH, "//span[contains(@class, 'Type') or contains(@class, 'text')]"
    )
    for elemento in stat_elements:
        try:
            texto = elemento.text.strip()
        except Exception:
            continue
        if re.match(r"^\d{1,3}(?:,\d{3})+$", texto) and elemento.is_displayed():
            numero = int(texto.replace(",", ""))
            if _es_reproduccion_valida(numero):
                return numero
    return None


def _buscar_por_contexto_en_page_source(driver) -> int | None:
    driver.execute_script("window.scrollTo(0, 200);")
    time.sleep(2)

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
    time.sleep(5)
    elementos = driver.find_elements(By.XPATH, "//*[text()[contains(., ',')]]")
    for elemento in elementos[:10]:
        try:
            texto = elemento.text.strip()
        except Exception:
            continue
        if re.match(r"^\d{1,3}(?:,\d{3})+$", texto):
            numero = int(texto.replace(",", ""))
            if _es_reproduccion_valida(numero):
                return numero
    return None


def obtener_reproducciones(spotify_url: str, cancion_nombre: str) -> int | None:
    """Abre la página del track en Chrome headless y extrae el contador de
    reproducciones probando varias estrategias, de más a menos específica."""
    driver = _crear_driver()

    try:
        print(f"   → Accediendo a Spotify para '{cancion_nombre}'...")
        driver.get(spotify_url)
        WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.TAG_NAME, "main")))

        print("   → Esperando carga de datos...")
        time.sleep(8 + random.uniform(1, 3))

        for metodo in (
            _buscar_en_selectores_especificos,
            _buscar_en_elementos_de_estadisticas,
            _buscar_por_contexto_en_page_source,
            _ultimo_intento,
        ):
            reproducciones = metodo(driver)
            if reproducciones:
                print(f"   ✅ {reproducciones:,} reproducciones para '{cancion_nombre}' ({metodo.__name__})")
                return reproducciones

        print(f"   ❌ No se encontraron reproducciones para '{cancion_nombre}'")
        return None

    except Exception as e:
        print(f"   ❌ Error: {e}")
        return None
    finally:
        driver.quit()
