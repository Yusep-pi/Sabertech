extends Node3D
## Esclusa: la sala donde el astronauta se pone el traje antes de salir.
## Se llega desde el habitáculo (puerta interior) y lleva a la caminata espacial.
##
## Ida: armario (ponerse el traje) → panel de la escotilla (despresurizar y abrir)
## → salir por la escotilla → caminata espacial.
## Vuelta: entrar → panel (cerrar y presurizar) → armario (quitarse el traje)
## → puerta interior, de vuelta al habitáculo.
## Por el ventanal se ve el exterior: en órbita, el espacio y la nave; en la
## plataforma, el cielo (y la escotilla no se abre: salir es solo en órbita).
##
## Se prueba sola: abrir scenes/esclusa/esclusa.tscn y pulsar F6.

const MODELO := preload("res://assets/modelos/esclusa.glb")
const Jugador := preload("res://scenes/cabina/jugador.gd")
const ESCENA_CAMINATA := "res://scenes/eva/eva.tscn"

const NOMBRES := {
	"consola_armario": "Armario del traje",
	"consola_escotilla": "Panel de la escotilla",
}
## La puerta interior, hacia el habitáculo.
const PUERTA_INTERIOR := Vector3(0, 1.15, 2.98)
## Coordenadas en Godot (las de Blender giradas: x, z, -y).
const CENTRO_ESCOTILLA := Vector3(0, 1.2, -3.0)
const PANTALLA_ESCOTILLA := Vector3(1.45, 1.52, -2.82)
const BALIZA := Vector3(0, 2.6, -2.85)
const APERTURA := 1.75  # metros que se corre la hoja al abrir
const PRESION := 101.0  # kPa
const SEGUNDOS_CICLO := 5.0
const LUZ_NORMAL := Color("#DDF4FF")
const LUZ_ALARMA := Color("#FF3B2E")

## "sin_traje", "con_traje", "despresurizando", "abierta", "presurizando".
var estado := "sin_traje"
var presion := PRESION
## Si se entró desde la caminata: cambian los objetivos (cerrar, presurizar, sacarse el traje).
var _volvio := false

var _jugador: Jugador
var _puerta: Node3D
var _cerrada := Vector3.ZERO  # posición de la hoja cerrada
var _traje: Node3D
var _luces: Array = []
var _baliza: SpotLight3D
var _vapor: GPUParticles3D
var _texto_panel: Label3D

var _mira: Control
var _indicacion: Label
var _objetivo: Label
var _mensaje: Label
var _visor: Control
var _estado_traje: Label
var _barra_presion: ProgressBar
var _texto_presion: Label
var _fundido: ColorRect


func _ready() -> void:
	_armar_exterior()
	var modelo := MODELO.instantiate()
	add_child(modelo)
	_preparar_modelo(modelo)
	_crear_luces()
	_crear_hud()

	_jugador = Jugador.new()
	_jugador.consola_usada.connect(_usar)
	add_child(_jugador)
	_crear_compuerta()
	# Con el traje no se come: las raciones se comen en el habitáculo o en la cabina.
	var tripulacion := HudTripulacion.new()
	tripulacion.ubicacion = HudTripulacion.TIRA_ABAJO
	tripulacion.permitir_comer = false
	add_child(tripulacion)

	if GameState.vuelve_de_caminata:
		# Volvemos de afuera: con el traje puesto, la escotilla abierta y la sala sin aire.
		GameState.vuelve_de_caminata = false
		_volvio = true
		_visor.visible = true
		estado = "abierta"
		presion = 0.0
		_traje.visible = false
		_puerta.position = _cerrada + Vector3(APERTURA, 0, 0)
		_poner_alarma(true)
		_jugador.position = Vector3(0, 0.05, -1.8)
		_jugador.mirar_hacia(PANTALLA_ESCOTILLA)
		_mostrar_mensaje("De vuelta adentro. Cerrá la escotilla desde el panel para presurizar.")
	elif GameState.origen_transicion == "habitaculo":
		_jugador.position = Vector3(0, 0.05, 2.0)
		_jugador.mirar_hacia(CENTRO_ESCOTILLA)
		_mostrar_mensaje("Esclusa. Para salir, primero ponete el traje: está colgado en el armario.")
	else:
		_jugador.position = Vector3(-0.4, 0.05, 1.9)
		_jugador.mirar_hacia(CENTRO_ESCOTILLA)
		_mostrar_mensaje("Esclusa. Para salir, primero ponete el traje: está colgado en el armario.")
	GameState.origen_transicion = ""
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_actualizar_hud()


func _process(delta: float) -> void:
	if _baliza.visible:
		_baliza.rotate_y(delta * 4.0)
	_actualizar_hud()
	# Con la escotilla abierta, cruzar el umbral es salir.
	if estado == "abierta" and not _volvio and _jugador.position.z < CENTRO_ESCOTILLA.z + 0.35 and absf(_jugador.position.x) < 0.8:
		_salir()


