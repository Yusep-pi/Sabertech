extends Node
## Prueba la caminata espacial sola: propulsor y freno, cada reparación, la lluvia
## de micrometeoritos (expuesto y a cubierto), la victoria y la falta de oxígeno.
## Guarda capturas en user://capturas/eva_*.png:
##   godot --path . res://tests/recorrido_eva.tscn

var _carpeta := "user://capturas"
var _fallos := 0
var _mouse_capturado := false  # solo durante la prueba del mouse, un instante


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_carpeta)
	_recorrer.call_deferred()


func _process(_delta: float) -> void:
	# Que la prueba no le robe el mouse a quien esté usando la computadora.
	if not _mouse_capturado:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _recorrer() -> void:
	var arbol := get_tree()
	reparent(arbol.root)
	arbol.current_scene = null
	GameState.reiniciar()

	_probar_generacion_de_paneles()

	arbol.change_scene_to_file("res://scenes/eva/eva.tscn")
	await _esperar(1.2)
	await _capturar("eva_01_inicio")
	var nivel := _nivel()
	var astronauta: CharacterBody3D = nivel._astronauta

	# Nada del HUD puede atrapar el mouse: si no, el movimiento no llega al astronauta.
	var atrapan := []
	for control in nivel.find_children("*", "Control", true, false):
		# Los paneles de reparación sí tienen botones, pero están ocultos hasta abrirlos.
		if control.is_visible_in_tree() and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			atrapan.append(control.name)
	_comprobar(atrapan.is_empty(), "el HUD deja pasar el mouse %s" % ("" if atrapan.is_empty() else str(atrapan)))
	# Y un movimiento del mouse con el mouse capturado gira al astronauta.
	var giro_antes := astronauta.global_transform.basis
	_mouse_capturado = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	var movimiento := InputEventMouseMotion.new()
	movimiento.relative = Vector2(120, 0)
	movimiento.position = get_viewport().get_visible_rect().size / 2
	Input.parse_input_event(movimiento)
	await get_tree().process_frame
	_mouse_capturado = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_comprobar(not astronauta.global_transform.basis.is_equal_approx(giro_antes), "mover el mouse gira al astronauta")

	# Propulsor hacia adelante y después freno, lejos de la escotilla (ahí se recarga).
	_ubicar(astronauta, nivel._nave.global_position + Vector3(0, 0, 30), nivel._nave.global_position + Vector3(0, 0, 60))
	_tecla(KEY_W, true)
	await _esperar(0.6)
	_tecla(KEY_W, false)
	_comprobar(astronauta.velocity.length() > 1.0, "el propulsor acelera (%.2f m/s)" % astronauta.velocity.length())
	_comprobar(astronauta.combustible < 100.0, "propulsar gasta combustible")
	_tecla(KEY_X, true)
	await _esperar(1.5)
	_tecla(KEY_X, false)
	_comprobar(astronauta.velocity.length() < 0.05, "el freno detiene al astronauta (%.2f m/s)" % astronauta.velocity.length())

	# Cada reparación: acercarse, abrir el panel con E y resolver el puzzle.
	for i in nivel._tareas.size():
		var tarea: Dictionary = nivel._tareas[i]
		_ubicar(astronauta, tarea["posicion"] + tarea["normal"] * 1.5, tarea["posicion"])
		await _esperar(0.2)
		_comprobar(not nivel.tarea_al_alcance().is_empty(), "la tarea «%s» queda al alcance" % tarea["titulo"])
		await _pulsar(KEY_E)
		await _esperar(nivel.ZOOM_SEGUNDOS + 0.2)
		var panel = tarea["panel"]
		var camara: Camera3D = astronauta.camara
		_comprobar(panel.visible and not astronauta.activo, "E abre el panel y engancha al astronauta")
		_comprobar(camara.global_position.distance_to(tarea["consola"].global_position) < 2.0, "la cámara se acerca a la consola")
		_comprobar(not panel.esta_resuelto(), "el panel no arranca resuelto")
		if i == 0:
			await _capturar("eva_02_panel")
			# Esc suelta el panel, la cámara vuelve y lo ajustado se conserva.
			panel.poner_control(0, 5)
			await _pulsar(KEY_ESCAPE)
			await _esperar(nivel.ZOOM_SEGUNDOS + 0.2)
			_comprobar(not panel.visible and astronauta.activo, "Esc suelta el panel")
			_comprobar(camara.position.distance_to(Vector3(0, 0.6, 0)) < 0.05, "la cámara vuelve a los ojos del astronauta")
			_comprobar(panel._controles[0]["valor"] == 5, "lo ajustado queda como estaba")
			await _pulsar(KEY_E)
			await _esperar(nivel.ZOOM_SEGUNDOS + 0.2)
		var solucion: Dictionary = panel.solucion()
		for c in solucion["controles"].size():
			panel.poner_control(c, solucion["controles"][c])
		for s in solucion["interruptores"].size():
			panel.poner_interruptor(s, solucion["interruptores"][s])
		if i == 0:
			await _esperar(0.3)
			await _capturar("eva_03_panel_resuelto")
		await _esperar(panel.CONFIRMACION + nivel.ZOOM_SEGUNDOS + 0.4)
		_comprobar(tarea["hecha"] and astronauta.activo, "resolver el panel completa «%s»" % tarea["titulo"])

	# Lluvia de micrometeoritos: aviso, expuesto y a cubierto.
	nivel.iniciar_aviso_lluvia()
	var direccion: Vector3 = nivel._lluvia_direccion
	var nave: Vector3 = nivel._nave.global_position
	_ubicar(astronauta, nave + direccion * 22.0 + Vector3.UP * 3.0, nave)
	await _esperar(0.5)
	await _capturar("eva_03_aviso")
	nivel._lluvia_reloj = 0.05
	await _esperar(0.3)
	var traje_antes: float = nivel._traje
	await _esperar(1.0)
	await _capturar("eva_04_lluvia_expuesto")
	_comprobar(nivel._traje < traje_antes, "expuesto a la lluvia, el traje se daña")
	_ubicar(astronauta, nave - direccion * 9.0, nave - direccion * 30.0)
	await _esperar(0.3)
	_comprobar(not nivel.expuesto_a_la_lluvia(), "detrás de la nave se está a cubierto")
	traje_antes = nivel._traje
	await _esperar(1.0)
	_comprobar(is_equal_approx(nivel._traje, traje_antes), "a cubierto, el traje no se daña")

	# Volver a la escotilla con todo resuelto es ganar.
	_ubicar(astronauta, nivel._escotilla + Vector3(nivel._escotilla.x, 0, nivel._escotilla.z).normalized() * 2.0, nave)
	await _esperar(0.6)
	_comprobar(nivel._estado == "victoria", "volver a la escotilla con todo resuelto gana")
	await _capturar("eva_05_victoria")

	# Sin oxígeno se pierde.
	arbol.change_scene_to_file("res://scenes/eva/eva.tscn")
	await _esperar(1.0)
	nivel = _nivel()
	_ubicar(nivel._astronauta, nivel._nave.global_position + Vector3(0, 0, 25), nivel._nave.global_position)
	nivel._oxigeno = 0.5
	await _esperar(1.0)
	_comprobar(nivel._estado == "derrota", "sin oxígeno se pierde")
	await _capturar("eva_06_sin_oxigeno")

	print("\n%s · capturas en %s" % ["TODO OK" if _fallos == 0 else "%d FALLOS" % _fallos, ProjectSettings.globalize_path(_carpeta)])
	arbol.quit(_fallos)


