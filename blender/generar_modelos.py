"""Genera los modelos 3D provisorios del juego y los exporta a assets/modelos.

Low-poly con colores planos (sin texturas todavía). Correr desde la carpeta del proyecto:

    blender --background --factory-startup --python blender/generar_modelos.py

Además guarda blender/sabertech.blend con todo separado para poder mirarlo y
retocarlo a mano, y renders de revisión en blender/previews.

Convención: en Blender el frente de cada modelo mira a +Y y arriba es +Z.
En Godot eso queda como frente -Z y arriba +Y.

Las piezas de la nave son empties con el mismo nombre que su id en
data/datos.json: el juego las prende y apaga por nombre. Los objetos cuyo
nombre termina en "-col" reciben colisión al importarse en Godot.
"""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIDA = os.path.join(RAIZ, "assets", "modelos")
PREVIEWS = os.path.join(RAIZ, "blender", "previews")

COLORES = {
	"casco": "#DDE4EA",
	"casco_gris": "#9AA7B8",
	"aqua": "#2EC4E6",
	"cian": "#8FE3FF",
	"lima": "#8EDB4F",
	"naranja": "#FF8A2B",
	"oscuro": "#2A3150",
	"negro": "#14182B",
	"celda": "#2B4FB8",
	"dorado": "#D8B04A",
	"concreto": "#8C8F99",
	"suelo": "#5E6B57",
	"piso": "#3A4466",
	"pared": "#C9D3DD",
	"pantalla": "#0B1030",
	"vidrio": "#8FE3FF",
}
EMISIVOS = {"cian": 1.0, "pantalla": 0.6, "aqua": 0.0}

_materiales = {}


# --- Utilidades -------------------------------------------------------------

def hex_a_lineal(hexa):
	hexa = hexa.lstrip("#")
	srgb = [int(hexa[i:i + 2], 16) / 255 for i in (0, 2, 4)]
	return [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]


def material(nombre, emision=0.0):
	clave = (nombre, emision)
	if clave in _materiales:
		return _materiales[clave]
	color = hex_a_lineal(COLORES[nombre])
	m = bpy.data.materials.new(nombre + ("_luz" if emision else ""))
	m.diffuse_color = (*color, 1.0)
	bsdf = m.node_tree.nodes.get("Principled BSDF")
	if bsdf:
		bsdf.inputs["Base Color"].default_value = (*color, 1.0)
		bsdf.inputs["Roughness"].default_value = 0.8
		if emision:
			bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
			bsdf.inputs["Emission Strength"].default_value = emision
	_materiales[clave] = m
	return m


def mat(nombre):
	return material(nombre, EMISIVOS.get(nombre, 0.0))


def _objeto(nombre, malla, pos, rot, color, padre):
	malla.materials.append(mat(color))
	obj = bpy.data.objects.new(nombre, malla)
	obj.location = pos
	obj.rotation_euler = [math.radians(a) for a in rot]
	bpy.context.scene.collection.objects.link(obj)
	obj.parent = padre
	return obj


def _malla(nombre, construir):
	malla = bpy.data.meshes.new(nombre)
	bm = bmesh.new()
	construir(bm)
	bm.to_mesh(malla)
	bm.free()
	return malla


def vacio(nombre, padre=None, pos=(0, 0, 0)):
	obj = bpy.data.objects.new(nombre, None)
	obj.empty_display_size = 0.5
	obj.location = pos
	bpy.context.scene.collection.objects.link(obj)
	obj.parent = padre
	return obj


def caja(nombre, tam, pos, color, padre, rot=(0, 0, 0)):
	escala = Matrix.Diagonal((*tam, 1.0))
	malla = _malla(nombre, lambda bm: bmesh.ops.create_cube(bm, size=1.0, matrix=escala))
	return _objeto(nombre, malla, pos, rot, color, padre)


def cilindro(nombre, radio_abajo, radio_arriba, alto, pos, color, padre, rot=(0, 0, 0), lados=8):
	def construir(bm):
		bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=lados,
			radius1=radio_abajo, radius2=radio_arriba, depth=alto)
	return _objeto(nombre, _malla(nombre, construir), pos, rot, color, padre)


def esfera(nombre, radio, pos, color, padre, segmentos=8, anillos=6):
	def construir(bm):
		bmesh.ops.create_uvsphere(bm, u_segments=segmentos, v_segments=anillos, radius=radio)
	return _objeto(nombre, _malla(nombre, construir), pos, (0, 0, 0), color, padre)


def descendientes(obj):
	lista = [obj]
	for hijo in obj.children:
		lista.extend(descendientes(hijo))
	return lista


