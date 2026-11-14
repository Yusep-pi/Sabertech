extends Node3D
## Caminata espacial: nivel de supervivencia aparte, todavía sin integrar al juego.
##
## El astronauta sale por la escotilla con oxígeno y combustible limitados, tiene
## que arreglar varios problemas en el exterior de la nave y volver antes de
## quedarse sin aire. Cada tanto llega una lluvia de micrometeoritos: hay que
## cubrirse detrás de la nave. En la escotilla se recargan oxígeno y combustible.
## Todos los valores están en el bloque "eva" de data/datos.json.
##
## Se prueba sola: abrir scenes/eva/eva.tscn y pulsar F6.

const Astronauta := preload("res://scenes/eva/astronauta.gd")
const PanelReparacion := preload("res://scenes/eva/panel_reparacion.gd")
const RADIO_ESCOTILLA := 4.0
const ESCENA_ESCLUSA := "res://scenes/esclusa/esclusa.tscn"
## Cuánto tarda la cámara en acercarse al panel y en volver.
const ZOOM_SEGUNDOS := 0.5

var _cfg: Dictionary
var _nave: Nave3D
var _astronauta: Astronauta
var _escotilla := Vector3.ZERO
var _tareas: Array = []  # {titulo, posicion, normal, consola, panel, hecha, marcador, luz, efecto}
var _tarea_abierta: Dictionary = {}  # la tarea cuyo panel está en pantalla
var _capa_paneles: CanvasLayer
var _marcador_escotilla: Label3D
var _azar := RandomNumberGenerator.new()
var _oxigeno := 0.0  # segundos que quedan
var _traje := 100.0
var _estado := "jugando"  # "jugando", "victoria" o "derrota"
var _tiempo := 0.0

var _lluvia_fase := ""  # "", "aviso" o "activa"
var _lluvia_reloj := 0.0  # segundos hasta el próximo cambio de fase
var _lluvia_direccion := Vector3.ZERO
var _lluvia_particulas: GPUParticles3D
var _lluvia_marcador: Label3D

var _barras: Dictionary = {}  # oxigeno, combustible, traje -> {barra, texto}
var _lista_tareas: Label
var _indicacion: Label
var _alerta: Label
var _mensaje: Label
var _datos_vuelo: Label
var _golpe: ColorRect
var _fin: CanvasLayer


func _ready() -> void:
	_cfg = GameState.datos.get("eva", {})
	_oxigeno = _cfg.get("oxigeno_segundos", 240.0)
	_lluvia_reloj = _cfg["lluvia"]["primera"]

	add_child(Espacio.entorno())
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, 40, 0)
	sol.light_energy = 1.4
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 150
	add_child(sol)
	add_child(Espacio.estrellas(900, 1800))
	var planeta := Espacio.planeta(GameState.mision.get("destino", "tierra"), 700)
	planeta.position = Vector3(250, -900, -700)
	add_child(planeta)

	_armar_nave()
	_armar_escotilla()
	_armar_tareas()
	_armar_lluvia()

	_astronauta = Astronauta.new()
	_astronauta.empuje = _cfg.get("empuje", 3.0)
	_astronauta.consumo = _cfg.get("consumo_propulsor", 6.0)
	_astronauta.velocidad_maxima = _cfg.get("velocidad_maxima", 9.0)
	_astronauta.combustible = _cfg.get("combustible", 100.0)
	_astronauta.choque.connect(_on_choque)
	add_child(_astronauta)
	var afuera := Vector3(_escotilla.x, 0, _escotilla.z).normalized()
	# Arranca a unos metros de la escotilla, de cara a la nave para ubicarse.
	_astronauta.global_position = _escotilla + afuera * 9.0 + Vector3.UP * 2.0
	_astronauta.look_at(_nave.global_position)

	_crear_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mostrar_mensaje("Saliste por la escotilla. Arreglá los %d problemas y volvé antes de quedarte sin oxígeno." % _tareas.size())


