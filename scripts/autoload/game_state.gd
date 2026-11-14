extends Node
## Estado global de la partida (autoload "GameState").
##
## Única fuente de verdad: guarda la misión elegida, las piezas, el lanzamiento,
## los turnos de operación y el informe, y hace todas las cuentas. Las pantallas
## solo leen de acá, llaman a sus funciones y escuchan las señales.

signal mision_cambiada(mision: Dictionary)
signal seleccion_cambiada(ids: Array)
signal medidores_cambiados(medidores: Dictionary)
signal plan_cambiado
signal turno_iniciado(turno: int)
signal turno_terminado(resumen: Dictionary)
## Cambió el hambre, la cordura o las raciones de la tripulación.
signal tripulacion_cambiada(hambre: float, cordura: float)
## Las operaciones terminaron. motivo: "turnos", "llegada", "salud", "hambre" o "cordura".
signal operaciones_terminadas(motivo: String)
## Avanzó el viaje al destino (solo misiones con "viaje"). progreso de 0 a 1.
signal viaje_avanzado(progreso: float)

const RUTA_DATOS := "res://data/datos.json"
const G0 := 9.81
## Pantallas de interfaz: se abren en las consolas de la cabina.
const ESCENAS := {
	"briefing": "res://scenes/briefing/briefing.tscn",
	"diseno": "res://scenes/diseno/diseno.tscn",
	"operaciones": "res://scenes/operaciones/operaciones.tscn",
	"informe": "res://scenes/informe/informe.tscn",
}
const ESCENA_CABINA := "res://scenes/cabina/cabina.tscn"
const ESCENA_LANZAMIENTO := "res://scenes/lanzamiento/lanzamiento.tscn"
## Los ambientes de la nave que se recorren a pie, en orden desde la cabina:
## cabina ⇄ habitáculo ⇄ esclusa ⇄ exterior. Se pasa de uno a otro por sus puertas.
const AMBIENTES := {
	"cabina": "res://scenes/cabina/cabina.tscn",
	"habitaculo": "res://scenes/sala_dos/sala_dos.tscn",
	"esclusa": "res://scenes/esclusa/esclusa.tscn",
	"exterior": "res://scenes/eva/eva.tscn",
}
## Daño por turno cuando la energía no alcanza ni para los sistemas básicos.
const DANO_APAGON := 15.0
## Fracción de la tasa que queda si la antena se rompe (antena de emergencia).
const TASA_EMERGENCIA := 0.1

## Contenido completo de data/datos.json.
var datos: Dictionary = {}
## Misión elegida (vacía hasta pasar por el briefing).
var mision: Dictionary = {}
## Ids de las piezas elegidas, en el orden en que se eligieron.
var seleccion: Array[String] = []
## Los 5 medidores: costo, masa, energia, datos, delta_v.
## Cada uno es {nombre, valor, limite, unidad, mayor_es_mejor, ok}.
var medidores: Dictionary = {}
## Números intermedios del diseño: masa_seca, combustible, generacion, consumo,
## fiabilidad_lanzamiento, fiabilidad_nave, proteccion.
var detalle: Dictionary = {}
## Resultado del lanzamiento: {exito, motivo}. motivo: "", "masa", "cohete", "delta_v".
var lanzamiento: Dictionary = {}
## Estado de la fase de operaciones (ver iniciar_operaciones).
var ops: Dictionary = {}
## Qué está encendido este turno: {instrumentos: {id: bool}, transmitir, calefaccion}.
var plan: Dictionary = {}
## Resultado final (ver calcular_informe).
var informe: Dictionary = {}
## Pantalla que la cabina abre apenas carga ("" para ninguna).
var pantalla_pendiente := ""
## Para los niveles de prueba de la esclusa y la caminata: true al volver de afuera.
var vuelve_de_caminata := false
## Ambiente del que viene el jugador al cruzar una puerta ("" si no cruzó ninguna):
## el ambiente de destino lo ubica frente a la puerta correcta.
var origen_transicion := ""

var rng := RandomNumberGenerator.new()

var _piezas_por_id: Dictionary = {}
var _categorias_por_id: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.randomize()
	cargar_datos()
	recalcular()


## El reloj de la tripulación corre solo en órbita y mientras sigan las operaciones.
func _process(delta: float) -> void:
	if reloj_corriendo():
		avanzar_tiempo(delta)


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


## Navegación entre fases. "lanzamiento" es la cinemática; las demás pantallas
## se abren en una consola de la cabina (si no estamos en ella, la carga primero).
func ir_a(pantalla: String) -> void:
	if pantalla == "lanzamiento":
		get_tree().change_scene_to_file(ESCENA_LANZAMIENTO)
		return
	if AMBIENTES.has(pantalla):
		get_tree().change_scene_to_file(AMBIENTES[pantalla])
		return
	var actual := get_tree().current_scene
	if actual and actual.has_method("abrir_pantalla"):
		actual.abrir_pantalla(pantalla)
		return
	# Al llegar a la órbita no se abre nada: primero se mira por la ventana.
	pantalla_pendiente = "" if pantalla == "operaciones" else pantalla
	get_tree().change_scene_to_file(ESCENA_CABINA)


