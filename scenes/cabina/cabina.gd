extends Node3D
## Cabina de la nave en primera persona: el lugar principal del juego.
##
## Antes del lanzamiento la nave está sobre la plataforma: por la ventana se ve
## la torre, y la computadora de misión abre el briefing y el diseño. Después
## del lanzamiento la nave está en órbita: por la ventana se ve el destino y
## cualquier consola abre las operaciones. Las pantallas de interfaz se abren
## encima, como si se mirara la consola de cerca.

const MODELO_CABINA := preload("res://assets/modelos/cabina.glb")
const MODELO_PLATAFORMA := preload("res://assets/modelos/plataforma.glb")
const MODELO_COHETES := preload("res://assets/modelos/cohetes.glb")
const Jugador := preload("res://scenes/cabina/jugador.gd")

const NOMBRES_CONSOLA := {
	"consola_principal": "Computadora de misión",
	"consola_energia": "Consola de energía",
	"consola_comunicaciones": "Consola de comunicaciones",
	"consola_ciencia": "Consola de ciencia",
}
## Dónde va el texto de cada pantalla, en coordenadas de la cabina: [posición, giro en Y, inclinación, ancho en px].
const PANTALLAS := {
	"consola_principal": [Vector3(0, 1.36, -3.7), 0.0, -15.0, 600],
	"consola_energia": [Vector3(-2.89, 1.6, -0.6), 90.0, 0.0, 480],
	"consola_comunicaciones": [Vector3(2.89, 1.6, -0.6), -90.0, 0.0, 480],
	"consola_ciencia": [Vector3(2.89, 1.6, 1.9), -90.0, 0.0, 480],
}
## Encima de la computadora de misión: ahí flota el marcador de "usá esta consola".
const POSICION_MARCADOR := Vector3(0, 1.95, -3.6)
## La puerta trasera, que lleva al habitáculo (en coordenadas de la cabina).
const PUERTA_TRASERA := Vector3(0, 1.15, 3.98)
const COLOR_PLANETA := {"tierra": Color("#2E6FD0"), "luna": Color("#A3A6B0"), "marte": Color("#C1552B")}
const REFRESCO_PANTALLAS := 0.3
## Viaje a la Luna: dónde se ven la Tierra y la Luna al salir y al llegar.
const TIERRA_INICIO := Vector3(-60, -105, -320)
const TIERRA_FIN := Vector3(260, -60, 900)
const LUNA_INICIO := Vector3(40, 30, -1400)
const LUNA_FIN := Vector3(-60, -105, -320)
const MENSAJES_FIN := {
	"llegada": "¡Llegaste a la Luna! El informe está en cualquier consola.",
	"frenado": "Llegaste a la Luna sin delta-v para frenar: la nave pasó de largo. El informe está en cualquier consola.",
	"hambre": "La tripulación no aguantó el hambre. La misión terminó: el informe está en cualquier consola.",
	"cordura": "La tripulación perdió la cordura. La misión terminó: el informe está en cualquier consola.",
}

var _interior: Node3D
var _jugador: Jugador
var _compuerta: Compuerta
var _textos_consola: Dictionary = {}  # consola -> Label3D
var _marcador: Label3D
var _planeta: Node3D
var _capa_pantalla: CanvasLayer
var _pantalla_abierta: Node
var _mira: Control
var _indicacion: Label
var _objetivo: Label
var _mensaje: Label
var _tiempo_refresco := 0.0
var _tripulacion: HudTripulacion
var _tierra: Node3D
var _luna: Node3D


