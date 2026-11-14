extends Node
## Estado global de la partida (autoload "GameState").
##
## Única fuente de verdad: guarda la misión elegida, las piezas y los
## resultados, y calcula los 5 medidores. Las pantallas solo leen de acá y
## escuchan las señales; ninguna otra parte del juego hace cuentas.

signal mision_cambiada(mision: Dictionary)
signal seleccion_cambiada(ids: Array)
signal medidores_cambiados(medidores: Dictionary)

const RUTA_DATOS := "res://data/datos.json"
const G0 := 9.81

## Contenido completo de data/datos.json.
var datos: Dictionary = {}
## Misión elegida (vacía hasta pasar por el briefing).
var mision: Dictionary = {}
## Ids de las piezas elegidas, en el orden en que se eligieron.
var seleccion: Array[String] = []
## Los 5 medidores: costo, masa, energia, datos, delta_v.
## Cada uno es {nombre, valor, limite, unidad, mayor_es_mejor, ok}.
var medidores: Dictionary = {}
## Números intermedios útiles para las fases siguientes y el informe.
var detalle: Dictionary = {}
## Lo que pase en lanzamiento, operaciones e informe.
var resultados: Dictionary = {}

var _piezas_por_id: Dictionary = {}
var _categorias_por_id: Dictionary = {}


func _ready() -> void:
	cargar_datos()
	recalcular()


func cargar_datos(ruta: String = RUTA_DATOS) -> void:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(ruta)) != OK:
		push_error("GameState: error en %s, línea %d: %s" % [ruta, json.get_error_line(), json.get_error_message()])
		return
	datos = json.data
	_piezas_por_id.clear()
	for pieza in datos.get("piezas", []):
		_piezas_por_id[pieza["id"]] = pieza
	_categorias_por_id.clear()
	for categoria in datos.get("categorias", []):
		_categorias_por_id[categoria["id"]] = categoria


# --- Consultas de datos -----------------------------------------------------

func get_misiones() -> Array:
	return datos.get("misiones", [])


func get_mision(id: String) -> Dictionary:
	for m in get_misiones():
		if m["id"] == id:
			return m
	return {}


func get_categorias() -> Array:
	return datos.get("categorias", [])


func get_categoria(id: String) -> Dictionary:
	return _categorias_por_id.get(id, {})


func get_piezas(categoria: String = "") -> Array:
	var lista := []
	for pieza in datos.get("piezas", []):
		if categoria == "" or pieza["categoria"] == categoria:
			lista.append(pieza)
	return lista


func get_pieza(id: String) -> Dictionary:
	return _piezas_por_id.get(id, {})


# --- Selección --------------------------------------------------------------

func elegir_mision(id: String) -> void:
	var nueva := get_mision(id)
	if nueva.is_empty():
		push_error("GameState: no existe la misión '%s'" % id)
		return
	mision = nueva
	mision_cambiada.emit(mision)
	recalcular()


## En categorías de elección única reemplaza a la pieza anterior.
func elegir_pieza(id: String) -> void:
	var pieza := get_pieza(id)
	if pieza.is_empty():
		push_error("GameState: no existe la pieza '%s'" % id)
		return
	if tiene_pieza(id):
		return
	if not get_categoria(pieza["categoria"]).get("multiple", false):
		for otra in piezas_elegidas(pieza["categoria"]):
			seleccion.erase(otra["id"])
	seleccion.append(id)
	_seleccion_actualizada()


func quitar_pieza(id: String) -> void:
	if tiene_pieza(id):
		seleccion.erase(id)
		_seleccion_actualizada()


func alternar_pieza(id: String) -> void:
	if tiene_pieza(id):
		quitar_pieza(id)
	else:
		elegir_pieza(id)


func tiene_pieza(id: String) -> bool:
	return seleccion.has(id)


func piezas_elegidas(categoria: String = "") -> Array:
	var lista := []
	for id in seleccion:
		var pieza: Dictionary = _piezas_por_id[id]
		if categoria == "" or pieza["categoria"] == categoria:
			lista.append(pieza)
	return lista


## La pieza elegida en una categoría de elección única, o {} si no hay.
func pieza_elegida(categoria: String) -> Dictionary:
	var lista := piezas_elegidas(categoria)
	return lista[0] if not lista.is_empty() else {}


## Nombres de las categorías obligatorias que todavía no tienen pieza.
func categorias_faltantes() -> Array[String]:
	var faltan: Array[String] = []
	for categoria in get_categorias():
		if categoria.get("obligatoria", false) and piezas_elegidas(categoria["id"]).is_empty():
			faltan.append(categoria["nombre"])
	return faltan