## La nave está en órbita si el lanzamiento salió bien y empezaron las operaciones.
func en_orbita() -> bool:
	return lanzamiento.get("exito", false) and not ops.is_empty()


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


func get_nave_base() -> Dictionary:
	return datos.get("nave_base", {})


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


## Empieza de cero: sin misión ni piezas.
func reiniciar() -> void:
	mision = {}
	seleccion.clear()
	volver_a_diseno()
	mision_cambiada.emit(mision)
	_seleccion_actualizada()


## Conserva misión y piezas, y descarta lo que pasó después del diseño.
func volver_a_diseno() -> void:
	lanzamiento = {}
	ops = {}
	plan = {}
	informe = {}


func _seleccion_actualizada() -> void:
	seleccion_cambiada.emit(seleccion.duplicate())
	recalcular()


# --- Medidores --------------------------------------------------------------

func recalcular() -> void:
	var cohete := pieza_elegida("cohete")
	var propulsion := pieza_elegida("propulsion")

	# Todo lo que viaja en la nave: la base más las piezas, sin el cohete.
	var piezas_nave: Array = [get_nave_base()]
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


# --- Lanzamiento ------------------------------------------------------------

## Resuelve el lanzamiento y la llegada. Orden: masa, tirada de fiabilidad, delta-v.
func lanzar() -> Dictionary:
	recalcular()
	var motivo := ""
	if medidores["masa"]["valor"] > medidores["masa"]["limite"]:
		motivo = "masa"
	elif rng.randf() > detalle["fiabilidad_lanzamiento"]:
		motivo = "cohete"
	elif medidores["delta_v"]["valor"] < medidores["delta_v"]["limite"] and not mision.has("viaje"):
		# En un viaje el delta-v se necesita para frenar al llegar: se juzga al final.
		motivo = "delta_v"
	lanzamiento = {"exito": motivo == "", "motivo": motivo}
	ops = {}
	informe = {}
	return lanzamiento


## Explicación del fallo de lanzamiento, o "" si salió bien.
func texto_fallo_lanzamiento() -> String:
	match lanzamiento.get("motivo", ""):
		"masa":
			return _frase("fallo_masa", {"masa": roundi(medidores["masa"]["valor"]), "capacidad": roundi(medidores["masa"]["limite"])})
		"cohete":
			return _frase("fallo_cohete", {"fiabilidad": roundi(detalle["fiabilidad_lanzamiento"] * 100)})
		"delta_v":
			return _frase("fallo_delta_v", {"dv": roundi(medidores["delta_v"]["valor"]), "requerido": roundi(medidores["delta_v"]["limite"])})
	return ""


# --- Operaciones ------------------------------------------------------------

func iniciar_operaciones() -> void:
	var partida: Dictionary = datos.get("partida", {})
	var tripulacion := get_tripulacion()
	ops = {
		"turno": 1,
		"turnos": int(partida.get("turnos", 8)),
		"terminada": false,
		"salud": 100.0,
		"bateria": float(get_nave_base().get("bateria", 0.0)),
		"almacen": {},  # id de instrumento -> datos guardados sin transmitir
		"rotas": [],  # ids de piezas fuera de servicio
		"dv_restante": medidores["delta_v"]["valor"] - medidores["delta_v"]["limite"],
		"ciencia": 0.0,
		"datos_generados": 0.0,
		"datos_transmitidos": 0.0,
		"datos_perdidos": 0.0,
		"apagones": 0,
		"turnos_frio": 0,
		"sin_ciencia_turnos": 0,
		"multiplicador_turno": 1.0,
		"multiplicador_resto": 1.0,
		"eventos": {},  # turno -> id de evento
		"evento_actual": {},  # evento que hay que decidir antes de terminar el turno
		"eventos_vividos": [],  # {turno, titulo, resultado}
		"respaldos": [],  # nombres de componentes que salvó la redundancia
		"avisos": [],  # mensajes del inicio del turno (energía recortada, etc.)
		"hambre": float(tripulacion.get("hambre_inicial", 100.0)),
		"cordura": float(tripulacion.get("cordura_inicial", 100.0)),
		"raciones": int(pieza_elegida("viveres").get("raciones", tripulacion.get("raciones", 0))),
		"motivo_fin": "",  # "", "turnos", "llegada", "salud", "hambre" o "cordura"
		"viaje": {},  # ver _preparar_viaje; {} si la misión no tiene viaje
	}
	ops["viaje"] = _preparar_viaje()
	plan = {"instrumentos": {}, "transmitir": true, "calefaccion": true}
	for pieza in piezas_elegidas("instrumento"):
		plan["instrumentos"][pieza["id"]] = true
	_programar_eventos(int(partida.get("eventos_por_partida", 3)))
	_iniciar_turno()


