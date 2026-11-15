extends Node
## Recorre una partida completa y guarda capturas en capturas/ (dentro del proyecto):
## cabina en la plataforma, pantallas de las consolas, cada plano de la
## cinemática de lanzamiento, cabina en órbita, operaciones, informe y una
## explosión de prueba. Sirve para revisar el flujo sin jugarlo a mano:
##   godot --path . res://tests/recorrido.tscn

const MISION := "luna"
const PIEZAS := ["cohete_mediano", "panel_grande", "antena_alta", "motor_quimico", "despensa_mediana", "camara", "espectrometro", "blindaje"]
## Segundos de la cinemática en los que se captura cada plano.
const PLANOS := {"general": 2.5, "motores": 5.6, "despegue": 8.6, "seguimiento": 11.8, "ascenso": 15.0, "resultado": 18.5}

var _carpeta := "res://capturas"  # dentro del proyecto (fuera de Git), no en el disco del sistema


func _ready() -> void:
	# Los textos se comprueban en español, sin tocar el idioma guardado del jugador.
	Idioma.usar("es")
	DirAccess.make_dir_recursive_absolute(_carpeta)
	_recorrer.call_deferred()


func _process(_delta: float) -> void:
	# Que la prueba no le robe el mouse a quien esté usando la computadora.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _recorrer() -> void:
	# Este nodo pasa a colgar de la raíz para sobrevivir a los cambios de escena.
	var arbol := get_tree()
	reparent(arbol.root)
	arbol.current_scene = null
	GameState.reiniciar()
	GameState.rng.seed = 7

	arbol.change_scene_to_file(GameState.ESCENA_CABINA)
	await _esperar(1.0)
	await _capturar("01_cabina_plataforma")
	var al_empezar: String = _escena()._jugador.consola_mirada()
	print("Al empezar se mira: ", al_empezar, "" if al_empezar == "consola_principal" else "  <-- FALLA")
	await _probar_caminar_derecho()
	_escena().abrir_pantalla("briefing")
	await _esperar(0.5)
	await _capturar("02_briefing")

	GameState.elegir_mision(MISION)
	for id in PIEZAS:
		GameState.elegir_pieza(id)
	GameState.ir_a("diseno")
	await _esperar(0.8)
	await _capturar("03_diseno")
	_escena().cerrar_pantalla()
	await _esperar(0.5)
	await _capturar("04_cabina_lista")
	# Mirando un poco hacia abajo, la mira tiene que caer sobre la computadora de misión.
	_escena()._jugador.camara.rotation_degrees.x = -20
	await get_tree().physics_frame
	await get_tree().physics_frame
	var mirada: String = _escena()._jugador.consola_mirada()
	print("Consola mirada: ", mirada, "" if mirada == "consola_principal" else "  <-- FALLA")
	_escena()._jugador.camara.rotation_degrees.x = 0

	# Lanzamiento forzado a salir bien, capturando cada plano.
	GameState.lanzar()
	GameState.lanzamiento = {"exito": true, "motivo": ""}
	await _cinematica("05")

	GameState.iniciar_operaciones()
	GameState.ir_a("operaciones")
	await _esperar(1.0)
	await _capturar("06_cabina_orbita")
	_escena()._jugador.rotation_degrees.y = -70
	await _esperar(0.4)
	await _capturar("07_cabina_consolas")
	_escena()._jugador.rotation_degrees.y = 0

	GameState.ir_a("operaciones")
	await _esperar(0.5)
	await _capturar("08_operaciones")
	while not GameState.ops["terminada"]:
		if not GameState.ops["evento_actual"].is_empty():
			var opciones: Array = GameState.ops["evento_actual"]["opciones"]
			GameState.resolver_evento(0 if GameState.opcion_disponible(opciones[0]) else 1)
			# Cerramos el cartel del evento como si se hubiera tocado "Continuar".
			var pantalla = _escena()._pantalla_abierta
			if is_instance_valid(pantalla._capa_evento):
				pantalla._capa_evento.queue_free()
			pantalla._boton_turno.disabled = false
		GameState.terminar_turno()
	GameState.ir_a("informe")
	await _esperar(0.6)
	await _capturar("09_informe")

	# Una explosión de prueba, para revisar ese camino de la cinemática.
	GameState.lanzamiento = {"exito": false, "motivo": "cohete"}
	arbol.change_scene_to_file(GameState.ESCENA_LANZAMIENTO)
	await _esperar(PLANOS["seguimiento"] + 1.2)
	await _capturar("10_explosion")

	# Y una falla por masa: la cámara queda fija mientras el cohete tiembla con los motores encendidos.
	GameState.lanzamiento = {"exito": false, "motivo": "masa"}
	arbol.change_scene_to_file(GameState.ESCENA_LANZAMIENTO)
	await _esperar(PLANOS["despegue"])
	await _capturar("11_fallo_masa")

	print("Capturas en ", ProjectSettings.globalize_path(_carpeta))
	arbol.quit()


## Con W apretada el jugador tiene que ir hacia donde mira (la cabina en la plataforma está girada).
func _probar_caminar_derecho() -> void:
	var jugador: CharacterBody3D = _escena()._jugador
	var giro_original := jugador.rotation.y
	# Mirando hacia el fondo de la cabina, que está despejado (hacia el frente está el asiento).
	jugador.rotation.y = PI
	var inicio := jugador.global_position
	var adelante := -jugador.global_transform.basis.z
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_W
	tecla.pressed = true
	Input.parse_input_event(tecla)
	await _esperar(0.3)
	var soltar := tecla.duplicate()
	soltar.pressed = false
	Input.parse_input_event(soltar)
	await get_tree().physics_frame
	var recorrido := jugador.global_position - inicio
	var desvio := rad_to_deg(Vector2(recorrido.x, recorrido.z).angle_to(Vector2(adelante.x, adelante.z)))
	print("Desvío al caminar: %.1f°%s" % [absf(desvio), "" if absf(desvio) < 2.0 and recorrido.length() > 0.3 else "  <-- FALLA"])
	jugador.global_position = inicio
	jugador.rotation.y = giro_original


func _cinematica(prefijo: String) -> void:
	GameState.ir_a("lanzamiento")
	var transcurrido := 0.0
	for plano in PLANOS:
		await _esperar(PLANOS[plano] - transcurrido)
		transcurrido = PLANOS[plano]
		await _capturar("%s_lanzamiento_%s" % [prefijo, plano])


func _escena() -> Node:
	return get_tree().current_scene


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


func _capturar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_carpeta, nombre])