func _process(delta: float) -> void:
	_animar_marcadores(delta)
	if _estado != "jugando":
		return
	_tiempo += delta
	_oxigeno -= delta

	var en_escotilla := _astronauta.global_position.distance_to(_escotilla) < RADIO_ESCOTILLA
	if en_escotilla:
		_oxigeno = minf(_oxigeno + _cfg.get("recarga_oxigeno", 40.0) * delta, _cfg.get("oxigeno_segundos", 240.0))
		_astronauta.combustible = minf(_astronauta.combustible + _cfg.get("recarga_combustible", 30.0) * delta, _cfg.get("combustible", 100.0))

	_actualizar_lluvia(delta, en_escotilla)
	_revisar_final(en_escotilla)
	_actualizar_hud(en_escotilla)


func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and evento.physical_keycode == KEY_ESCAPE:
		if not _tarea_abierta.is_empty():
			_cerrar_panel()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()


func _unhandled_input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if not tecla or not tecla.pressed or tecla.echo or tecla.physical_keycode != KEY_E:
		return
	if _estado == "jugando" and _tarea_abierta.is_empty() and not tarea_al_alcance().is_empty():
		_abrir_panel(tarea_al_alcance())


# --- Armado -----------------------------------------------------------------

func _armar_nave() -> void:
	_nave = Nave3D.new()
	_nave.scale = Vector3.ONE * _cfg.get("escala_nave", 4.0)
	add_child(_nave)
	var ids: Array = GameState.seleccion if not GameState.seleccion.is_empty() else _cfg.get("nave_por_defecto", [])
	_nave.mostrar(ids)
	# Solo las piezas visibles chocan.
	for malla in _nave.find_children("*", "MeshInstance3D", true, false):
		if malla.is_visible_in_tree():
			malla.create_trimesh_collision()


func _armar_escotilla() -> void:
	var escotilla := _nave.find_child("nave_base_escotilla", true, false) as Node3D
	_escotilla = escotilla.global_position if escotilla else Vector3(5, 0, 0)
	var luz := OmniLight3D.new()
	luz.light_color = Interfaz.LIMA
	luz.light_energy = 2.0
	luz.omni_range = 6.0
	luz.position = _escotilla + Vector3(_escotilla.x, 0, _escotilla.z).normalized() * 1.0
	add_child(luz)
	_marcador_escotilla = _marcador_3d("Escotilla · oxígeno y combustible", _escotilla + Vector3.UP * 2.5, Interfaz.LIMA)
	add_child(_marcador_escotilla)


func _armar_tareas() -> void:
	_azar.randomize()
	_capa_paneles = CanvasLayer.new()
	_capa_paneles.layer = 2
	add_child(_capa_paneles)
	for tarea in _cfg.get("tareas", []):
		var pieza := _primera_pieza_visible(tarea["piezas"])
		if not pieza:
			continue
		var exterior := _punto_exterior(pieza)
		var normal: Vector3 = exterior[1]
		var posicion: Vector3 = exterior[0] + normal * 1.5
		var marcador := _marcador_3d("◆ " + tarea["titulo"], posicion + Vector3.UP * 1.2, Interfaz.ALERTA)
		add_child(marcador)
		var luz := OmniLight3D.new()
		luz.light_color = Interfaz.ALERTA
		luz.omni_range = 5.0
		luz.position = posicion
		add_child(luz)
		var panel := PanelReparacion.new()
		panel.visible = false
		panel.configurar(tarea, _cfg.get("tolerancia", 1.0), _azar)
		_capa_paneles.add_child(panel)
		var datos := {
			"titulo": tarea["titulo"],
			"posicion": posicion,
			"normal": normal,
			"consola": _consola_3d(exterior[0] + normal * 0.3, normal),
			"panel": panel,
			"hecha": false,
			"marcador": marcador,
			"luz": luz,
			"efecto": _efecto_tarea(tarea["id"], posicion),
		}
		panel.resuelto.connect(_on_panel_resuelto.bind(datos))
		_tareas.append(datos)