## Condición especial del turno actual (noche lunar, tormenta de polvo...), o {}.
func condicion_turno() -> Dictionary:
	return condicion_de_turno(ops.get("turno", 0))


func condicion_de_turno(turno: int) -> Dictionary:
	return mision.get("condiciones", {}).get(str(turno), {})


## Batería que quedará al terminar el turno con el plan actual.
func bateria_al_terminar() -> float:
	var energia := energia_turno()
	return clampf(energia["disponible"] - energia["consumo"], 0.0, get_nave_base().get("bateria", 0.0))


func esta_rota(id: String) -> bool:
	return ops.get("rotas", []).has(id)


## Energía del turno: {generacion, bateria, disponible, base, consumo, libre}.
func energia_turno() -> Dictionary:
	var fuente := pieza_elegida("energia")
	var generacion := calcular_generacion(fuente, mision.get("distancia_ua", 1.0))
	if fuente.get("tipo", "") == "solar":
		generacion *= condicion_turno().get("factor_solar", 1.0)
	if esta_rota(fuente.get("id", "")):
		generacion *= 0.5
	var bateria: float = ops.get("bateria", 0.0)
	var consumo := consumo_plan()
	return {
		"generacion": generacion,
		"bateria": bateria,
		"disponible": generacion + bateria,
		"base": float(get_nave_base().get("consumo", 0.0)),
		"consumo": consumo,
		"libre": generacion + bateria - consumo,
	}


## Consumo del plan actual, incluidos los sistemas básicos.
func consumo_plan() -> float:
	var total: float = get_nave_base().get("consumo", 0.0)
	if plan.get("calefaccion", false):
		total += mision.get("calefaccion", 0.0)
	var antena := pieza_elegida("comunicacion")
	if plan.get("transmitir", false) and not esta_rota(antena.get("id", "")):
		total += antena.get("consumo", 0.0)
	for id in plan.get("instrumentos", {}):
		if plan["instrumentos"][id] and not esta_rota(id):
			total += get_pieza(id).get("consumo", 0.0)
	return total


## Consumo que agrega encender algo del plan: "calefaccion", "transmitir" o un instrumento.
func consumo_de(clave: String) -> float:
	match clave:
		"calefaccion":
			return mision.get("calefaccion", 0.0)
		"transmitir":
			return pieza_elegida("comunicacion").get("consumo", 0.0)
	return get_pieza(clave).get("consumo", 0.0)


## Enciende o apaga algo del plan. Devuelve false si no alcanza la energía o está roto.
func cambiar_plan(clave: String, activo: bool) -> bool:
	if activo:
		if clave != "calefaccion" and clave != "transmitir" and esta_rota(clave):
			return false
		if clave == "transmitir" and esta_rota(pieza_elegida("comunicacion").get("id", "")):
			return false
		if not _esta_activo(clave) and consumo_de(clave) > energia_turno()["libre"] + 0.001:
			return false
	if clave == "calefaccion" or clave == "transmitir":
		plan[clave] = activo
	else:
		plan["instrumentos"][clave] = activo
	plan_cambiado.emit()
	return true


## Datos que la antena puede enviar este turno.
func capacidad_transmision() -> float:
	var antena := pieza_elegida("comunicacion")
	var tasa: float = antena.get("tasa", 0.0) / mision.get("factor_datos", 1.0)
	return tasa * TASA_EMERGENCIA if esta_rota(antena.get("id", "")) else tasa


## Datos que generaría un instrumento este turno con las condiciones actuales.
func datos_de_instrumento(id: String) -> float:
	if esta_rota(id) or ops.get("sin_ciencia_turnos", 0) > 0:
		return 0.0
	var multiplicador: float = ops.get("multiplicador_turno", 1.0) * ops.get("multiplicador_resto", 1.0)
	multiplicador *= condicion_turno().get("multiplicador_instrumentos", {}).get(id, 1.0)
	return get_pieza(id).get("datos", 0.0) * multiplicador


func datos_almacenados() -> float:
	var total := 0.0
	for id in ops.get("almacen", {}):
		total += ops["almacen"][id]
	return total


func opcion_disponible(opcion: Dictionary) -> bool:
	var requisitos: Dictionary = opcion.get("requisitos", {})
	return ops.get("dv_restante", 0.0) >= requisitos.get("delta_v", 0.0)