def exportar(raices, archivo):
	bpy.ops.object.select_all(action="DESELECT")
	for raiz in raices:
		for obj in descendientes(raiz):
			obj.select_set(True)
	bpy.ops.export_scene.gltf(
		filepath=os.path.join(SALIDA, archivo),
		export_format="GLB",
		use_selection=True,
		export_yup=True,
		export_apply=True,
		export_lights=False,
		export_cameras=False,
	)


# --- Nave modular -----------------------------------------------------------

def construir_nave():
	"""Módulo tripulado con piezas intercambiables. Frente (ventana e instrumentos) en +Y."""
	raiz = vacio("nave")

	base = vacio("nave_base", raiz)
	cilindro("nave_base_modulo", 1.2, 1.2, 2.4, (0, 0, 0), "casco", base)
	cilindro("nave_base_capsula", 1.2, 0.5, 1.3, (0, 0, 1.85), "casco", base)
	cilindro("nave_base_tapa", 0.5, 0.35, 0.2, (0, 0, 2.6), "casco_gris", base)
	cilindro("nave_base_franja", 1.23, 1.23, 0.18, (0, 0, 0.95), "aqua", base)
	cilindro("nave_base_aro", 1.23, 1.23, 0.12, (0, 0, -1.1), "casco_gris", base)
	caja("nave_base_ventana", (0.9, 0.08, 0.35), (0, 0.92, 1.9), "pantalla", base, rot=(-35, 0, 0))
	caja("nave_base_escotilla", (0.7, 0.06, 0.9), (1.15, 0, 0.1), "casco_gris", base, rot=(0, 0, 90))

	panel = vacio("panel_chico", raiz)
	for lado, signo in (("izq", -1), ("der", 1)):
		caja(f"panel_chico_brazo_{lado}", (0.4, 0.1, 0.1), (signo * 1.35, 0, 0), "casco_gris", panel)
		caja(f"panel_chico_{lado}", (2.0, 1.0, 0.06), (signo * 2.55, 0, 0), "celda", panel)

	panel = vacio("panel_grande", raiz)
	for lado, signo in (("izq", -1), ("der", 1)):
		caja(f"panel_grande_brazo_{lado}", (0.5, 0.12, 0.12), (signo * 1.4, 0, 0), "casco_gris", panel)
		for i in range(2):
			caja(f"panel_grande_{lado}_{i}", (1.9, 1.4, 0.06), (signo * (2.65 + i * 2.0), 0, 0), "celda", panel)

	rtg = vacio("rtg", raiz)
	caja("rtg_brazo", (0.12, 1.2, 0.12), (0, -1.75, -0.7), "casco_gris", rtg)
	cilindro("rtg_generador", 0.28, 0.28, 1.1, (0, -2.5, -0.7), "oscuro", rtg, rot=(90, 0, 0))
	for i in range(4):
		angulo = i * 90
		x = math.cos(math.radians(angulo)) * 0.4
		z = math.sin(math.radians(angulo)) * 0.4
		caja(f"rtg_aleta_{i}", (0.06 if i % 2 == 0 else 0.5, 1.0, 0.5 if i % 2 == 0 else 0.06),
			(x, -2.5, -0.7 + z), "casco_gris", rtg)

	antena = vacio("antena_baja", raiz)
	cilindro("antena_baja_varilla", 0.03, 0.02, 1.4, (0.6, -1.0, 1.4), "casco", antena)

	antena = vacio("antena_media", raiz)
	caja("antena_media_mastil", (0.1, 0.7, 0.1), (0, -1.5, 0.6), "casco_gris", antena)
	cilindro("antena_media_plato", 0.15, 0.65, 0.25, (0, -1.95, 0.75), "casco", antena, rot=(-110, 0, 0), lados=10)

	antena = vacio("antena_alta", raiz)
	caja("antena_alta_mastil", (0.12, 0.9, 0.12), (0, -1.6, 0.7), "casco_gris", antena)
	cilindro("antena_alta_plato", 0.2, 1.15, 0.35, (0, -2.2, 0.95), "casco", antena, rot=(-110, 0, 0), lados=12)
	cilindro("antena_alta_receptor", 0.04, 0.04, 0.7, (0, -2.55, 1.05), "casco_gris", antena, rot=(-110, 0, 0))

	motor = vacio("motor_quimico", raiz)
	cilindro("motor_quimico_tobera", 0.75, 0.3, 0.9, (0, 0, -1.65), "oscuro", motor)

	motor = vacio("motor_eficiente", raiz)
	cilindro("motor_eficiente_tobera", 0.9, 0.3, 1.2, (0, 0, -1.8), "oscuro", motor, lados=10)
	for i, x in enumerate((-1.0, 1.0)):
		esfera(f"motor_eficiente_tanque_{i}", 0.4, (x, -0.6, -1.0), "casco", motor)

	motor = vacio("motor_ionico", raiz)
	cilindro("motor_ionico_base", 1.0, 1.0, 0.15, (0, 0, -1.28), "oscuro", motor)
	for i, (x, y) in enumerate(((-0.45, 0), (0.45, 0), (0, 0.5), (0, -0.5))):
		cilindro(f"motor_ionico_rejilla_{i}", 0.3, 0.3, 0.12, (x, y, -1.42), "cian", motor)

	camara = vacio("camara", raiz)
	caja("camara_cuerpo", (0.35, 0.35, 0.35), (-0.45, 1.25, -0.5), "oscuro", camara)
	cilindro("camara_lente", 0.15, 0.15, 0.3, (-0.45, 1.5, -0.5), "negro", camara, rot=(-90, 0, 0))

	espectro = vacio("espectrometro", raiz)
	caja("espectrometro_caja", (0.5, 0.4, 0.4), (0.45, 1.3, -0.5), "lima", espectro)
	cilindro("espectrometro_tubo", 0.08, 0.08, 0.3, (0.45, 1.6, -0.4), "negro", espectro, rot=(-90, 0, 0))

	radar = vacio("radar", raiz)
	caja("radar_brazo", (0.1, 0.5, 0.1), (0, -1.4, -0.7), "casco_gris", radar)
	caja("radar_antena", (3.2, 0.12, 0.8), (0, -1.7, -0.7), "oscuro", radar)
	for i in range(5):
		caja(f"radar_franja_{i}", (0.05, 0.14, 0.8), (-1.2 + i * 0.6, -1.7, -0.7), "aqua", radar)

	respaldo = vacio("redundancia", raiz)
	caja("redundancia_modulo", (0.5, 0.6, 0.7), (-1.3, 0.3, -0.4), "cian", respaldo)
	caja("redundancia_caja", (0.45, 0.5, 0.5), (1.3, 0.3, -0.4), "cian", respaldo)

	blindaje = vacio("blindaje", raiz)
	cilindro("blindaje_lamina", 1.27, 1.27, 1.7, (0, 0, -0.1), "dorado", blindaje)
	return raiz