func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and evento.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()


# --- Acciones ---------------------------------------------------------------

func _usar(consola: String) -> void:
	match consola:
		"consola_armario":
			if estado == "sin_traje":
				_ponerse_traje()
			elif estado == "con_traje":
				_quitarse_traje()
			else:
				_mostrar_mensaje("Con la esclusa sin aire no te podés sacar el traje.")
		"consola_escotilla":
			if estado == "sin_traje":
				_mostrar_mensaje("¡Sin traje no! Abrir la escotilla vacía la esclusa. Ponete el traje primero.")
			elif estado == "con_traje":
				if en_plataforma():
					_mostrar_mensaje("La nave todavía está en la plataforma: las caminatas espaciales son en órbita.")
				else:
					_despresurizar()
			elif estado == "abierta":
				_presurizar()


## Hay una misión en curso y la nave sigue en la plataforma (en la prueba suelta, sin misión, se puede salir).
func en_plataforma() -> bool:
	return not GameState.mision.is_empty() and not GameState.en_orbita()


## La puerta interior lleva al habitáculo, con la esclusa presurizada y sin el traje puesto.
func _crear_compuerta() -> void:
	var compuerta := Compuerta.new()
	compuerta.jugador = _jugador
	compuerta.agregar(func() -> bool: return _jugador.position.z > 2.2 and absf(_jugador.position.x) < 1.0,
		"Ir al habitáculo", "habitaculo", "esclusa", _motivo_puerta_cerrada)
	add_child(compuerta)


func _motivo_puerta_cerrada() -> String:
	if presion < PRESION:
		return "La puerta no abre: del otro lado hay aire y acá no."
	if estado != "sin_traje":
		return "Sacate el traje en el armario antes de volver a la nave."
	return ""


func _ponerse_traje() -> void:
	_jugador.activo = false
	await _fundir(1.0, "Poniéndote el traje...")
	_traje.visible = false
	_visor.visible = true
	estado = "con_traje"
	await _fundir(0.0)
	_jugador.activo = true
	_mostrar_mensaje("Traje sellado. Ahora usá el panel de la escotilla para despresurizar y abrir.")


func _quitarse_traje() -> void:
	_jugador.activo = false
	await _fundir(1.0, "Sacándote el traje...")
	_traje.visible = true
	_visor.visible = false
	estado = "sin_traje"
	_volvio = false
	await _fundir(0.0)
	_jugador.activo = true
	_mostrar_mensaje("Bienvenido de vuelta. Misión afuera terminada.")


## Alarma, la presión baja, el aire se va por la ventilación y la escotilla se abre.
func _despresurizar() -> void:
	estado = "despresurizando"
	_poner_alarma(true)
	_vapor.emitting = true
	var tween := create_tween()
	tween.tween_property(self, "presion", 0.0, SEGUNDOS_CICLO)
	await tween.finished
	_vapor.emitting = false
	var abrir := create_tween().set_trans(Tween.TRANS_SINE)
	abrir.tween_property(_puerta, "position", _cerrada + Vector3(APERTURA, 0, 0), 1.5)
	await abrir.finished
	estado = "abierta"
	_mostrar_mensaje("Escotilla abierta. Salí cuando quieras.")


func _presurizar() -> void:
	estado = "presurizando"
	var cerrar := create_tween().set_trans(Tween.TRANS_SINE)
	cerrar.tween_property(_puerta, "position", _cerrada, 1.5)
	await cerrar.finished
	var tween := create_tween()
	tween.tween_property(self, "presion", PRESION, SEGUNDOS_CICLO)
	await tween.finished
	_poner_alarma(false)
	estado = "con_traje"
	_mostrar_mensaje("Esclusa presurizada. Ya te podés sacar el traje en el armario.")


func _salir() -> void:
	estado = "saliendo"
	_jugador.activo = false
	await _fundir(1.0, "Saliendo al espacio...")
	get_tree().change_scene_to_file(ESCENA_CAMINATA)


func _poner_alarma(encendida: bool) -> void:
	_baliza.visible = encendida
	for luz in _luces:
		create_tween().tween_property(luz, "light_color", LUZ_ALARMA if encendida else LUZ_NORMAL, 0.6)


## Lleva la pantalla a negro (1) o la devuelve (0), con un texto opcional en el medio.
func _fundir(hasta: float, texto := "") -> void:
	_fundido.get_child(0).text = texto
	var tween := create_tween()
	tween.tween_property(_fundido, "color:a", hasta, 0.6)
	await tween.finished
	if hasta > 0.0:
		await get_tree().create_timer(0.5).timeout