## Aplica la opción elegida del evento actual y devuelve el texto del resultado.
func resolver_evento(indice: int) -> String:
	var evento: Dictionary = ops.get("evento_actual", {})
	if evento.is_empty():
		return ""
	var opcion: Dictionary = evento["opciones"][indice]
	if not opcion_disponible(opcion):
		return ""
	var mensajes := _aplicar_efectos(opcion.get("efectos", {}), evento.get("objetivo_id", ""))
	var texto := " ".join([opcion.get("resultado", "")] + mensajes).strip_edges()
	ops["eventos_vividos"].append({"turno": ops["turno"], "titulo": evento["titulo"], "resultado": texto})
	ops["evento_actual"] = {}
	_ajustar_plan()
	plan_cambiado.emit()
	return texto


## Cierra el turno: energía, datos, transmisión, ciencia y daños.
func terminar_turno() -> Dictionary:
	if ops.is_empty() or ops["terminada"] or not ops["evento_actual"].is_empty():
		return {}
	var energia := energia_turno()
	var capacidad_bateria: float = get_nave_base().get("bateria", 0.0)
	var resumen := {
		"turno": ops["turno"],
		"condicion": condicion_turno().get("nombre", ""),
		"generados": 0.0, "transmitidos": 0.0, "perdidos": 0.0, "ciencia": 0.0,
		"mensajes": [],
	}

	if energia["base"] > energia["disponible"]:
		# Apagón: no alcanza ni para la computadora. Todo se apaga y la nave sufre.
		ops["apagones"] += 1
		ops["salud"] -= DANO_APAGON
		ops["bateria"] = 0.0
		resumen["mensajes"].append("Apagón: no alcanzó la energía ni para los sistemas básicos.")
	else:
		ops["bateria"] = minf(capacidad_bateria, energia["disponible"] - energia["consumo"])
		if not plan["calefaccion"]:
			ops["turnos_frio"] += 1
			ops["salud"] -= mision.get("dano_frio", 0.0)
			resumen["mensajes"].append("Sin calefacción: la electrónica y la tripulación sufrieron el frío.")
			cambiar_tripulacion(0.0, -get_tripulacion().get("cordura_por_frio", 0.0))
		_generar_datos(resumen)
		if plan["transmitir"]:
			_transmitir(resumen)

	ops["salud"] = clampf(ops["salud"], 0.0, 100.0)
	ops["sin_ciencia_turnos"] = maxi(0, ops["sin_ciencia_turnos"] - 1)
	ops["turno"] += 1
	# Si la tripulación cayó durante el turno, el final ya quedó registrado.
	var ya_terminada: bool = ops["terminada"]
	if ya_terminada:
		pass
	elif ops["salud"] <= 0.0:
		ops["terminada"] = true
		ops["motivo_fin"] = "salud"
		ops["turno_perdida"] = resumen["turno"]
		resumen["mensajes"].append("Se perdió el contacto con la nave.")
	elif ops["turno"] > ops["turnos"]:
		ops["terminada"] = true
		ops["motivo_fin"] = "turnos"
		if tiene_viaje():
			# El último tramo cierra al llegar (los tests cierran turnos a mano).
			ops["viaje"]["recorrido_km"] = ops["viaje"]["distancia_km"]
			if ops["dv_restante"] < 0.0:
				# Llegó sin delta-v para frenar: pasa de largo.
				ops["motivo_fin"] = "frenado"
				ops["turno_perdida"] = resumen["turno"]
				resumen["mensajes"].append("No alcanzó el delta-v para frenar: la nave pasó de largo.")
			else:
				ops["motivo_fin"] = "llegada"
	turno_terminado.emit(resumen)
	if ops["terminada"] and not ya_terminada:
		operaciones_terminadas.emit(ops["motivo_fin"])
	else:
		_iniciar_turno()
	return resumen


# --- Tripulación ------------------------------------------------------------

func get_tripulacion() -> Dictionary:
	return datos.get("tripulacion", {})


func reloj_corriendo() -> bool:
	return en_orbita() and not ops.get("terminada", true)


## Avanza el reloj de la tripulación: hambre y cordura bajan por minuto.
func avanzar_tiempo(segundos: float) -> void:
	if ops.is_empty() or ops["terminada"]:
		return
	var minutos := segundos / 60.0
	var tripulacion := get_tripulacion()
	cambiar_tripulacion(-tripulacion.get("hambre_por_minuto", 0.0) * minutos, -tripulacion.get("cordura_por_minuto", 0.0) * minutos)
	if tiene_viaje() and not ops["terminada"]:
		_avanzar_viaje(segundos)


# --- Viaje ------------------------------------------------------------------

## La misión tiene un viaje al destino (por ahora solo la Luna). Requiere operaciones iniciadas.
func tiene_viaje() -> bool:
	return not ops.get("viaje", {}).is_empty()