## Se puede lanzar con medidores en rojo; solo hace falta misión y piezas obligatorias.
func puede_lanzar() -> bool:
	return not mision.is_empty() and categorias_faltantes().is_empty()


func reiniciar() -> void:
	mision = {}
	seleccion.clear()
	resultados.clear()
	mision_cambiada.emit(mision)
	_seleccion_actualizada()


func _seleccion_actualizada() -> void:
	seleccion_cambiada.emit(seleccion.duplicate())
	recalcular()


# --- Medidores --------------------------------------------------------------

func recalcular() -> void:
	var cohete := pieza_elegida("cohete")
	var propulsion := pieza_elegida("propulsion")

	# Todo lo que viaja en la nave: la base más las piezas, sin el cohete.
	var piezas_nave: Array = [datos.get("nave_base", {})]
	for pieza in piezas_elegidas():
		if pieza["categoria"] != "cohete":
			piezas_nave.append(pieza)

	var costo: float = cohete.get("costo", 0.0)
	var masa_seca := 0.0
	var consumo: float = mision.get("calefaccion", 0.0)
	var datos_generados := 0.0
	var fiabilidad_nave := 1.0
	var reduccion_fallo := 1.0
	for pieza in piezas_nave:
		costo += pieza.get("costo", 0.0)
		masa_seca += pieza.get("masa", 0.0)
		consumo += pieza.get("consumo", 0.0)
		datos_generados += pieza.get("datos", 0.0)
		fiabilidad_nave *= pieza.get("fiabilidad", 1.0)
		reduccion_fallo *= pieza.get("reduccion_fallo", 1.0)
	fiabilidad_nave = 1.0 - (1.0 - fiabilidad_nave) * reduccion_fallo

	var combustible: float = propulsion.get("combustible", 0.0)
	var masa_total := masa_seca + combustible
	var capacidad: float = cohete.get("capacidad", 0.0) * mision.get("factor_capacidad", 1.0)
	var generacion := calcular_generacion(pieza_elegida("energia"), mision.get("distancia_ua", 1.0))
	var transmitibles: float = pieza_elegida("comunicacion").get("tasa", 0.0) / mision.get("factor_datos", 1.0)
	var delta_v := calcular_delta_v(propulsion.get("isp", 0.0), masa_total, masa_seca)

	medidores = {
		"costo": _medidor("Presupuesto", costo, mision.get("presupuesto", 0.0), "M$", false),
		"masa": _medidor("Masa", masa_total, capacidad, "kg", false),
		"energia": _medidor("Energía", consumo, generacion, "W", false),
		"datos": _medidor("Datos", datos_generados, transmitibles, "u/turno", false),
		"delta_v": _medidor("Delta-v", delta_v, mision.get("delta_v", 0.0), "m/s", true),
	}
	detalle = {
		"masa_seca": masa_seca,
		"combustible": combustible,
		"generacion": generacion,
		"consumo": consumo,
		"fiabilidad_lanzamiento": cohete.get("fiabilidad", 0.0),
		"fiabilidad_nave": fiabilidad_nave,
		"proteccion": _proteccion_total(),
	}
	medidores_cambiados.emit(medidores)


## dv = Isp * g0 * ln(masa_inicial / masa_final)
static func calcular_delta_v(isp: float, masa_inicial: float, masa_final: float) -> float:
	if isp <= 0.0 or masa_final <= 0.0 or masa_inicial <= masa_final:
		return 0.0
	return isp * G0 * log(masa_inicial / masa_final)


## Los paneles solares rinden potencia / distancia^2; el RTG no depende de la distancia.
static func calcular_generacion(fuente: Dictionary, distancia_ua: float) -> float:
	var potencia: float = fuente.get("potencia", 0.0)
	if fuente.get("tipo", "") == "solar" and distancia_ua > 0.0:
		return potencia / pow(distancia_ua, 2)
	return potencia


func _proteccion_total() -> float:
	var proteccion := 0.0
	for pieza in piezas_elegidas("extra"):
		proteccion = maxf(proteccion, pieza.get("proteccion", 0.0))
	return proteccion


static func _medidor(nombre: String, valor: float, limite: float, unidad: String, mayor_es_mejor: bool) -> Dictionary:
	return {
		"nombre": nombre,
		"valor": valor,
		"limite": limite,
		"unidad": unidad,
		"mayor_es_mejor": mayor_es_mejor,
		"ok": valor >= limite if mayor_es_mejor else valor <= limite,
	}
