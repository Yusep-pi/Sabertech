extends Node
## Prueba la tripulación en las zonas nuevas: el HUD en el habitáculo, comer en
## el refrigerador, dormir en la cama (y despertar), y que la misión que termina
## fuera de la cabina lleve al informe. Guarda capturas en capturas/:
##   godot --path . res://tests/recorrido_cama.tscn

var _carpeta := "res://capturas"
var _fallos := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_carpeta)
	_recorrer.call_deferred()


func _process(_delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _recorrer() -> void:
	var arbol := get_tree()
	reparent(arbol.root)
	arbol.current_scene = null

	GameState.reiniciar()
	GameState.elegir_mision("luna")
	for id in ["cohete_mediano", "panel_grande", "antena_alta", "motor_quimico", "despensa_mediana", "camara"]:
		GameState.elegir_pieza(id)
	GameState.lanzamiento = {"exito": true, "motivo": ""}
	GameState.iniciar_operaciones()
	GameState.ops["eventos"] = {}
	GameState.ops["evento_actual"] = {}

	GameState.origen_transicion = "cabina"
	GameState.ir_a("habitaculo")
	await _esperar(1.0)
	var sala := arbol.current_scene
	_comprobar(sala.name == "SalaDos", "se llega al habitáculo")
	_comprobar(sala._tripulacion.visible and sala._tripulacion._panel.visible, "el habitáculo muestra la tripulación")

	# Refrigerador: comer una ración.
	GameState.cambiar_tripulacion(-50.0, 0.0)
	var raciones: int = GameState.ops["raciones"]
	sala._jugador.consola_usada.emit("consola_refrigerador")
	_comprobar(GameState.ops["raciones"] == raciones - 1, "en el refrigerador se come una ración")

	# Mirar la cama: aparece la indicación.
	sala._jugador.position = Vector3(1.2, 0.05, 0.4)
	sala._jugador.mirar_hacia(sala._interior.to_global(Vector3(2.35, 0.3, 0.4)))
	await _esperar(0.3)
	_comprobar(sala._jugador.consola_mirada() == "consola_cama", "se puede mirar la cama")
	await _capturar("cama_01_habitaculo")

	# Sin sueño no se duerme.
	sala._jugador.consola_usada.emit("consola_cama")
	_comprobar(not GameState.durmiendo(), "con la cordura alta la cama no duerme")
	await _esperar(0.3)
	await _capturar("cama_02_sin_sueno")

	# Con sueño, sí: el jugador queda quieto y el viaje se acelera.
	GameState.ops["cordura"] = 70.0
	var horas: float = GameState.ops["viaje"]["horas"]
	sala._jugador.consola_usada.emit("consola_cama")
	_comprobar(GameState.durmiendo() and not sala._jugador.activo, "en la cama se duerme y el jugador queda quieto")
	await _esperar(2.0)
	_comprobar(GameState.ops["cordura"] > 70.0, "durmiendo sube la cordura")
	var acel: float = GameState.get_tripulacion()["dormir"]["aceleracion"]
	_comprobar(GameState.ops["viaje"]["horas"] - horas > 2.0 * acel * 0.8 / GameState.ops["viaje"]["segundos_por_hora"], "durmiendo el viaje va más rápido")
	await _capturar("cama_03_durmiendo")

	# Cualquier tecla despierta.
	_tecla(KEY_SPACE, true)
	_tecla(KEY_SPACE, false)
	await _esperar(0.3)
	_comprobar(not GameState.durmiendo() and sala._jugador.activo, "una tecla despierta y devuelve el control")
	await _capturar("cama_04_despierto")

	# Una alerta fuera de la cabina se avisa en el HUD.
	GameState.ops["evento_actual"] = GameState._preparar_evento("tormenta_solar")
	GameState.plan_cambiado.emit()
	await _esperar(0.3)
	_comprobar(sala._tripulacion._alerta.text != "", "una alerta se avisa fuera de la cabina")
	await _capturar("cama_05_alerta")
	GameState.ops["evento_actual"] = {}

	# Si la misión termina fuera de la cabina, se vuelve a la cabina con el informe.
	GameState.cambiar_tripulacion(0.0, -200.0)
	await _esperar(HudTripulacion.ESPERA_INFORME + 1.5)
	_comprobar(arbol.current_scene and arbol.current_scene.name == "Cabina", "al terminar fuera de la cabina se vuelve a la cabina")
	_comprobar(arbol.current_scene and arbol.current_scene._pantalla_abierta != null, "y se abre el informe")
	await _capturar("cama_06_informe")

	print("\n%s · capturas en %s" % ["TODO OK" if _fallos == 0 else "%d FALLOS" % _fallos, ProjectSettings.globalize_path(_carpeta)])
	arbol.quit(_fallos)


func _tecla(tecla: Key, apretada: bool) -> void:
	var evento := InputEventKey.new()
	evento.physical_keycode = tecla
	evento.pressed = apretada
	Input.parse_input_event(evento)


func _comprobar(condicion: bool, descripcion: String) -> void:
	print(("  ok  " if condicion else "  FALLA  ") + descripcion)
	if not condicion:
		_fallos += 1


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


func _capturar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_carpeta, nombre])