## Velocidad media de crucero en m/s: base más una parte del delta-v que sobró,
## con tope, por el empuje del motor (el iónico empuja poco y llega más lento).
static func calcular_velocidad_viaje(viaje: Dictionary, dv_sobrante: float, empuje: float) -> float:
	var base: float = viaje.get("velocidad_base", 1000.0)
	var velocidad := clampf(base + maxf(dv_sobrante, 0.0) * viaje.get("factor_dv", 0.0), base, viaje.get("velocidad_maxima", base))
	return velocidad * empuje


func _preparar_viaje() -> Dictionary:
	var datos_viaje: Dictionary = mision.get("viaje", {})
	if datos_viaje.is_empty():
		return {}
	var empuje: float = pieza_elegida("propulsion").get("empuje", 1.0)
	var velocidad := calcular_velocidad_viaje(datos_viaje, ops.get("dv_restante", 0.0), empuje)
	var distancia: float = datos_viaje["distancia_km"]
	return {
		"distancia_km": distancia,
		"velocidad": velocidad,
		"horas_totales": distancia / (velocidad * 3.6),
		"segundos_por_hora": float(datos_viaje.get("segundos_por_hora", 10.0)),
		"horas": 0.0,
		"recorrido_km": 0.0,
	}


## Fracción del viaje recorrida, de 0 a 1 (0 si no hay viaje).
func progreso_viaje() -> float:
	if not tiene_viaje():
		return 0.0
	return ops["viaje"]["recorrido_km"] / ops["viaje"]["distancia_km"]


## Minutos reales que faltan para llegar.
func minutos_para_llegar() -> float:
	if not tiene_viaje():
		return 0.0
	var viaje: Dictionary = ops["viaje"]
	return maxf(0.0, viaje["horas_totales"] - viaje["horas"]) * viaje["segundos_por_hora"] / 60.0


## Segundos reales que faltan para que se cierre el tramo (turno) actual.
func segundos_para_tramo() -> float:
	if not tiene_viaje():
		return 0.0
	var viaje: Dictionary = ops["viaje"]
	var horas_tramo: float = viaje["horas_totales"] * float(ops["turno"]) / ops["turnos"]
	return maxf(0.0, horas_tramo - viaje["horas"]) * viaje["segundos_por_hora"]


func _avanzar_viaje(segundos: float) -> void:
	var viaje: Dictionary = ops["viaje"]
	viaje["horas"] = minf(viaje["horas"] + segundos / viaje["segundos_por_hora"], viaje["horas_totales"])
	viaje["recorrido_km"] = minf(viaje["velocidad"] * 3.6 * viaje["horas"], viaje["distancia_km"])
	viaje_avanzado.emit(progreso_viaje())
	# Cada tramo del viaje es un turno: se cierra solo, salvo que haya un evento sin decidir.
	while not ops["terminada"] and ops["evento_actual"].is_empty() \
			and viaje["horas"] >= viaje["horas_totales"] * float(ops["turno"]) / ops["turnos"] - 0.0001:
		terminar_turno()


## Punto único para subir o bajar las barras (eventos, tareas, zonas de la nave).
func cambiar_tripulacion(hambre: float, cordura: float) -> void:
	if ops.is_empty() or ops["terminada"]:
		return
	ops["hambre"] = clampf(ops["hambre"] + hambre, 0.0, 100.0)
	ops["cordura"] = clampf(ops["cordura"] + cordura, 0.0, 100.0)
	tripulacion_cambiada.emit(ops["hambre"], ops["cordura"])
	_revisar_tripulacion()


## Come una ración. Devuelve false si no quedan o si la tripulación no tiene hambre.
func comer_racion() -> bool:
	if ops.is_empty() or ops["terminada"] or ops["raciones"] <= 0 or ops["hambre"] >= 100.0:
		return false
	ops["raciones"] -= 1
	cambiar_tripulacion(get_tripulacion().get("hambre_por_racion", 0.0), 0.0)
	return true


func _revisar_tripulacion() -> void:
	var motivo := ""
	if ops["hambre"] <= 0.0:
		motivo = "hambre"
	elif ops["cordura"] <= 0.0:
		motivo = "cordura"
	if motivo == "":
		return
	ops["terminada"] = true
	ops["motivo_fin"] = motivo
	ops["turno_perdida"] = ops["turno"]
	ops["evento_actual"] = {}
	operaciones_terminadas.emit(motivo)
	plan_cambiado.emit()


func _iniciar_turno() -> void:
	ops["multiplicador_turno"] = 1.0
	ops["avisos"] = []
	ops["evento_actual"] = {}
	var id_evento: String = ops["eventos"].get(ops["turno"], "")
	if id_evento != "":
		ops["evento_actual"] = _preparar_evento(id_evento)
	_ajustar_plan()
	turno_iniciado.emit(ops["turno"])
	plan_cambiado.emit()