# --- Armado -----------------------------------------------------------------

func _preparar_modelo(modelo: Node) -> void:
	_puerta = modelo.find_child("escotilla_puerta", true, false)
	_cerrada = _puerta.position
	_traje = modelo.find_child("traje", true, false)
	var vidrio := modelo.find_child("esclusa_vidrio", true, false) as MeshInstance3D
	if vidrio:
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(Interfaz.CIAN, 0.06)
		vidrio.material_override = material
	# Lo que se usa con E también tiene que poder mirarse: le damos colisión.
	for consola in NOMBRES:
		var nodo := modelo.find_child(consola, true, false)
		for malla in nodo.find_children("*", "MeshInstance3D", true, false):
			if not String(malla.name).ends_with("-col") and malla.get_child_count() == 0:
				malla.create_trimesh_collision()

	_texto_panel = Label3D.new()
	_texto_panel.position = PANTALLA_ESCOTILLA
	_texto_panel.pixel_size = 0.0012
	_texto_panel.font_size = 28
	_texto_panel.width = 380
	_texto_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto_panel.modulate = Interfaz.CIAN
	add_child(_texto_panel)


func _armar_exterior() -> void:
	if en_plataforma():
		_armar_cielo()
		return
	add_child(Espacio.entorno())
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-25, -70, 0)
	sol.light_energy = 1.3
	sol.shadow_enabled = true
	add_child(sol)
	add_child(Espacio.estrellas(900, 1500))
	# La Tierra abajo a la izquierda, a la vista desde el ventanal.
	var planeta := Espacio.planeta(GameState.mision.get("destino", "tierra"), 600)
	planeta.position = Vector3(-700, -520, 150)
	add_child(planeta)
	# Un ala de la nave, afuera del ventanal.
	var nave := Nave3D.new()
	nave.scale = Vector3.ONE * 4.0
	nave.position = Vector3(-14, -6, -10)
	nave.rotation_degrees = Vector3(0, 20, 0)
	add_child(nave)
	var ids: Array = GameState.seleccion if not GameState.seleccion.is_empty() else GameState.datos.get("eva", {}).get("nave_por_defecto", [])
	nave.mostrar(ids)


## Antes del lanzamiento, por el ventanal se ve el cielo de la plataforma.
func _armar_cielo() -> void:
	var cielo := ProceduralSkyMaterial.new()
	cielo.sky_top_color = Color("#3D7FD9")
	cielo.sky_horizon_color = Color("#BFE3F5")
	cielo.ground_horizon_color = Color("#9DB0A0")
	cielo.ground_bottom_color = Color("#4E5A48")
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_SKY
	entorno.sky = Sky.new()
	entorno.sky.sky_material = cielo
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var nodo := WorldEnvironment.new()
	nodo.environment = entorno
	add_child(nodo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, -40, 0)
	sol.light_energy = 1.2
	sol.shadow_enabled = true
	add_child(sol)


func _crear_luces() -> void:
	for posicion in [Vector3(0, 2.7, 1.6), Vector3(0, 2.7, -1.0)]:
		var luz := OmniLight3D.new()
		luz.position = posicion
		luz.light_color = LUZ_NORMAL
		luz.light_energy = 1.0
		luz.omni_range = 6.0
		add_child(luz)
		_luces.append(luz)

	_baliza = SpotLight3D.new()
	_baliza.position = BALIZA
	_baliza.rotation_degrees = Vector3(-20, 0, 0)
	_baliza.light_color = Interfaz.ALERTA
	_baliza.light_energy = 6.0
	_baliza.spot_range = 8.0
	_baliza.spot_angle = 35.0
	_baliza.visible = false
	add_child(_baliza)

	# El aire que se va por la ventilación del techo.
	var proceso := ParticleProcessMaterial.new()
	proceso.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proceso.emission_box_extents = Vector3(0.3, 0.05, 0.25)
	proceso.direction = Vector3(0, -1, 0)
	proceso.spread = 30.0
	proceso.initial_velocity_min = 0.4
	proceso.initial_velocity_max = 1.0
	proceso.gravity = Vector3(0, 0.5, 0)
	proceso.scale_min = 0.5
	proceso.scale_max = 1.2
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1, 1, 1, 0.35)
	material.albedo_texture = Espacio.textura_bocanada()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	quad.material = material
	_vapor = GPUParticles3D.new()
	_vapor.amount = 50
	_vapor.lifetime = 2.0
	_vapor.process_material = proceso
	_vapor.draw_pass_1 = quad
	_vapor.position = Vector3(0.9, 2.9, -2.08)
	_vapor.emitting = false
	add_child(_vapor)


# --- HUD --------------------------------------------------------------------

