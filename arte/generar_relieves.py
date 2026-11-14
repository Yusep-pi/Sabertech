"""Genera un mapa de relieve (normal map) para cada textura de assets/texturas.

Toma el brillo de cada píxel como altura (las juntas oscuras quedan hundidas y
los paneles claros, salientes) y calcula la inclinación con los vecinos. Los
bordes se leen dando la vuelta, así el relieve también repite sin costuras.

Correr desde la carpeta del proyecto cada vez que cambie una textura:

    python3 arte/generar_relieves.py

Escribe assets/texturas/<nombre>_normal.png. El autoload Estilo los usa solos.
"""

import math
import os

from PIL import Image

CARPETA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "texturas")
## Cuánto relieve tiene cada material: más alto, más marcadas las juntas.
FUERZA = {
	"casco": 3.0, "casco_gris": 2.5, "oscuro": 2.5, "celda": 2.0, "dorado": 4.0,
	"pared": 3.5, "piso": 2.5, "concreto": 2.0, "suelo": 1.5,
}


def altura(imagen):
	ancho, alto = imagen.size
	gris = imagen.convert("L").load()
	return [[gris[x, y] / 255.0 for x in range(ancho)] for y in range(alto)], ancho, alto


def relieve(nombre, fuerza):
	ruta = os.path.join(CARPETA, nombre + ".png")
	if not os.path.exists(ruta):
		return False
	h, ancho, alto = altura(Image.open(ruta))
	salida = Image.new("RGB", (ancho, alto))
	pixeles = salida.load()
	for y in range(alto):
		for x in range(ancho):
			# Diferencias centradas, dando la vuelta en los bordes.
			du = h[y][(x + 1) % ancho] - h[y][(x - 1) % ancho]
			dv = h[(y + 1) % alto][x] - h[(y - 1) % alto][x]
			nx, ny, nz = -du * fuerza, -dv * fuerza, 1.0
			largo = math.sqrt(nx * nx + ny * ny + nz * nz)
			pixeles[x, y] = tuple(int((c / largo * 0.5 + 0.5) * 255) for c in (nx, ny, nz))
	salida.save(os.path.join(CARPETA, nombre + "_normal.png"))
	return True


if __name__ == "__main__":
	for nombre, fuerza in FUERZA.items():
		print(nombre, "ok" if relieve(nombre, fuerza) else "sin textura")