func _generar_datos(resumen: Dictionary) -> void:
	var nuevos := {}
	var total := 0.0
	for id in plan["instrumentos"]:
		if plan["instrumentos"][id]:
			var cantidad := datos_de_instrumento(id)
			if cantidad > 0.0:
				nuevos[id] = cantidad
				total += cantidad
	if total <= 0.0:
		return
	# Lo que no entra en la memoria se pierde, en proporción a cada instrumento.
	var espacio: float = maxf(0.0, get_nave_base().get("almacenamiento", 0.0) - datos_almacenados())
	var entra := minf(1.0, espacio / total)
	for id in nuevos:
		ops["almacen"][id] = ops["almacen"].get(id, 0.0) + nuevos[id] * entra
	var perdidos := total * (1.0 - entra)
	ops["datos_generados"] += total
	ops["datos_perdidos"] += perdidos
	resumen["generados"] = total
	resumen["perdidos"] = perdidos
	if perdidos > 0.0:
		resumen["mensajes"].append("Memoria llena: se perdieron %d datos." % roundi(perdidos))


func _transmitir(resumen: Dictionary) -> void:
	var guardados := datos_almacenados()
	if guardados <= 0.0:
		return
	var enviados := minf(guardados, capacidad_transmision())
	var fraccion := enviados / guardados
	var ciencia := 0.0
	for id in ops["almacen"]:
		var parte: float = ops["almacen"][id] * fraccion
		ops["almacen"][id] -= parte
		ciencia += parte * get_pieza(id).get("ciencia", 1.0)
	ops["datos_transmitidos"] += enviados
	ops["ciencia"] += ciencia
	resumen["transmitidos"] = enviados
	resumen["ciencia"] = ciencia


## Si el plan no entra en la energía del turno, apaga cosas: primero los
## instrumentos que más consumen, después la transmisión y al final la calefacción.
func _ajustar_plan() -> void:
	var apagados := []
	for id in plan["instrumentos"]:
		if plan["instrumentos"][id] and esta_rota(id):
			plan["instrumentos"][id] = false
	var instrumentos: Array = plan["instrumentos"].keys().filter(func(id): return plan["instrumentos"][id])
	instrumentos.sort_custom(func(a, b): return consumo_de(a) > consumo_de(b))
	var orden: Array = instrumentos + ["transmitir", "calefaccion"]
	for clave in orden:
		if energia_turno()["libre"] >= 0.0:
			break
		if clave == "transmitir" or clave == "calefaccion":
			if plan[clave]:
				plan[clave] = false
				apagados.append(clave)
		else:
			plan["instrumentos"][clave] = false
			apagados.append(get_pieza(clave)["nombre"])
	if not apagados.is_empty():
		ops["avisos"].append("No alcanza la energía: se apagó " + ", ".join(apagados) + ".")


func _esta_activo(clave: String) -> bool:
	if clave == "calefaccion" or clave == "transmitir":
		return plan.get(clave, false)
	return plan.get("instrumentos", {}).get(clave, false)


func _programar_eventos(cantidad: int) -> void:
	var turnos_posibles := []
	for t in range(2, ops["turnos"]):
		turnos_posibles.append(t)
	var ids := []
	for evento in datos.get("eventos", []):
		ids.append(evento["id"])
	_barajar(turnos_posibles)
	_barajar(ids)
	for i in mini(cantidad, mini(turnos_posibles.size(), ids.size())):
		ops["eventos"][turnos_posibles[i]] = ids[i]


func _preparar_evento(id: String) -> Dictionary:
	var original: Dictionary = {}
	for evento in datos.get("eventos", []):
		if evento["id"] == id:
			original = evento
	var evento: Dictionary = original.duplicate(true)
	if evento.get("objetivo", "") != "componente":
		return evento

	# El evento le pasa a un componente instalado que todavía funciona.
	var candidatos := []
	for categoria in ["instrumento", "comunicacion", "energia"]:
		for pieza in piezas_elegidas(categoria):
			if not esta_rota(pieza["id"]):
				candidatos.append(pieza)
	if candidatos.is_empty():
		return {}
	var objetivo: Dictionary = candidatos[rng.randi_range(0, candidatos.size() - 1)]
	evento["objetivo_id"] = objetivo["id"]
	evento["texto"] = evento["texto"].format({"componente": objetivo["nombre"]})
	var respaldo: String = evento.get("evitable_con", "")
	if respaldo != "" and tiene_pieza(respaldo):
		ops["respaldos"].append(objetivo["nombre"])
		evento["texto"] = evento.get("texto_evitado", "").format({"componente": objetivo["nombre"]})
		evento["opciones"] = [{"texto": "Continuar", "efectos": {}, "resultado": "El respaldo funcionó."}]
	else:
		ops["rotas"].append(objetivo["id"])
	return evento