# --- Cohetes ----------------------------------------------------------------

def construir_cohete(id_cohete, radio, alto, aletas, propulsores=False):
	"""Cohete parado sobre z=0. El empty <id>_carga marca dónde va el origen de la nave."""
	raiz = vacio(id_cohete)
	cilindro(f"{id_cohete}_cuerpo", radio, radio, alto, (0, 0, alto / 2), "casco", raiz, lados=10)
	cilindro(f"{id_cohete}_franja_baja", radio + 0.02, radio + 0.02, 1.2, (0, 0, 2.0), "oscuro", raiz, lados=10)
	cilindro(f"{id_cohete}_franja_alta", radio + 0.02, radio + 0.02, 0.5, (0, 0, alto * 0.62), "aqua", raiz, lados=10)
	cilindro(f"{id_cohete}_adaptador", radio, 1.25, 1.6, (0, 0, alto + 0.8), "casco_gris", raiz, lados=10)
	cilindro(f"{id_cohete}_tobera", radio * 0.8, radio * 0.45, 1.2, (0, 0, -0.4), "oscuro", raiz, lados=10)
	if aletas:
		for i in range(4):
			angulo = math.radians(45 + i * 90)
			caja(f"{id_cohete}_aleta_{i}", (0.15, 1.4, 2.4),
				(math.cos(angulo) * (radio + 0.6), math.sin(angulo) * (radio + 0.6), 1.4),
				"oscuro", raiz, rot=(0, 0, math.degrees(angulo) + 90))
	if propulsores:
		for i, x in enumerate((-(radio + 1.2), radio + 1.2)):
			alto_p = alto * 0.65
			cilindro(f"{id_cohete}_propulsor_{i}", 1.0, 1.0, alto_p, (x, 0, alto_p / 2), "casco", raiz)
			cilindro(f"{id_cohete}_propulsor_punta_{i}", 1.0, 0.1, 2.0, (x, 0, alto_p + 1.0), "casco", raiz)
			cilindro(f"{id_cohete}_propulsor_tobera_{i}", 0.8, 0.5, 1.0, (x, 0, -0.3), "oscuro", raiz)
			cilindro(f"{id_cohete}_propulsor_franja_{i}", 1.02, 1.02, 0.8, (x, 0, alto_p * 0.5), "naranja", raiz)
	# La tobera de la nave mide ~2.1 m bajo su origen: queda dentro del adaptador.
	vacio(f"{id_cohete}_carga", raiz, (0, 0, alto + 1.6 + 1.5))
	return raiz


# --- Plataforma de lanzamiento ----------------------------------------------