## Muchos paneles al azar: ninguno arranca resuelto y la solución siempre funciona.
func _probar_generacion_de_paneles() -> void:
	var PanelReparacion := preload("res://scenes/eva/panel_reparacion.gd")
	var azar := RandomNumberGenerator.new()
	azar.seed = 99
	for tarea in GameState.datos["eva"]["tareas"]:
		var bien := 0
		for i in 200:
			var panel = PanelReparacion.new()
			panel.configurar(tarea, GameState.datos["eva"].get("tolerancia", 1.0), azar)
			var arranca_resuelto: bool = panel.esta_resuelto()
			var solucion: Dictionary = panel.solucion()
			for c in solucion["controles"].size():
				panel.poner_control(c, solucion["controles"][c])
			for s in solucion["interruptores"].size():
				panel.poner_interruptor(s, solucion["interruptores"][s])
			if not arranca_resuelto and panel.esta_resuelto():
				bien += 1
			panel.free()
		_comprobar(bien == 200, "«%s»: %d de 200 paneles al azar son resolubles y arrancan sin resolver" % [tarea["titulo"], bien])


func _pulsar(tecla: Key) -> void:
	_tecla(tecla, true)
	await get_tree().process_frame
	_tecla(tecla, false)


func _ubicar(astronauta: CharacterBody3D, posicion: Vector3, mirar: Vector3) -> void:
	astronauta.global_position = posicion
	astronauta.velocity = Vector3.ZERO
	var arriba := Vector3.UP if absf((mirar - posicion).normalized().dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	astronauta.look_at(mirar, arriba)


func _tecla(tecla: Key, apretada: bool) -> void:
	var evento := InputEventKey.new()
	evento.physical_keycode = tecla
	evento.pressed = apretada
	Input.parse_input_event(evento)


func _nivel() -> Node:
	return get_tree().current_scene


func _comprobar(condicion: bool, descripcion: String) -> void:
	print(("  ok  " if condicion else "  FALLA  ") + descripcion)
	if not condicion:
		_fallos += 1


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


func _capturar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_carpeta, nombre])