func _crear_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	_visor = Interfaz.visor_casco()
	_visor.visible = false
	hud.add_child(_visor)

	_mira = ColorRect.new()
	(_mira as ColorRect).color = Color(Interfaz.BLANCO, 0.8)
	_mira.size = Vector2(4, 4)
	_mira.set_anchors_preset(Control.PRESET_CENTER)
	_mira.position -= Vector2(2, 2)
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

	_estado_traje = Interfaz.etiqueta("", Interfaz.LIMA, 16)
	_estado_traje.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_estado_traje.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_estado_traje.position += Vector2(-20, 12)
	_estado_traje.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(_estado_traje)

	var presion_caja := Interfaz.vbox(4)
	presion_caja.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	presion_caja.grow_horizontal = Control.GROW_DIRECTION_BOTH
	presion_caja.custom_minimum_size.x = 360
	presion_caja.offset_top = 110
	hud.add_child(presion_caja)
	_texto_presion = Interfaz.etiqueta("", Interfaz.ALERTA, 20)
	_texto_presion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	presion_caja.add_child(_texto_presion)
	_barra_presion = Interfaz.barra(Interfaz.ALERTA, PRESION)
	presion_caja.add_child(_barra_presion)

	_mensaje = Interfaz.parrafo("", Interfaz.LIMA, 20)
	_mensaje.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_mensaje.custom_minimum_size.x = 760
	_mensaje.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.offset_top = 52
	hud.add_child(_mensaje)

	var controles := Interfaz.etiqueta("WASD: caminar · Mouse: mirar · E o clic: usar · Mantener E: puertas · Esc: soltar el mouse", Color(Interfaz.CIAN, 0.7), 14)
	controles.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controles.position += Vector2(16, -28)
	hud.add_child(controles)

	_fundido = ColorRect.new()
	_fundido.color = Color(0, 0, 0, 0)
	_fundido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(_fundido)
	var texto_fundido := Interfaz.etiqueta("", Interfaz.BLANCO, 26)
	texto_fundido.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	texto_fundido.grow_horizontal = Control.GROW_DIRECTION_BOTH
	texto_fundido.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fundido.add_child(texto_fundido)

	# Con el mouse capturado, todo movimiento cae en el centro: nada del HUD lo atrapa.
	for control in hud.find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _actualizar_hud() -> void:
	var consola := _jugador.consola_mirada() if _jugador.activo else ""
	_indicacion.text = "[E] %s" % _accion(consola) if consola != "" and _accion(consola) != "" else ""

	match estado:
		"sin_traje":
			_objetivo.text = "Objetivo: ponete el traje (armario a la derecha)."
		"con_traje":
			_objetivo.text = "Objetivo: sacate el traje en el armario." if _volvio else "Objetivo: despresurizá y abrí la escotilla desde su panel."
		"despresurizando":
			_objetivo.text = "Despresurizando..."
		"abierta":
			_objetivo.text = "Objetivo: cerrá la escotilla desde el panel." if _volvio else "Objetivo: salí por la escotilla."
		"presurizando":
			_objetivo.text = "Presurizando..."

	_estado_traje.text = "Traje sellado · oxígeno de la nave" if _visor.visible else ""
	var ciclo := estado in ["despresurizando", "presurizando", "abierta"]
	_texto_presion.get_parent().visible = ciclo
	_texto_presion.text = "⚠ Presión de la esclusa: %d kPa" % roundi(presion)
	_barra_presion.value = presion

	var texto_panel := "ESCOTILLA\n"
	match estado:
		"sin_traje", "con_traje":
			texto_panel += "Cerrada · %d kPa\n[E] Despresurizar" % roundi(presion)
		"despresurizando":
			texto_panel += "DESPRESURIZANDO\n%d kPa" % roundi(presion)
		"abierta":
			texto_panel += "ABIERTA · vacío\n[E] Cerrar"
		"presurizando":
			texto_panel += "PRESURIZANDO\n%d kPa" % roundi(presion)
	_texto_panel.text = texto_panel
	_texto_panel.modulate = Interfaz.ALERTA if presion < PRESION else Interfaz.CIAN


## Qué hace E sobre cada cosa, según el momento.
func _accion(consola: String) -> String:
	match consola:
		"consola_armario":
			if estado == "sin_traje":
				return "Ponerte el traje"
			return "Sacarte el traje" if estado == "con_traje" else NOMBRES[consola]
		"consola_escotilla":
			match estado:
				"con_traje":
					return "Despresurizar y abrir"
				"abierta":
					return "Cerrar y presurizar"
				"sin_traje":
					return NOMBRES[consola]
			return ""
	return NOMBRES.get(consola, "")


func _mostrar_mensaje(texto: String) -> void:
	_mensaje.text = texto
	_mensaje.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(_mensaje, "modulate:a", 0.0, 1.0)