func _ready() -> void:
	_interior = Node3D.new()
	add_child(_interior)
	var modelo := MODELO_CABINA.instantiate()
	_interior.add_child(modelo)
	_preparar_modelo(modelo)
	_crear_luces_interiores()
	_crear_textos_consola()

	_jugador = Jugador.new()
	_jugador.consola_usada.connect(_usar_consola)
	_interior.add_child(_jugador)

	if GameState.en_orbita():
		_armar_orbita()
	else:
		_armar_plataforma()
	var desde_habitaculo := GameState.origen_transicion == "habitaculo"
	if desde_habitaculo:
		# Entra por la puerta trasera, mirando hacia el frente de la cabina.
		_jugador.position = Vector3(0.0, 0.05, 2.9)
	else:
		# Al lado del asiento, a un paso de la computadora de misión.
		_jugador.position = Vector3(0.8, 0.05, -1.4)
	_jugador.mirar_hacia(_interior.to_global(PANTALLAS["consola_principal"][0]))
	_crear_compuerta()
	_crear_marcador()
	_crear_hud()
	GameState.operaciones_terminadas.connect(_on_operaciones_terminadas)
	GameState.viaje_avanzado.connect(func(_p: float) -> void: _actualizar_ventana_viaje())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var pendiente := GameState.pantalla_pendiente
	GameState.pantalla_pendiente = ""
	GameState.origen_transicion = ""
	if pendiente != "":
		abrir_pantalla(pendiente)
	elif desde_habitaculo:
		pass
	elif GameState.en_orbita():
		if GameState.tiene_viaje():
			_mostrar_mensaje("Rumbo a la Luna. Mirá por la ventana: la Tierra queda atrás. Usá cualquier consola para operar.")
		else:
			_mostrar_mensaje("La nave llegó a destino. Mirá por la ventana y usá cualquier consola para operar.")
	else:
		_mostrar_mensaje("Bienvenido a bordo. La computadora de misión está al frente.")


func _process(delta: float) -> void:
	if _planeta:
		_planeta.rotate_y(delta * 0.01)
	_marcador.position.y = POSICION_MARCADOR.y + sin(Time.get_ticks_msec() / 300.0) * 0.06
	_tiempo_refresco -= delta
	if _tiempo_refresco <= 0.0:
		_tiempo_refresco = REFRESCO_PANTALLAS
		_actualizar_textos_consola()
		_actualizar_hud()


func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and evento.physical_keycode == KEY_ESCAPE:
		if _pantalla_abierta:
			cerrar_pantalla()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()


# --- Pantallas de interfaz --------------------------------------------------

## La llama GameState.ir_a mientras estamos en la cabina.
func abrir_pantalla(pantalla: String) -> void:
	# Volver a diseñar desde la órbita es empezar otro intento: la nave vuelve a la plataforma.
	if (pantalla == "briefing" or pantalla == "diseno") and GameState.en_orbita():
		GameState.volver_a_diseno()
		GameState.pantalla_pendiente = pantalla
		get_tree().reload_current_scene()
		return
	cerrar_pantalla()
	_pantalla_abierta = load(GameState.ESCENAS[pantalla]).instantiate()
	_capa_pantalla.add_child(_pantalla_abierta)
	var volver := Interfaz.etiqueta("Esc: volver a la cabina", Interfaz.CIAN, 14)
	volver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	volver.position += Vector2(16, -28)
	_pantalla_abierta.add_child(volver)
	_jugador.activo = false
	_mira.visible = false
	_tripulacion.ubicacion = HudTripulacion.TIRA_ARRIBA
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func cerrar_pantalla() -> void:
	if _pantalla_abierta:
		_pantalla_abierta.queue_free()
		_pantalla_abierta = null
		if GameState.en_orbita() and not GameState.ops["terminada"]:
			var quedan: int = GameState.ops["turnos"] - GameState.ops["turno"] + 1
			if GameState.tiene_viaje():
				_mostrar_mensaje("Faltan %d tramos para la Luna. Volvé a cualquier consola para ajustar la energía." % quedan)
			else:
				_mostrar_mensaje("Quedan %d turnos. Volvé a cualquier consola para seguir operando." % quedan)
	_jugador.activo = true
	_mira.visible = true
	_tripulacion.ubicacion = HudTripulacion.PANEL
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _usar_consola(consola: String) -> void:
	if GameState.en_orbita():
		abrir_pantalla("informe" if GameState.ops["terminada"] else "operaciones")
	elif consola != "consola_principal":
		_mostrar_mensaje("Sin datos: la nave todavía está en la plataforma. Usá la computadora de misión.")
	else:
		abrir_pantalla("briefing" if GameState.mision.is_empty() else "diseno")