## La caja del panel de control, atornillada a la pieza y mirando hacia afuera.
func _consola_3d(posicion: Vector3, normal: Vector3) -> Node3D:
	var consola := Node3D.new()
	add_child(consola)
	consola.global_position = posicion
	var arriba := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	consola.look_at(posicion + normal, arriba)
	# Con look_at, el frente (-Z) queda mirando hacia afuera.
	for parte in [
		[Vector3(1.2, 0.8, 0.2), Vector3.ZERO, Color("#3A4466"), false],
		[Vector3(0.8, 0.5, 0.02), Vector3(-0.1, 0.05, -0.11), Interfaz.AQUA, true],
		[Vector3(0.12, 0.12, 0.05), Vector3(0.43, 0.2, -0.12), Interfaz.LIMA, true],
		[Vector3(0.12, 0.12, 0.05), Vector3(0.43, -0.05, -0.12), Interfaz.ALERTA, true],
	]:
		var malla := BoxMesh.new()
		malla.size = parte[0]
		var material := StandardMaterial3D.new()
		material.albedo_color = parte[2]
		if parte[3]:
			material.emission_enabled = true
			material.emission = parte[2]
			material.emission_energy_multiplier = 0.8
		var instancia := MeshInstance3D.new()
		instancia.mesh = malla
		instancia.material_override = material
		instancia.position = parte[1]
		consola.add_child(instancia)
	return consola


## La pieza instalada de la lista, o null si la nave no lleva ninguna.
func _primera_pieza_visible(ids: Array) -> Node3D:
	for id in ids:
		var nodo := _nave.find_child(id, true, false) as Node3D
		if nodo and nodo.visible:
			return nodo
	return null


## El punto de la pieza más alejado del centro de la nave (la punta del panel, el plato
## de la antena...) y la dirección hacia afuera: [punto, normal].
func _punto_exterior(pieza: Node3D) -> Array:
	var mejor := pieza.global_position
	for malla in pieza.find_children("*", "MeshInstance3D", true, false):
		var centro: Vector3 = malla.global_transform * malla.get_aabb().get_center()
		if centro.distance_to(_nave.global_position) > mejor.distance_to(_nave.global_position):
			mejor = centro
	return [mejor, (mejor - _nave.global_position).normalized()]


## Algo que se vea: un escombro girando sobre el panel, una fuga en el motor.
func _efecto_tarea(id: String, posicion: Vector3) -> Node3D:
	match id:
		"panel":
			var escombro := MeshInstance3D.new()
			var malla := BoxMesh.new()
			malla.size = Vector3(0.8, 0.5, 0.6)
			escombro.mesh = malla
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("#6B6F7A")
			escombro.material_override = material
			escombro.position = posicion
			add_child(escombro)
			return escombro
		"motor":
			var fuga := _chorro(posicion)
			add_child(fuga)
			return fuga
	return null


func _chorro(posicion: Vector3) -> GPUParticles3D:
	var proceso := ParticleProcessMaterial.new()
	proceso.direction = Vector3(0, -1, 0)
	proceso.spread = 25.0
	proceso.initial_velocity_min = 2.0
	proceso.initial_velocity_max = 4.0
	proceso.gravity = Vector3.ZERO
	proceso.scale_min = 0.3
	proceso.scale_max = 0.8
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1, 1, 1, 0.5)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	quad.material = material
	var chorro := GPUParticles3D.new()
	chorro.amount = 60
	chorro.lifetime = 1.5
	chorro.process_material = proceso
	chorro.draw_pass_1 = quad
	chorro.position = posicion
	return chorro


func _armar_lluvia() -> void:
	var proceso := ParticleProcessMaterial.new()
	proceso.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proceso.emission_box_extents = Vector3(35, 35, 2)
	proceso.direction = Vector3(0, 0, -1)
	proceso.spread = 2.0
	proceso.initial_velocity_min = 70.0
	proceso.initial_velocity_max = 100.0
	proceso.gravity = Vector3.ZERO
	proceso.particle_flag_align_y = true
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#FFE2B0")
	material.emission_enabled = true
	material.emission = Interfaz.ALERTA
	var malla := BoxMesh.new()
	malla.size = Vector3(0.06, 2.0, 0.06)
	malla.material = material
	_lluvia_particulas = GPUParticles3D.new()
	_lluvia_particulas.amount = 400
	_lluvia_particulas.lifetime = 1.6
	_lluvia_particulas.process_material = proceso
	_lluvia_particulas.draw_pass_1 = malla
	_lluvia_particulas.emitting = false
	_lluvia_particulas.local_coords = false
	_lluvia_particulas.visibility_aabb = AABB(Vector3(-80, -80, -200), Vector3(160, 160, 220))
	add_child(_lluvia_particulas)

	_lluvia_marcador = _marcador_3d("☄ Micrometeoritos", Vector3.ZERO, Interfaz.ALERTA)
	_lluvia_marcador.font_size = 64
	_lluvia_marcador.visible = false
	add_child(_lluvia_marcador)