def construir_plataforma():
	raiz = vacio("plataforma")
	caja("plataforma_suelo", (600, 600, 0.2), (0, 0, -1.1), "suelo", raiz)
	caja("plataforma_base", (26, 26, 1.0), (0, 0, -0.5), "concreto", raiz)
	caja("plataforma_foso", (6, 26.2, 1.02), (0, 0, -0.5), "negro", raiz)
	caja("plataforma_rampa", (26, 10, 1.0), (0, -18, -0.9), "concreto", raiz, rot=(4, 0, 0))

	# Torre de servicio a un costado del cohete.
	x = -8.0
	for i, (dx, dy) in enumerate(((-1.2, -1.2), (1.2, -1.2), (-1.2, 1.2), (1.2, 1.2))):
		caja(f"torre_columna_{i}", (0.35, 0.35, 36), (x + dx, dy, 18), "oscuro", raiz)
	for nivel in range(12):
		z = 2 + nivel * 3
		caja(f"torre_viga_x_{nivel}", (2.8, 0.25, 0.25), (x, -1.2, z), "casco_gris", raiz)
		caja(f"torre_viga_x2_{nivel}", (2.8, 0.25, 0.25), (x, 1.2, z), "casco_gris", raiz)
		caja(f"torre_viga_y_{nivel}", (0.25, 2.8, 0.25), (x - 1.2, 0, z), "casco_gris", raiz)
		caja(f"torre_viga_y2_{nivel}", (0.25, 2.8, 0.25), (x + 1.2, 0, z), "casco_gris", raiz)
		caja(f"torre_diagonal_{nivel}", (0.18, 0.18, 3.6), (x - 1.2, 0, z + 1.5), "casco_gris", raiz, rot=(48 if nivel % 2 else -48, 0, 0))
	caja("torre_techo", (3.4, 3.4, 0.4), (x, 0, 36.2), "oscuro", raiz)
	cilindro("torre_pararrayos", 0.08, 0.02, 6, (x, 0, 39.4), "casco_gris", raiz)
	esfera("torre_luz", 0.25, (x, 0, 42.4), "naranja", raiz)
	for i, z in enumerate((14, 24, 30)):
		caja(f"torre_brazo_{i}", (5.2, 0.8, 0.5), (x + 3.6, 0, z), "naranja" if i == 1 else "casco_gris", raiz)

	# Tanques y edificios alrededor, para dar escala.
	for i, (px, py) in enumerate(((34, 26), (42, 18), (-36, 30))):
		esfera(f"tanque_{i}", 4.0, (px, py, 3.0), "casco", raiz, segmentos=10, anillos=7)
		caja(f"tanque_base_{i}", (5, 5, 1), (px, py, -0.5), "concreto", raiz)
	caja("edificio_control", (14, 8, 5), (-40, -40, 2.5), "pared", raiz)
	caja("edificio_franja", (14.1, 8.1, 0.6), (-40, -40, 4.0), "aqua", raiz)
	caja("hangar", (24, 18, 14), (50, -50, 7), "casco_gris", raiz)
	caja("hangar_puerta", (12, 0.2, 11), (50, -40.9, 5.5), "oscuro", raiz)
	for i, (px, py) in enumerate(((13, 13), (-13, 13), (13, -13), (-13, -13))):
		cilindro(f"poste_{i}", 0.15, 0.12, 12, (px, py, 6), "casco_gris", raiz)
		esfera(f"poste_luz_{i}", 0.4, (px, py, 12.2), "cian", raiz)
	return raiz


# --- Cabina en primera persona ----------------------------------------------