## La puerta trasera lleva al habitáculo, y de ahí a la esclusa y al exterior.
func _crear_compuerta() -> void:
	_compuerta = Compuerta.new()
	_compuerta.jugador = _jugador
	_compuerta.agregar(func() -> bool:
		return _jugador.position.z > 2.4 and absf(_jugador.position.x) < 1.2,
		"Ir al habitáculo", "habitaculo", "cabina")
	add_child(_compuerta)
	var cartel := Label3D.new()
	cartel.text = "HABITÁCULO"
	cartel.position = PUERTA_TRASERA + Vector3(0, 1.45, -0.12)
	cartel.rotation_degrees.y = 180
	cartel.pixel_size = 0.0025
	cartel.font_size = 32
	cartel.outline_size = 8
	cartel.outline_modulate = Interfaz.FONDO
	cartel.modulate = Interfaz.AQUA
	_interior.add_child(cartel)


# --- Modelo e iluminación ---------------------------------------------------

func _preparar_modelo(modelo: Node) -> void:
	var vidrio := modelo.find_child("ventana_vidrio", true, false) as MeshInstance3D
	if vidrio:
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(Interfaz.CIAN, 0.08)
		vidrio.material_override = material
	# Las pantallas y tableros también reciben colisión, para poder apuntarles con la mirada.
	for consola in NOMBRES_CONSOLA:
		var nodo := modelo.find_child(consola, true, false)
		if not nodo:
			push_warning("Cabina: falta %s en el modelo" % consola)
			continue
		for malla in nodo.find_children("*", "MeshInstance3D", true, false):
			if not String(malla.name).contains("mesa"):
				malla.create_trimesh_collision()


func _crear_luces_interiores() -> void:
	for posicion in [Vector3(-1.4, 2.7, -2.0), Vector3(1.4, 2.7, -2.0), Vector3(0, 2.7, 2.0)]:
		var luz := OmniLight3D.new()
		luz.position = posicion
		luz.light_color = Color("#DDF4FF")
		luz.light_energy = 0.9
		luz.omni_range = 6.0
		_interior.add_child(luz)


func _armar_plataforma() -> void:
	var cielo := ProceduralSkyMaterial.new()
	cielo.sky_top_color = Color("#3D7FD9")
	cielo.sky_horizon_color = Color("#BFE3F5")
	cielo.ground_horizon_color = Color("#9DB0A0")
	cielo.ground_bottom_color = Color("#4E5A48")
	_entorno(Environment.BG_SKY, cielo, Color.BLACK)
	_sol(Vector3(-35, -40, 0), 1.2)

	var plataforma := MODELO_PLATAFORMA.instantiate()
	add_child(plataforma)
	# Los brazos de la torre atravesarían la nave: en esta vista ya están retirados.
	for brazo in plataforma.find_children("torre_brazo_*", "", true, false):
		brazo.visible = false
	# La cabina queda arriba del cohete elegido, mirando hacia la torre.
	_interior.position = Vector3(2.5, _altura_carga(), 0)
	_interior.rotation_degrees.y = 60


func _armar_orbita() -> void:
	_entorno(Environment.BG_COLOR, null, Color("#04071A"))
	_sol(Vector3(-20, 60, 0), 1.4)
	_crear_estrellas()

	if GameState.tiene_viaje():
		_armar_viaje()
		return
	var destino: String = GameState.mision.get("destino", "tierra")
	_planeta = Node3D.new()
	_planeta.position = Vector3(-60, -105, -320)
	add_child(_planeta)
	_planeta.add_child(_esfera(150, COLOR_PLANETA.get(destino, Color.GRAY), 32))
	if destino == "tierra":
		var atmosfera := _esfera(156, Color(Interfaz.CIAN, 0.18), 32)
		var material := atmosfera.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_planeta.add_child(atmosfera)