func _marcador_3d(texto: String, posicion: Vector3, color: Color) -> Label3D:
	var marcador := Label3D.new()
	marcador.text = texto
	marcador.position = posicion
	marcador.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marcador.no_depth_test = true
	marcador.fixed_size = true
	marcador.pixel_size = 0.0011
	marcador.font_size = 40
	marcador.outline_size = 10
	marcador.outline_modulate = Interfaz.FONDO
	marcador.modulate = color
	return marcador


# --- Juego ------------------------------------------------------------------

## La tarea pendiente más cercana al alcance, o {} si no hay ninguna.
func tarea_al_alcance() -> Dictionary:
	var mejor := {}
	var alcance: float = _cfg.get("distancia_tarea", 3.5)
	for tarea in _tareas:
		var distancia := _astronauta.global_position.distance_to(tarea["posicion"])
		if not tarea["hecha"] and distancia < alcance:
			alcance = distancia
			mejor = tarea
	return mejor


## El astronauta se engancha al panel y la cámara se acerca hasta tenerlo de frente.
func _abrir_panel(tarea: Dictionary) -> void:
	_tarea_abierta = tarea
	_mostrar_marcadores(false)
	_astronauta.activo = false
	_astronauta.velocity = Vector3.ZERO
	var camara := _astronauta.camara
	var desde := camara.global_transform
	var punto: Vector3 = tarea["consola"].global_position
	var arriba := _astronauta.global_transform.basis.y
	if absf(arriba.dot(tarea["normal"])) > 0.95:
		arriba = _astronauta.global_transform.basis.z
	var hasta := Transform3D(Basis(), punto + tarea["normal"] * 1.6).looking_at(punto, arriba)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_method(func(t: float) -> void: camara.global_transform = desde.interpolate_with(hasta, t), 0.0, 1.0, ZOOM_SEGUNDOS)
	tween.tween_property(camara, "fov", 55.0, ZOOM_SEGUNDOS)
	await tween.finished
	if _tarea_abierta == tarea:
		tarea["panel"].visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Suelta el panel: la cámara vuelve a los ojos del astronauta. Lo ajustado queda como está.
func _cerrar_panel() -> void:
	if _tarea_abierta.is_empty():
		return
	_tarea_abierta["panel"].visible = false
	_tarea_abierta = {}
	_mostrar_marcadores(true)
	var camara := _astronauta.camara
	var desde := _astronauta.global_transform.affine_inverse() * camara.global_transform
	var hasta := Transform3D(Basis(), Vector3(0, 0.6, 0))
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_method(func(t: float) -> void: camara.transform = desde.interpolate_with(hasta, t), 0.0, 1.0, ZOOM_SEGUNDOS)
	tween.tween_property(camara, "fov", 80.0, ZOOM_SEGUNDOS)
	await tween.finished
	if _estado == "jugando" and _tarea_abierta.is_empty():
		_astronauta.activo = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Los carteles 3D se ven a través de todo: con un panel abierto, molestan.
func _mostrar_marcadores(visibles: bool) -> void:
	_marcador_escotilla.visible = visibles
	for tarea in _tareas:
		tarea["marcador"].visible = visibles


func _on_panel_resuelto(tarea: Dictionary) -> void:
	tarea["hecha"] = true
	tarea["marcador"].text = "✓ " + tarea["titulo"]
	tarea["marcador"].modulate = Interfaz.LIMA
	tarea["luz"].light_color = Interfaz.LIMA
	if tarea["efecto"]:
		tarea["efecto"].queue_free()
		tarea["efecto"] = null
	_cerrar_panel()
	var faltan := tareas_pendientes()
	_mostrar_mensaje("¡Funciona! " + ("Volvé a la escotilla." if faltan == 0 else "Quedan %d problemas." % faltan))