def construir_cabina():
	"""Interior de la nave: 6 x 8 x 3 m. Ventanal al frente (+Y)."""
	raiz = vacio("cabina")

	estructura = vacio("cabina_estructura", raiz)
	caja("piso-col", (6.4, 8.4, 0.2), (0, 0, -0.1), "piso", estructura)
	for i in range(7):
		caja(f"piso_franja_{i}", (5.8, 0.04, 0.01), (0, -3.5 + i * 1.15, 0.005), "oscuro", estructura)
	caja("techo-col", (6.4, 8.4, 0.2), (0, 0, 3.1), "pared", estructura)
	caja("pared_izq-col", (0.2, 8.4, 3.2), (-3.1, 0, 1.5), "pared", estructura)
	caja("pared_der-col", (0.2, 8.4, 3.2), (3.1, 0, 1.5), "pared", estructura)
	caja("pared_tras-col", (6.4, 0.2, 3.2), (0, -4.1, 1.5), "pared", estructura)
	caja("pared_frente_baja-col", (6.4, 0.2, 1.0), (0, 4.1, 0.5), "pared", estructura)
	caja("pared_frente_alta-col", (6.4, 0.2, 0.55), (0, 4.1, 2.82), "pared", estructura)
	for i, x in enumerate((-2.95, -1.0, 1.0, 2.95)):
		caja(f"ventana_marco_{i}", (0.16, 0.3, 1.6), (x, 4.05, 1.8), "oscuro", estructura)
	caja("ventana_marco_bajo", (6.0, 0.3, 0.1), (0, 4.05, 1.0), "oscuro", estructura)
	caja("ventana_marco_alto", (6.0, 0.3, 0.1), (0, 4.05, 2.55), "oscuro", estructura)
	caja("ventana_vidrio", (6.0, 0.02, 1.6), (0, 4.12, 1.8), "vidrio", estructura)

	# Puerta trasera, luces, guardas y caños.
	caja("puerta", (1.3, 0.06, 2.3), (0, -3.98, 1.15), "casco_gris", estructura)
	caja("puerta_franja", (1.32, 0.07, 0.12), (0, -3.97, 1.4), "aqua", estructura)
	for i, x in enumerate((-1.4, 1.4)):
		caja(f"luz_techo_{i}", (0.25, 6.5, 0.05), (x, 0, 2.98), "cian", estructura)
	for i, x in enumerate((-2.99, 2.99)):
		caja(f"guarda_{i}", (0.04, 8.0, 0.1), (x, 0, 1.15), "aqua", estructura)
		cilindro(f"cano_{i}", 0.06, 0.06, 8.0, (x * 0.97, 0, 2.6), "casco_gris", estructura, rot=(90, 0, 0))
		cilindro(f"cano_bajo_{i}", 0.04, 0.04, 8.0, (x * 0.97, 0, 2.45), "oscuro", estructura, rot=(90, 0, 0))
	for i, (x, nombre) in enumerate(((-2.4, "izq"), (2.4, "der"))):
		caja(f"casillero_{nombre}-col", (1.0, 0.6, 2.2), (x, -3.65, 1.1), "casco_gris", estructura)
		caja(f"casillero_{nombre}_linea", (0.03, 0.62, 2.0), (x, -3.65, 1.1), "oscuro", estructura)

	asiento = vacio("asiento", raiz)
	caja("asiento_base-col", (0.8, 0.8, 0.5), (0, 1.9, 0.25), "oscuro", asiento)
	caja("asiento_cojin", (0.7, 0.7, 0.12), (0, 1.9, 0.56), "aqua", asiento)
	caja("asiento_respaldo", (0.7, 0.14, 0.65), (0, 1.52, 0.9), "aqua", asiento, rot=(-12, 0, 0))
	for i, x in enumerate((-0.42, 0.42)):
		caja(f"asiento_apoyabrazos_{i}", (0.1, 0.6, 0.1), (x, 1.85, 0.8), "oscuro", asiento)

	# Consolas: cada una tiene su pantalla, que el juego usa para mostrar datos.
	consola = vacio("consola_principal", raiz)
	caja("consola_principal_mesa-col", (4.2, 0.9, 1.0), (0, 3.45, 0.5), "oscuro", consola)
	caja("consola_principal_tablero", (4.0, 0.7, 0.06), (0, 3.3, 1.03), "casco_gris", consola, rot=(-12, 0, 0))
	caja("pantalla_principal", (1.6, 0.05, 0.6), (0, 3.75, 1.35), "pantalla", consola, rot=(-15, 0, 0))
	caja("pantalla_principal_marco", (1.7, 0.04, 0.7), (0, 3.78, 1.35), "aqua", consola, rot=(-15, 0, 0))
	for i, x in enumerate((-1.6, -1.2, 1.2, 1.6)):
		caja(f"consola_principal_boton_{i}", (0.18, 0.18, 0.05), (x, 3.25, 1.07), "lima" if i % 2 else "naranja", consola, rot=(-12, 0, 0))

	for id_consola, x, y, giro in (
		("consola_energia", -2.5, 0.6, 90),
		("consola_comunicaciones", 2.5, 0.6, -90),
		("consola_ciencia", 2.5, -1.9, -90),
	):
		consola = vacio(id_consola, raiz)
		signo = -1 if x < 0 else 1
		caja(f"{id_consola}_mesa-col", (0.9, 1.8, 1.0), (x, y, 0.5), "oscuro", consola)
		caja(f"{id_consola}_tablero", (0.7, 1.7, 0.06), (x, y, 1.03), "casco_gris", consola)
		nombre_pantalla = id_consola.replace("consola_", "pantalla_")
		caja(nombre_pantalla, (0.05, 1.3, 0.7), (signo * 2.92, y, 1.6), "pantalla", consola)
		caja(f"{nombre_pantalla}_marco", (0.04, 1.4, 0.8), (signo * 2.95, y, 1.6), "aqua", consola)
		for i in range(3):
			caja(f"{id_consola}_boton_{i}", (0.15, 0.15, 0.05), (x, y - 0.5 + i * 0.5, 1.07),
				("lima", "aqua", "naranja")[i], consola)

	# Cajas de carga del lado izquierdo, para que no quede vacío.
	carga = vacio("carga", raiz)
	for i, (px, py, pz, t) in enumerate(((-2.5, -1.9, 0.35, 0.7), (-2.5, -2.7, 0.3, 0.6), (-2.45, -2.3, 0.95, 0.5))):
		caja(f"caja_carga_{i}-col", (t, t, t), (px, py, pz), "casco_gris" if i % 2 else "lima", carga)
	return raiz