## En el viaje se ven las dos: la Tierra se aleja y la Luna se acerca con el progreso.
func _armar_viaje() -> void:
	_tierra = Node3D.new()
	add_child(_tierra)
	_tierra.add_child(_esfera(150, COLOR_PLANETA["tierra"], 32))
	var atmosfera := _esfera(156, Color(Interfaz.CIAN, 0.18), 32)
	var material := atmosfera.material_override as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tierra.add_child(atmosfera)
	_luna = Node3D.new()
	add_child(_luna)
	_luna.add_child(_esfera(150, COLOR_PLANETA["luna"], 32))
	_actualizar_ventana_viaje()


func _actualizar_ventana_viaje() -> void:
	if not _tierra:
		return
	var t := GameState.progreso_viaje()
	_tierra.position = TIERRA_INICIO.lerp(TIERRA_FIN, t)
	_tierra.scale = Vector3.ONE * lerpf(1.0, 0.25, t)
	# La Luna crece cada vez más rápido al acercarse.
	var cerca := t * t
	_luna.position = LUNA_INICIO.lerp(LUNA_FIN, cerca)
	_luna.scale = Vector3.ONE * lerpf(0.12, 1.0, cerca)


func _entorno(fondo: Environment.BGMode, cielo: Material, color: Color) -> void:
	var entorno := Environment.new()
	entorno.background_mode = fondo
	entorno.background_color = color
	if cielo:
		entorno.sky = Sky.new()
		entorno.sky.sky_material = cielo
		entorno.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	else:
		entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		entorno.ambient_light_color = Color("#2A3358")
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	entorno.glow_enabled = true
	var nodo := WorldEnvironment.new()
	nodo.environment = entorno
	add_child(nodo)


func _sol(rotacion: Vector3, energia: float) -> void:
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = rotacion
	sol.light_energy = energia
	sol.shadow_enabled = true
	add_child(sol)


func _crear_estrellas() -> void:
	var malla := QuadMesh.new()
	malla.size = Vector2(1.5, 1.5)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Interfaz.BLANCO
	malla.material = material
	var multimalla := MultiMesh.new()
	multimalla.transform_format = MultiMesh.TRANSFORM_3D
	multimalla.mesh = malla
	multimalla.instance_count = 700
	var azar := RandomNumberGenerator.new()
	azar.seed = 42
	for i in multimalla.instance_count:
		var direccion := Vector3(azar.randfn(), azar.randfn(), azar.randfn()).normalized()
		multimalla.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * azar.randf_range(0.5, 1.5)), direccion * 700))
	var estrellas := MultiMeshInstance3D.new()
	estrellas.multimesh = multimalla
	add_child(estrellas)


func _esfera(radio: float, color: Color, segmentos: int) -> MeshInstance3D:
	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2
	malla.radial_segments = segmentos
	malla.rings = segmentos / 2
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	var instancia := MeshInstance3D.new()
	instancia.mesh = malla
	instancia.material_override = material
	return instancia


## Altura del punto donde va la nave en el cohete elegido (la toma del modelo de Blender).
func _altura_carga() -> float:
	var id: String = GameState.pieza_elegida("cohete").get("id", "cohete_mediano")
	var cohetes := MODELO_COHETES.instantiate()
	var marcador := cohetes.find_child(id + "_carga", true, false) as Node3D
	var altura := marcador.position.y if marcador else 20.0
	cohetes.free()
	return altura


# --- Textos en las pantallas de las consolas --------------------------------

func _crear_textos_consola() -> void:
	for consola in PANTALLAS:
		var datos: Array = PANTALLAS[consola]
		var texto := Label3D.new()
		texto.position = datos[0]
		texto.rotation_degrees = Vector3(datos[2], datos[1], 0)
		texto.pixel_size = 0.002
		texto.font_size = 32
		texto.outline_size = 0
		texto.width = datos[3]
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto.modulate = Interfaz.CIAN
		_interior.add_child(texto)
		_textos_consola[consola] = texto