func _aplicar_efectos(efectos: Dictionary, objetivo_id: String) -> Array:
	var mensajes := []
	var proteccion: float = detalle.get("proteccion", 0.0) if efectos.get("blindable", false) else 0.0
	if efectos.has("salud"):
		var cambio: float = efectos["salud"]
		if cambio < 0.0:
			cambio *= 1.0 - proteccion
			if proteccion > 0.0:
				mensajes.append("El blindaje absorbió parte del daño.")
		ops["salud"] = clampf(ops["salud"] + cambio, 0.0, 100.0)
	if efectos.has("sin_ciencia_turnos"):
		ops["sin_ciencia_turnos"] = maxi(ops["sin_ciencia_turnos"], int(efectos["sin_ciencia_turnos"]))
	if efectos.has("multiplicador_datos"):
		ops["multiplicador_turno"] *= efectos["multiplicador_datos"]
	if efectos.has("multiplicador_datos_resto"):
		ops["multiplicador_resto"] *= efectos["multiplicador_datos_resto"]
	if efectos.has("delta_v"):
		ops["dv_restante"] += efectos["delta_v"]
	if efectos.has("hambre") or efectos.has("cordura"):
		cambiar_tripulacion(efectos.get("hambre", 0.0), efectos.get("cordura", 0.0))
	if efectos.has("bateria"):
		ops["bateria"] = clampf(ops["bateria"] + efectos["bateria"], 0.0, get_nave_base().get("bateria", 0.0))

	var probabilidad: float = efectos.get("probabilidad", 1.0)
	if efectos.has("romper"):
		var id: String = objetivo_id if efectos["romper"] == "objetivo" else _instrumento_sano_al_azar()
		if id != "" and rng.randf() < probabilidad * (1.0 - proteccion):
			ops["rotas"].append(id)
			mensajes.append("Quedó fuera de servicio: %s." % get_pieza(id)["nombre"])
	if efectos.has("reparar") and objetivo_id != "":
		var nombre: String = get_pieza(objetivo_id)["nombre"]
		if rng.randf() < probabilidad:
			ops["rotas"].erase(objetivo_id)
			mensajes.append("¡%s volvió a funcionar!" % nombre)
		else:
			mensajes.append("%s no respondió al reinicio." % nombre)
	return mensajes


func _instrumento_sano_al_azar() -> String:
	var sanos := []
	for pieza in piezas_elegidas("instrumento"):
		if not esta_rota(pieza["id"]):
			sanos.append(pieza["id"])
	return "" if sanos.is_empty() else sanos[rng.randi_range(0, sanos.size() - 1)]