# --- Revisión ---------------------------------------------------------------

def construir_esclusa():
	"""Esclusa de 5 x 6 x 3 m: ventanal a la izquierda (-X), escotilla al frente (+Y),
	armario con el traje a la derecha (+X) y la puerta a la cabina atrás (-Y)."""
	raiz = vacio("esclusa")
	e = vacio("esclusa_estructura", raiz)
	caja("esclusa_piso-col", (5.4, 6.4, 0.2), (0, 0, -0.1), "piso", e)
	for i in range(5):
		caja(f"esclusa_piso_franja_{i}", (5.0, 0.04, 0.01), (0, -2.4 + i * 1.1, 0.005), "oscuro", e)
	caja("esclusa_techo-col", (5.4, 6.4, 0.2), (0, 0, 3.1), "pared", e)
	caja("esclusa_pared_der-col", (0.2, 6.4, 3.2), (2.6, 0, 1.5), "pared", e)
	caja("esclusa_pared_tras-col", (5.4, 0.2, 3.2), (0, -3.1, 1.5), "pared", e)

	# Pared izquierda con el ventanal: base, dintel, columnas y vidrio.
	caja("esclusa_pared_izq_baja-col", (0.2, 6.4, 0.9), (-2.6, 0, 0.45), "pared", e)
	caja("esclusa_pared_izq_alta-col", (0.2, 6.4, 0.65), (-2.6, 0, 2.88), "pared", e)
	caja("esclusa_pared_izq_fondo-col", (0.2, 1.1, 1.7), (-2.6, -2.65, 1.7), "pared", e)
	caja("esclusa_pared_izq_frente-col", (0.2, 1.1, 1.7), (-2.6, 2.65, 1.7), "pared", e)
	for i, y in enumerate((-2.1, -0.7, 0.7, 2.1)):
		caja(f"esclusa_ventanal_marco_{i}", (0.3, 0.14, 1.66), (-2.55, y, 1.72), "oscuro", e)
	caja("esclusa_ventanal_marco_bajo", (0.3, 4.3, 0.12), (-2.55, 0, 0.92), "oscuro", e)
	caja("esclusa_ventanal_marco_alto", (0.3, 4.3, 0.12), (-2.55, 0, 2.52), "oscuro", e)
	caja("esclusa_vidrio", (0.02, 4.2, 1.6), (-2.66, 0, 1.72), "vidrio", e)

	# Pared del frente con el hueco de la escotilla (1.6 x 2.0 m).
	caja("esclusa_pared_frente_izq-col", (1.8, 0.2, 3.2), (-1.7, 3.1, 1.5), "pared", e)
	caja("esclusa_pared_frente_der-col", (1.8, 0.2, 3.2), (1.7, 3.1, 1.5), "pared", e)
	caja("esclusa_pared_frente_alta-col", (1.6, 0.2, 1.0), (0, 3.1, 2.7), "pared", e)
	caja("esclusa_pared_frente_umbral-col", (1.6, 0.2, 0.2), (0, 3.1, 0.1), "pared", e)
	# Marco con franjas de peligro.
	for i in range(8):
		color = "naranja" if i % 2 == 0 else "negro"
		caja(f"esclusa_marco_izq_{i}", (0.16, 0.3, 0.26), (-0.88, 3.0, 0.33 + i * 0.26), color, e)
		caja(f"esclusa_marco_der_{i}", (0.16, 0.3, 0.26), (0.88, 3.0, 0.33 + i * 0.26), color, e)
	caja("esclusa_marco_arriba", (1.92, 0.3, 0.16), (0, 3.0, 2.28), "oscuro", e)
	for i in range(6):
		caja(f"esclusa_piso_peligro_{i}", (0.3, 0.6, 0.01), (-0.75 + i * 0.3, 2.6, 0.006), "naranja" if i % 2 == 0 else "negro", e)

	# La hoja de la escotilla: se desliza hacia la derecha al abrir.
	# El nodo queda en el origen: sus piezas ya tienen la posición final y el juego lo desplaza entero.
	puerta = vacio("escotilla_puerta", raiz)
	caja("escotilla_hoja-col", (1.6, 0.12, 2.0), (0, 3.12, 1.2), "casco_gris", puerta)
	cilindro("escotilla_mirilla", 0.22, 0.22, 0.14, (0, 3.08, 1.65), "pantalla", puerta, rot=(90, 0, 0), lados=12)
	cilindro("escotilla_volante", 0.3, 0.3, 0.06, (0, 3.03, 1.0), "oscuro", puerta, rot=(90, 0, 0), lados=12)
	caja("escotilla_franja", (1.6, 0.13, 0.12), (0, 3.11, 0.5), "naranja", puerta)

	baliza = vacio("baliza", raiz)
	cilindro("baliza_base", 0.14, 0.14, 0.08, (0, 2.95, 2.62), "oscuro", baliza)
	cilindro("baliza_luz", 0.1, 0.08, 0.16, (0, 2.95, 2.74), "naranja", baliza)

	# Panel de la escotilla, a la derecha del hueco.
	panel = vacio("consola_escotilla", raiz)
	caja("consola_escotilla_caja", (0.6, 0.15, 0.85), (1.45, 2.92, 1.35), "oscuro", panel)
	caja("pantalla_escotilla", (0.48, 0.02, 0.36), (1.45, 2.84, 1.52), "pantalla", panel)
	caja("consola_escotilla_boton", (0.16, 0.06, 0.16), (1.33, 2.84, 1.1), "naranja", panel)
	caja("consola_escotilla_boton_2", (0.16, 0.06, 0.16), (1.57, 2.84, 1.1), "lima", panel)

	# Puerta interior, hacia la cabina.
	interior = vacio("consola_puerta", raiz)
	caja("consola_puerta_hoja-col", (1.3, 0.1, 2.3), (0, -2.98, 1.15), "casco_gris", interior)
	caja("consola_puerta_franja", (1.32, 0.11, 0.12), (0, -2.97, 1.4), "aqua", interior)

	# Armario abierto con el traje colgando, mirando hacia la sala (-X).
	armario = vacio("consola_armario", raiz)
	x, y = 2.15, 1.0
	caja("consola_armario_fondo-col", (0.08, 1.4, 2.4), (x + 0.3, y, 1.2), "oscuro", armario)
	caja("consola_armario_lado_a-col", (0.7, 0.08, 2.4), (x, y - 0.7, 1.2), "casco_gris", armario)
	caja("consola_armario_lado_b-col", (0.7, 0.08, 2.4), (x, y + 0.7, 1.2), "casco_gris", armario)
	caja("consola_armario_techo", (0.7, 1.48, 0.08), (x, y, 2.4), "casco_gris", armario)
	caja("consola_armario_base", (0.7, 1.48, 0.12), (x, y, 0.06), "casco_gris", armario)
	cilindro("consola_armario_barra", 0.03, 0.03, 1.3, (x, y, 2.2), "casco_gris", armario, rot=(90, 0, 0))
	caja("consola_armario_luz", (0.05, 1.2, 0.04), (x + 0.25, y, 2.32), "cian", armario)

	traje = vacio("traje", armario)
	tx = x - 0.05
	caja("traje_gancho", (0.03, 0.03, 0.2), (tx, y, 2.1), "casco_gris", traje)
	esfera("traje_casco", 0.21, (tx, y, 1.82), "casco", traje, segmentos=10, anillos=7)
	caja("traje_visor", (0.06, 0.26, 0.16), (tx - 0.19, y, 1.83), "dorado", traje)
	caja("traje_cuello", (0.26, 0.3, 0.08), (tx, y, 1.6), "aqua", traje)
	caja("traje_torso", (0.3, 0.48, 0.58), (tx, y, 1.28), "casco", traje)
	caja("traje_panel_pecho", (0.04, 0.22, 0.16), (tx - 0.16, y, 1.38), "oscuro", traje)
	caja("traje_mochila", (0.22, 0.44, 0.56), (tx + 0.25, y, 1.3), "casco_gris", traje)
	for i, lado in enumerate((-1, 1)):
		cilindro(f"traje_brazo_{i}", 0.07, 0.08, 0.6, (tx, y + lado * 0.32, 1.22), "casco", traje, rot=(lado * 8, 0, 0))
		esfera(f"traje_guante_{i}", 0.07, (tx, y + lado * 0.36, 0.9), "aqua", traje)
		cilindro(f"traje_pierna_{i}", 0.09, 0.1, 0.62, (tx, y + lado * 0.12, 0.68), "casco", traje)
		caja(f"traje_bota_{i}", (0.24, 0.13, 0.12), (tx - 0.03, y + lado * 0.12, 0.33), "casco_gris", traje)
	caja("traje_cinturon", (0.32, 0.5, 0.06), (tx, y, 1.0), "aqua", traje)

	# Banco, tanques de oxígeno, pasamanos, luces y ventilación.
	caja("esclusa_banco-col", (0.5, 1.6, 0.45), (0.4, -1.4, 0.23), "aqua", e)
	for i, yy in enumerate((-2.2, -1.85, -1.5)):
		cilindro(f"esclusa_tanque_{i}", 0.13, 0.13, 1.0, (2.3, yy, 0.6), "lima" if i == 1 else "casco", e, lados=10)
		esfera(f"esclusa_tanque_tapa_{i}", 0.13, (2.3, yy, 1.1), "casco_gris", e)
	caja("esclusa_tanques_soporte", (0.06, 1.0, 0.08), (2.46, -1.85, 0.9), "oscuro", e)
	for i, xx in enumerate((-2.42, 2.42)):
		cilindro(f"esclusa_pasamanos_{i}", 0.035, 0.035, 5.6, (xx, 0, 1.05 if xx > 0 else 2.6), "naranja", e, rot=(90, 0, 0))
	for i, yy in enumerate((-1.6, 1.0)):
		caja(f"esclusa_luz_{i}", (2.6, 0.25, 0.05), (0, yy, 2.98), "cian", e)
	for i in range(4):
		caja(f"esclusa_ventilacion_{i}", (0.6, 0.06, 0.04), (0.9, 1.9 + i * 0.12, 2.99), "oscuro", e)
	return raiz