func _crear_marcador() -> void:
	_marcador = Label3D.new()
	_marcador.position = POSICION_MARCADOR
	_marcador.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marcador.no_depth_test = true
	_marcador.pixel_size = 0.002
	_marcador.font_size = 48
	_marcador.outline_size = 12
	_marcador.outline_modulate = Interfaz.FONDO
	_interior.add_child(_marcador)


## Qué dice el marcador y de qué color, según lo que toca hacer.
func _actualizar_marcador() -> void:
	var texto := "Elegir misión"
	var color := Interfaz.LIMA
	if GameState.en_orbita():
		if GameState.ops["terminada"]:
			texto = "Ver informe"
		elif not GameState.ops["evento_actual"].is_empty():
			texto = "¡Alerta!"
			color = Interfaz.ALERTA
		else:
			texto = ("Tramo %d de %d" if GameState.tiene_viaje() else "Turno %d de %d") % [GameState.ops["turno"], GameState.ops["turnos"]]
	elif not GameState.mision.is_empty():
		texto = "Diseñar y lanzar"
	_marcador.text = "[E] %s\n▼" % texto
	_marcador.modulate = color


func _actualizar_textos_consola() -> void:
	_actualizar_marcador()
	var textos := _textos_en_orbita() if GameState.en_orbita() else _textos_en_plataforma()
	for consola in textos:
		_textos_consola[consola].text = textos[consola]
	var evento: bool = GameState.en_orbita() and not GameState.ops["evento_actual"].is_empty()
	_textos_consola["consola_principal"].modulate = Interfaz.ALERTA if evento else Interfaz.CIAN


func _textos_en_plataforma() -> Dictionary:
	var mision := GameState.mision
	if mision.is_empty():
		return {
			"consola_principal": "SABERTECH\nSin misión asignada\n[E] Elegir misión",
			"consola_energia": "ENERGÍA\nEn espera",
			"consola_comunicaciones": "COMUNICACIONES\nEn espera",
			"consola_ciencia": "CIENCIA\nEn espera",
		}
	var m := GameState.medidores
	var instrumentos := []
	for pieza in GameState.piezas_elegidas("instrumento"):
		instrumentos.append(pieza["nombre"])
	return {
		"consola_principal": "MISIÓN: %s\nPresupuesto %d / %d M$\n%s\n[E] Diseñar y lanzar" % [
			mision["nombre"], roundi(m["costo"]["valor"]), roundi(m["costo"]["limite"]),
			"Lista para lanzar" if GameState.puede_lanzar() else "Faltan piezas"],
		"consola_energia": "ENERGÍA\n%s\nGenera %d W · necesita %d W" % [
			GameState.pieza_elegida("energia").get("nombre", "Sin fuente"), roundi(m["energia"]["limite"]), roundi(m["energia"]["valor"])],
		"consola_comunicaciones": "COMUNICACIONES\n%s\nEnvía %d datos por turno" % [
			GameState.pieza_elegida("comunicacion").get("nombre", "Sin antena"), roundi(m["datos"]["limite"])],
		"consola_ciencia": "CIENCIA\n%s\nObjetivo: %d puntos" % [
			", ".join(instrumentos) if not instrumentos.is_empty() else "Sin instrumentos", roundi(mision["objetivo_ciencia"])],
	}