func _barajar(lista: Array) -> void:
	for i in range(lista.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temporal = lista[i]
		lista[i] = lista[j]
		lista[j] = temporal


# --- Informe ----------------------------------------------------------------

## Calcula el puntaje y las frases que explican el resultado.
## {exito, puntaje, nota, ciencia, objetivo, sobrante, salud, frases}
func calcular_informe() -> Dictionary:
	var presupuesto: float = mision.get("presupuesto", 1.0)
	var sobrante: float = presupuesto - medidores["costo"]["valor"]
	var objetivo: float = mision.get("objetivo_ciencia", 1.0)
	var llego: bool = lanzamiento.get("exito", false)
	var ciencia: float = ops.get("ciencia", 0.0) if llego else 0.0
	var salud: float = ops.get("salud", 0.0) if llego else 0.0
	var perdida: bool = not llego or ops.get("turno_perdida", 0) > 0
	var motivo_fin: String = ops.get("motivo_fin", "")

	# Ciencia hasta 600 (900 si supera el objetivo), salud hasta 200, llegar al
	# destino de un viaje suma puntos_llegada y presupuesto: ahorrar suma hasta 100,
	# pero pasarse resta ocho veces más.
	var puntaje := 0
	if llego:
		var fraccion_sobrante := sobrante / presupuesto
		var puntos_presupuesto := fraccion_sobrante * 100.0 if sobrante >= 0.0 else maxf(fraccion_sobrante * 800.0, -600.0)
		var puntos_llegada: float = mision.get("viaje", {}).get("puntos_llegada", 0.0) if motivo_fin == "llegada" else 0.0
		puntaje = maxi(roundi(minf(ciencia / objetivo, 1.5) * 600.0 + puntos_presupuesto + salud * 2.0 + puntos_llegada), 0)

	var nota := "Misión perdida"
	if llego and not perdida:
		if puntaje >= 850:
			nota = "Misión legendaria"
		elif puntaje >= 650:
			nota = "Misión exitosa"
		elif puntaje >= 400:
			nota = "Éxito parcial"
		else:
			nota = "Misión con problemas"
	elif llego and motivo_fin == "frenado":
		nota = "No pudo frenar"
	elif llego and (motivo_fin == "hambre" or motivo_fin == "cordura"):
		nota = "Tripulación perdida"
	elif llego:
		nota = "Contacto perdido"

	informe = {
		"exito": llego and not perdida,
		"puntaje": puntaje,
		"nota": nota,
		"ciencia": ciencia,
		"objetivo": objetivo,
		"sobrante": sobrante,
		"salud": salud,
		"hambre": ops.get("hambre", 0.0) if llego else 0.0,
		"cordura": ops.get("cordura", 0.0) if llego else 0.0,
		"raciones": ops.get("raciones", 0) if llego else 0,
		"motivo_fin": motivo_fin,
		"viaje": ops.get("viaje", {}).duplicate() if llego else {},
		"frases": _frases_informe(ciencia, objetivo, sobrante, presupuesto),
	}
	return informe


func _frases_informe(ciencia: float, objetivo: float, sobrante: float, presupuesto: float) -> Array:
	var frases := []
	if not lanzamiento.get("exito", false):
		frases.append(texto_fallo_lanzamiento())
	else:
		frases.append(_frase("ciencia", {"ciencia": roundi(ciencia), "objetivo": roundi(objetivo), "pct": roundi(ciencia / objetivo * 100)}))
		var viaje: Dictionary = ops.get("viaje", {})
		if not viaje.is_empty():
			if ops.get("motivo_fin", "") == "frenado":
				# dv_restante es lo que sobra (o falta) sobre lo requerido para frenar.
				var requerido: float = medidores["delta_v"]["limite"]
				frases.append(_frase("fallo_frenado", {"dv": roundi(maxf(0.0, requerido + ops["dv_restante"])), "requerido": roundi(requerido)}))
			elif ops.get("motivo_fin", "") == "llegada":
				frases.append(_frase("llegada_luna", {"km": _miles(viaje["distancia_km"]), "horas": roundi(viaje["horas_totales"]), "velocidad": _miles(viaje["velocidad"])}))
			else:
				frases.append(_frase("viaje_incompleto", {"faltan": _miles(viaje["distancia_km"] - viaje["recorrido_km"]), "pct": roundi(progreso_viaje() * 100)}))
		match ops.get("motivo_fin", ""):
			"salud":
				frases.append(_frase("nave_perdida", {"turno": ops["turno_perdida"]}))
			"hambre":
				frases.append(_frase("fin_hambre", {}))
			"cordura":
				frases.append(_frase("fin_cordura", {}))
		var generados: float = ops.get("datos_generados", 0.0)
		if generados > 0.0:
			var proporcion: float = ops["datos_transmitidos"] / generados
			if proporcion < 0.8:
				frases.append(_frase("transmision_baja", {"pct": roundi(proporcion * 100)}))
			elif proporcion >= 0.95:
				frases.append(_frase("transmision_ok", {}))
		if ops.get("datos_perdidos", 0.0) >= 1.0:
			frases.append(_frase("datos_perdidos", {"datos": roundi(ops["datos_perdidos"])}))
		if ops.get("apagones", 0) > 0:
			frases.append(_frase_contada("apagones", ops["apagones"]))
		if ops.get("turnos_frio", 0) > 0:
			frases.append(_frase_contada("frio", ops["turnos_frio"]))
		for componente in ops.get("respaldos", []):
			frases.append(_frase("respaldo", {"componente": componente}))
		if ops.get("salud", 100.0) < 50.0 and ops.get("turno_perdida", 0) == 0:
			frases.append(_frase("salud_baja", {"salud": roundi(ops["salud"])}))
		if ops.has("cordura") and ops["cordura"] < 30.0 and ops.get("motivo_fin", "") != "cordura":
			frases.append(_frase("cordura_baja", {"cordura": roundi(ops["cordura"])}))
		if ops.get("raciones", 0) > 0:
			frases.append(_frase_contada("raciones_sobrantes", ops["raciones"]))
	if sobrante < 0.0:
		frases.append(_frase("presupuesto_excedido", {"monto": roundi(-sobrante)}))
	elif sobrante / presupuesto >= 0.15:
		frases.append(_frase("presupuesto_sobrante", {"monto": roundi(sobrante), "pct": roundi(sobrante / presupuesto * 100)}))
	return frases


## 384400 -> "384.400"
static func _miles(valor: float) -> String:
	var texto := str(roundi(valor))
	var resultado := ""
	while texto.length() > 3:
		resultado = "." + texto.right(3) + resultado
		texto = texto.left(texto.length() - 3)
	return texto + resultado


func _frase(clave: String, valores: Dictionary) -> String:
	return str(datos.get("frases", {}).get(clave, clave)).format(valores)


## Usa la variante "<clave>_uno" cuando la cantidad es 1, si existe.
func _frase_contada(clave: String, n: int) -> String:
	if n == 1 and datos.get("frases", {}).has(clave + "_uno"):
		return _frase(clave + "_uno", {})
	return _frase(clave, {"n": n})