def render_revision(nombre, objetivo, distancia, altura, angulo=35):
	escena = bpy.context.scene
	escena.render.engine = "BLENDER_WORKBENCH"
	escena.display.shading.light = "STUDIO"
	escena.display.shading.color_type = "MATERIAL"
	escena.display.shading.show_shadows = False
	escena.display.shading.background_type = "VIEWPORT"
	escena.display.shading.background_color = hex_a_lineal("#0B1030")
	escena.render.resolution_x = 960
	escena.render.resolution_y = 540
	camara_datos = bpy.data.cameras.new("camara_revision")
	camara = bpy.data.objects.new("camara_revision", camara_datos)
	escena.collection.objects.link(camara)
	rad = math.radians(angulo)
	objetivo = Vector(objetivo)
	camara.location = objetivo + Vector((math.sin(rad) * distancia, math.cos(rad) * distancia, altura))
	direccion = objetivo - camara.location
	camara.rotation_euler = direccion.to_track_quat("-Z", "Y").to_euler()
	escena.camera = camara
	escena.render.filepath = os.path.join(PREVIEWS, nombre + ".png")
	bpy.ops.render.render(write_still=True)
	bpy.data.objects.remove(camara)


def mover(raiz, desplazamiento):
	raiz.location = Vector(raiz.location) + Vector(desplazamiento)


