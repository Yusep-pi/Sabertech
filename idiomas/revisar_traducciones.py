#!/usr/bin/env python3
"""Revisa la traducción al inglés (idiomas/en.po).

Junta los textos traducibles del juego:
  - en los .gd: los literales dentro de tr("...") y TranslationServer.translate("...");
  - en data/datos.json: todos los textos, salvo ids/referencias y comentarios ("_..."),
    con la misma regla que GameState._traducir_datos().
y lista los que faltan en en.po (o tienen msgstr vacío) y los que sobran.

Uso, desde la carpeta del proyecto:
    python3 idiomas/revisar_traducciones.py
Sale con código 1 si falta alguno.
"""
import json
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
PO = RAIZ / "idiomas" / "en.po"
# Igual que GameState.CLAVES_SIN_TRADUCIR y su regla de ids.
CLAVES_SIN_TRADUCIR = {"id", "categoria", "nave_por_defecto", "tipo", "destino",
                       "romper", "reparar", "evitable_con", "objetivo_id", "requiere", "pieza"}
# Valores con forma de id ("panel_grande") no se traducen nunca.
FORMA_DE_ID = re.compile(r"[a-z0-9_]+")
CARPETAS_IGNORADAS = {"tests", ".godot", "blender", "capturas", "build"}
LITERAL = r'"((?:[^"\\]|\\.)*)"'
LLAMADA = re.compile(r'(?<![\w.])(?:tr|TranslationServer\.translate)\(\s*' + LITERAL + r'\s*[,)]')


ESCAPES = {"n": "\n", "t": "\t", '"': '"', "\\": "\\"}


def desescapar(texto):
    """Interpreta los escapes de GDScript y de .po (\\n, \\t, \\", \\\\)."""
    return re.sub(r'\\(.)', lambda m: ESCAPES.get(m.group(1), m.group(0)), texto)


def textos_codigo():
    textos = {}
    for archivo in sorted(RAIZ.rglob("*.gd")):
        relativo = archivo.relative_to(RAIZ)
        if relativo.parts[0] in CARPETAS_IGNORADAS:
            continue
        for numero, linea in enumerate(archivo.read_text(encoding="utf-8").splitlines(), 1):
            for encontrado in LLAMADA.finditer(linea):
                texto = desescapar(encontrado.group(1))
                textos.setdefault(texto, f"{relativo}:{numero}")
    return textos


def literales_codigo():
    """Todos los literales de los .gd: los textos que se traducen desde constantes
    (tr(NOMBRES[x])) no se ven en tr("..."), pero están escritos en el código."""
    literales = set()
    for archivo in RAIZ.rglob("*.gd"):
        if archivo.relative_to(RAIZ).parts[0] in CARPETAS_IGNORADAS:
            continue
        literales.update(desescapar(t) for t in re.findall(LITERAL, archivo.read_text(encoding="utf-8")))
    return literales


def textos_datos():
    textos = {}

    def recorrer(valor, clave, ruta):
        if clave.startswith("_") or clave in CLAVES_SIN_TRADUCIR:
            return
        if isinstance(valor, dict):
            for k, v in valor.items():
                recorrer(v, k, f"{ruta}/{k}")
        elif isinstance(valor, list):
            for i, v in enumerate(valor):
                recorrer(v, clave, f"{ruta}[{i}]")
        elif isinstance(valor, str) and valor.strip() and not FORMA_DE_ID.fullmatch(valor):
            textos.setdefault(valor, "data/datos.json" + ruta)

    recorrer(json.loads((RAIZ / "data" / "datos.json").read_text(encoding="utf-8")), "", "")
    return textos


def leer_po():
    """Devuelve {msgid: msgstr} de un .po simple (sin plurales ni contextos)."""
    entradas, actual, campo = {}, {}, None
    for linea in PO.read_text(encoding="utf-8").splitlines() + [""]:
        linea = linea.strip()
        if linea.startswith("msgid "):
            if "msgid" in actual:
                entradas[actual["msgid"]] = actual.get("msgstr", "")
            actual, campo = {"msgid": ""}, "msgid"
            linea = linea[6:]
        elif linea.startswith("msgstr "):
            campo = "msgstr"
            actual["msgstr"] = ""
            linea = linea[7:]
        elif not linea.startswith('"'):
            continue
        actual[campo] += desescapar(linea[1:-1])
    if "msgid" in actual:
        entradas[actual["msgid"]] = actual.get("msgstr", "")
    entradas.pop("", None)
    return entradas


def main():
    textos = {**textos_datos(), **textos_codigo()}
    po = leer_po()
    faltan = {t: lugar for t, lugar in textos.items() if not po.get(t)}
    literales = literales_codigo()
    sobran = [t for t in po if t not in textos and t not in literales]
    print(f"Textos traducibles: {len(textos)} · en en.po: {len(po)}")
    if faltan:
        print(f"\nFaltan traducir ({len(faltan)}):")
        for texto, lugar in sorted(faltan.items(), key=lambda par: par[1]):
            print(f"  {lugar}: {texto!r}")
    if sobran:
        print(f"\nEn en.po pero ya no se usan ({len(sobran)}) (se pueden borrar):")
        for texto in sobran:
            print(f"  {texto!r}")
    if not faltan:
        print("\nTODO TRADUCIDO")
    return 1 if faltan else 0


if __name__ == "__main__":
    sys.exit(main())