func tareas_pendientes() -> int:
	var faltan := 0
	for tarea in _tareas:
		if not tarea["hecha"]:
			faltan += 1
	return faltan


func _actualizar_lluvia(delta: float, en_escotilla: bool) -> void:
	_lluvia_reloj -= delta
	var lluvia: Dictionary = _cfg["lluvia"]
	if _lluvia_fase == "" and _lluvia_reloj <= lluvia["aviso"]:
		iniciar_aviso_lluvia()
	elif _lluvia_fase == "aviso" and _lluvia_reloj <= 0.0:
		_lluvia_fase = "activa"
		_lluvia_reloj = lluvia["duracion"]
		_lluvia_particulas.emitting = true
	elif _lluvia_fase == "activa":
		if _lluvia_reloj <= 0.0:
			_lluvia_fase = ""
			_lluvia_reloj = randf_range(lluvia["cada_min"], lluvia["cada_max"])
			_lluvia_particulas.emitting = false
			_lluvia_marcador.visible = false
			_mostrar_mensaje("Pasó la lluvia de micrometeoritos.")
		elif not en_escotilla and expuesto_a_la_lluvia():
			_traje -= lluvia["dano_por_segundo"] * delta
			_golpe.color.a = maxf(_golpe.color.a, 0.18)

	# La lluvia viene siempre desde la misma dirección y rodea al astronauta.
	if _lluvia_fase != "":
		var origen := _astronauta.global_position + _lluvia_direccion * 70.0
		_lluvia_particulas.global_position = origen
		_lluvia_particulas.look_at(_astronauta.global_position)
		_lluvia_marcador.global_position = _astronauta.global_position + _lluvia_direccion * 25.0


func iniciar_aviso_lluvia() -> void:
	_lluvia_fase = "aviso"
	_lluvia_reloj = _cfg["lluvia"]["aviso"]
	# Viene de un costado de la nave, para que siempre haya dónde cubrirse.
	var angulo := randf() * TAU
	_lluvia_direccion = Vector3(cos(angulo), randf_range(-0.3, 0.3), sin(angulo)).normalized()
	_lluvia_marcador.visible = true