def main():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	os.makedirs(SALIDA, exist_ok=True)
	os.makedirs(PREVIEWS, exist_ok=True)

	nave = construir_nave()
	cohetes = [
		construir_cohete("cohete_chico", 1.3, 14, aletas=True),
		construir_cohete("cohete_mediano", 1.6, 22, aletas=True),
		construir_cohete("cohete_pesado", 1.8, 26, aletas=False, propulsores=True),
	]
	plataforma = construir_plataforma()
	cabina = construir_cabina()
	esclusa = construir_esclusa()

	exportar([nave], "nave.glb")
	exportar(cohetes, "cohetes.glb")
	exportar([plataforma], "plataforma.glb")
	exportar([cabina], "cabina.glb")
	exportar([esclusa], "esclusa.glb")

	# Para mirar y retocar en Blender, separamos los modelos en el espacio.
	for i, cohete in enumerate(cohetes):
		mover(cohete, (i * 8, 0, 0))
	mover(plataforma, (0, 300, 0))
	mover(cabina, (-30, 0, 0))
	mover(esclusa, (-50, 0, 0))
	mover(nave, (-12, 0, 2))

	# Con la nave sola se ven todas las piezas a la vez (en el juego se eligen de a una por categoría).
	render_revision("nave", (-12, 0, 2), 11, 4, angulo=150)
	render_revision("cohetes", (8, 0, 12), 55, 12, angulo=160)
	render_revision("cabina", (-30, 1, 1.4), 4.5, 0.2, angulo=180)
	render_revision("esclusa", (-50, 1.5, 1.3), 4.0, 0.4, angulo=200)
	render_revision("plataforma", (0, 300, 10), 70, 25, angulo=150)

	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(RAIZ, "blender", "sabertech.blend"))
	print("Modelos exportados en", SALIDA)


if __name__ == "__main__":
	main()