func _textos_en_orbita() -> Dictionary:
	var ops := GameState.ops
	var energia := GameState.energia_turno()
	var base := GameState.get_nave_base()
	var formato := ("TRAMO" if GameState.tiene_viaje() else "TURNO") + " %d / %d\nCiencia %d / %d\nSalud %d%%"
	var principal := formato % [
		mini(ops["turno"], ops["turnos"]), ops["turnos"], roundi(ops["ciencia"]), roundi(GameState.mision["objetivo_ciencia"]), roundi(ops["salud"])]
	if not ops["evento_actual"].is_empty():
		principal += "\n¡ALERTA: %s!" % ops["evento_actual"]["titulo"]
	elif ops["terminada"]:
		principal += "\nMisión terminada · [E] Informe"
	var instrumentos := []
	for pieza in GameState.piezas_elegidas("instrumento"):
		var estado := "ROTO" if GameState.esta_rota(pieza["id"]) else ("ON" if GameState.plan["instrumentos"].get(pieza["id"], false) else "OFF")
		instrumentos.append("%s: %s" % [pieza["nombre"], estado])
	return {
		"consola_principal": principal,
		"consola_energia": "ENERGÍA\nGenera %d W\nBatería %d / %d\nUsando %d W" % [
			roundi(energia["generacion"]), roundi(ops["bateria"]), roundi(base["bateria"]), roundi(energia["consumo"])],
		"consola_comunicaciones": "COMUNICACIONES\nMemoria %d / %d\nEnvío %d por turno\nTransmitir: %s" % [
			roundi(GameState.datos_almacenados()), roundi(base["almacenamiento"]), roundi(GameState.capacidad_transmision()),
			"SÍ" if GameState.plan["transmitir"] else "NO"],
		"consola_ciencia": "CIENCIA\n" + ("\n".join(instrumentos) if not instrumentos.is_empty() else "Sin instrumentos"),
	}


# --- HUD --------------------------------------------------------------------

func _crear_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	_mira = ColorRect.new()
	(_mira as ColorRect).color = Color(Interfaz.BLANCO, 0.8)
	_mira.size = Vector2(4, 4)
	_mira.set_anchors_preset(Control.PRESET_CENTER)
	_mira.position -= Vector2(2, 2)
	_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_mira)

	_indicacion = Interfaz.etiqueta("", Interfaz.BLANCO, 20)
	_indicacion.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_indicacion.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_indicacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicacion.offset_top = 30
	hud.add_child(_indicacion)

	_objetivo = Interfaz.etiqueta("", Interfaz.CIAN, 18)
	_objetivo.position = Vector2(16, 12)
	hud.add_child(_objetivo)

	_mensaje = Interfaz.parrafo("", Interfaz.LIMA, 20)
	_mensaje.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_mensaje.custom_minimum_size.x = 700
	_mensaje.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.offset_top = 60
	hud.add_child(_mensaje)

	var controles := Interfaz.etiqueta("WASD: caminar · Mouse: mirar · E o clic: usar · Mantener E: puertas · F: comer · Esc: soltar el mouse", Color(Interfaz.CIAN, 0.7), 14)
	controles.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controles.position += Vector2(16, -28)
	hud.add_child(controles)

	_capa_pantalla = CanvasLayer.new()
	_capa_pantalla.layer = 5
	add_child(_capa_pantalla)

	# La tripulación va por encima de las pantallas: el reloj corre aunque haya una abierta.
	_tripulacion = HudTripulacion.new()
	_tripulacion.en_cabina = true
	add_child(_tripulacion)


func _actualizar_hud() -> void:
	var consola := _jugador.consola_mirada() if _jugador.activo else ""
	_indicacion.text = "[E] " + NOMBRES_CONSOLA[consola] if consola != "" else ""
	if GameState.mision.is_empty():
		_objetivo.text = "Objetivo: elegí una misión en la computadora de misión."
	elif not GameState.en_orbita():
		_objetivo.text = "Objetivo: diseñá la nave y lanzala desde la computadora de misión."
	elif GameState.ops["terminada"]:
		_objetivo.text = "Misión terminada: el informe está en cualquier consola."
	elif GameState.tiene_viaje():
		_objetivo.text = "Objetivo: llegá a la Luna con la tripulación entera (tramo %d de %d)." % [GameState.ops["turno"], GameState.ops["turnos"]]
	else:
		_objetivo.text = "Objetivo: operá la nave (turno %d de %d). Cualquier consola sirve." % [GameState.ops["turno"], GameState.ops["turnos"]]


func _on_operaciones_terminadas(motivo: String) -> void:
	if MENSAJES_FIN.has(motivo):
		_mostrar_mensaje(MENSAJES_FIN[motivo])


func _mostrar_mensaje(texto: String) -> void:
	_mensaje.text = texto
	_mensaje.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(_mensaje, "modulate:a", 0.0, 1.0)