## Si entre el astronauta y la lluvia no hay ninguna parte de la nave.
func expuesto_a_la_lluvia() -> bool:
	var consulta := PhysicsRayQueryParameters3D.create(
		_astronauta.global_position, _astronauta.global_position + _lluvia_direccion * 80.0)
	consulta.exclude = [_astronauta.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()


func _on_choque(velocidad: float) -> void:
	var segura: float = _cfg.get("velocidad_segura", 2.5)
	if velocidad > segura and _estado == "jugando":
		_traje -= (velocidad - segura) * _cfg.get("dano_por_choque", 8.0)
		_golpe.color.a = 0.5
		_mostrar_mensaje("¡Golpe a %.1f m/s! El traje se dañó. Frená con X antes de llegar." % velocidad)


func _revisar_final(en_escotilla: bool) -> void:
	var distancia := _astronauta.global_position.distance_to(_nave.global_position)
	if _oxigeno <= 0.0:
		_terminar(false, "Te quedaste sin oxígeno.")
	elif _traje <= 0.0:
		_terminar(false, "El traje no resistió más daño.")
	elif distancia > _cfg.get("distancia_maxima", 90.0) and _astronauta.combustible <= 0.0:
		_terminar(false, "Quedaste a la deriva, sin combustible para volver.")
	elif tareas_pendientes() == 0 and en_escotilla:
		_terminar(true, "Todos los problemas resueltos y de vuelta en la nave.")


func _terminar(victoria: bool, motivo: String) -> void:
	_estado = "victoria" if victoria else "derrota"
	if not _tarea_abierta.is_empty():
		_tarea_abierta["panel"].visible = false
		_tarea_abierta = {}
	_astronauta.activo = false
	_lluvia_particulas.emitting = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var capa := CanvasLayer.new()
	capa.layer = 3
	add_child(capa)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(centro)
	var panel := Interfaz.panel(Interfaz.PANEL, 24)
	panel.custom_minimum_size.x = 560
	centro.add_child(panel)
	var caja := Interfaz.vbox(14)
	panel.add_child(caja)
	caja.add_child(Interfaz.etiqueta("¡Caminata completada!" if victoria else "Caminata fallida", Interfaz.LIMA if victoria else Interfaz.ALERTA, 30))
	caja.add_child(Interfaz.parrafo(motivo, Interfaz.BLANCO, 18))
	caja.add_child(Interfaz.parrafo("Tiempo afuera: %d:%02d · Oxígeno restante: %d s · Traje: %d%% · Problemas resueltos: %d de %d" % [
		int(_tiempo) / 60, int(_tiempo) % 60, maxi(0, roundi(_oxigeno)), maxi(0, roundi(_traje)),
		_tareas.size() - tareas_pendientes(), _tareas.size()], Interfaz.CIAN, 16))
	var botones := Interfaz.hbox(12)
	caja.add_child(botones)
	# Ganando se vuelve a entrar por la escotilla; perdiendo se empieza de nuevo desde la esclusa.
	var esclusa := Interfaz.boton_principal("Volver a la esclusa" if victoria else "Reintentar desde la esclusa", 20)
	esclusa.pressed.connect(func() -> void:
		GameState.vuelve_de_caminata = victoria
		get_tree().change_scene_to_file(ESCENA_ESCLUSA))
	botones.add_child(esclusa)
	var repetir := Interfaz.boton("Repetir la caminata", 20)
	repetir.pressed.connect(func() -> void: get_tree().reload_current_scene())
	botones.add_child(repetir)
	_fin = capa


func _animar_marcadores(delta: float) -> void:
	var parpadeo := 1.5 + sin(Time.get_ticks_msec() / 200.0) * 1.2
	for tarea in _tareas:
		if not tarea["hecha"]:
			tarea["luz"].light_energy = parpadeo
		if tarea["efecto"] is MeshInstance3D:
			tarea["efecto"].rotate(Vector3(1, 0.6, 0.3).normalized(), delta * 0.8)
	if _golpe:
		_golpe.color.a = move_toward(_golpe.color.a, 0.0, delta * 0.8)


# --- HUD del casco ----------------------------------------------------------

func _crear_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	hud.add_child(Interfaz.visor_casco())

	_golpe = ColorRect.new()
	_golpe.color = Color(Interfaz.ALERTA, 0.0)
	_golpe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_golpe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_golpe)

	var recursos := Interfaz.vbox(4)
	recursos.position = Vector2(24, 20)
	recursos.custom_minimum_size.x = 260
	hud.add_child(recursos)
	for clave in ["oxigeno", "combustible", "traje"]:
		var texto := Interfaz.etiqueta("", Interfaz.BLANCO, 16)
		var barra := Interfaz.barra(Interfaz.AQUA)
		recursos.add_child(texto)
		recursos.add_child(barra)
		_barras[clave] = {"texto": texto, "barra": barra}

	_lista_tareas = Interfaz.etiqueta("", Interfaz.CIAN, 16)
	_lista_tareas.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_lista_tareas.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_lista_tareas.position += Vector2(-24, 20)
	_lista_tareas.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(_lista_tareas)

	var mira := ColorRect.new()
	mira.color = Color(Interfaz.BLANCO, 0.8)
	mira.size = Vector2(4, 4)
	mira.set_anchors_preset(Control.PRESET_CENTER)
	mira.position -= Vector2(2, 2)
	hud.add_child(mira)

	var centro := Interfaz.vbox(6)
	centro.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	centro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	centro.offset_top = 40
	centro.custom_minimum_size.x = 420
	hud.add_child(centro)
	_indicacion = Interfaz.etiqueta("", Interfaz.BLANCO, 20)
	_indicacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centro.add_child(_indicacion)

	_alerta = Interfaz.etiqueta("", Interfaz.ALERTA, 26)
	_alerta.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_alerta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_alerta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alerta.offset_top = 110
	hud.add_child(_alerta)

	_mensaje = Interfaz.parrafo("", Interfaz.LIMA, 18)
	_mensaje.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_mensaje.custom_minimum_size.x = 700
	_mensaje.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.offset_top = 160
	hud.add_child(_mensaje)

	_datos_vuelo = Interfaz.etiqueta("", Interfaz.CIAN, 16)
	_datos_vuelo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_datos_vuelo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_datos_vuelo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_datos_vuelo.position += Vector2(-24, -24)
	_datos_vuelo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(_datos_vuelo)

	var controles := Interfaz.etiqueta(
		"WASD: propulsar · Espacio/Ctrl: subir/bajar · Shift: turbo · X: frenar · Z/C: rotar · E: abrir panel · Esc: soltar el panel o el mouse",
		Color(Interfaz.CIAN, 0.7), 13)
	controles.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controles.position += Vector2(24, -26)
	hud.add_child(controles)

	# Con el mouse capturado, todo movimiento cae en el centro de la pantalla: si algo del HUD
	# lo atrapa (la mira, por ejemplo), el astronauta no puede mirar. Nada del casco lo atrapa.
	for control in hud.find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _actualizar_hud(en_escotilla: bool) -> void:
	var oxigeno_max: float = _cfg.get("oxigeno_segundos", 240.0)
	var combustible_max: float = _cfg.get("combustible", 100.0)
	_pintar("oxigeno", "Oxígeno: %d:%02d" % [maxi(0, int(_oxigeno)) / 60, maxi(0, int(_oxigeno)) % 60], _oxigeno / oxigeno_max, _oxigeno < 45.0)
	_pintar("combustible", "Combustible: %d%%" % roundi(_astronauta.combustible / combustible_max * 100), _astronauta.combustible / combustible_max, _astronauta.combustible < 20.0)
	_pintar("traje", "Traje: %d%%" % maxi(0, roundi(_traje)), _traje / 100.0, _traje < 35.0)

	var lineas := []
	for tarea in _tareas:
		var distancia := _astronauta.global_position.distance_to(tarea["posicion"])
		lineas.append(("✓ %s" % tarea["titulo"]) if tarea["hecha"] else ("%s · %d m  ◆" % [tarea["titulo"], roundi(distancia)]))
	if tareas_pendientes() == 0:
		lineas.append("Volvé a la escotilla · %d m" % roundi(_astronauta.global_position.distance_to(_escotilla)))
	_lista_tareas.text = "\n".join(lineas)

	var tarea := tarea_al_alcance()
	if not _tarea_abierta.is_empty():
		_indicacion.text = ""
	elif not tarea.is_empty():
		_indicacion.text = "[E] Abrir el panel · %s" % tarea["titulo"]
	elif en_escotilla:
		_indicacion.text = "Recargando oxígeno y combustible"
	else:
		_indicacion.text = ""

	match _lluvia_fase:
		"aviso":
			_alerta.text = "☄ Lluvia de micrometeoritos en %d s · cubrite detrás de la nave o entrá a la escotilla" % ceili(_lluvia_reloj)
		"activa":
			var peligro := "¡ESTÁS EXPUESTO!" if not en_escotilla and expuesto_a_la_lluvia() else "A cubierto"
			_alerta.text = "☄ Lluvia de micrometeoritos · %s · %d s" % [peligro, ceili(_lluvia_reloj)]
		_:
			_alerta.text = ""

	var distancia_nave := _astronauta.global_position.distance_to(_nave.global_position)
	_datos_vuelo.text = "Velocidad %.1f m/s\nDistancia a la nave %d m" % [_astronauta.velocity.length(), roundi(distancia_nave)]
	_datos_vuelo.modulate = Interfaz.ALERTA if distancia_nave > _cfg.get("distancia_maxima", 90.0) * 0.7 else Color.WHITE


func _pintar(clave: String, texto: String, proporcion: float, alerta: bool) -> void:
	_barras[clave]["texto"].text = texto
	_barras[clave]["barra"].value = clampf(proporcion, 0.0, 1.0)
	Interfaz.color_barra(_barras[clave]["barra"], Interfaz.ALERTA if alerta else Interfaz.AQUA)


func _mostrar_mensaje(texto: String) -> void:
	_mensaje.text = texto
	_mensaje.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(_mensaje, "modulate:a", 0.0, 1.0)
