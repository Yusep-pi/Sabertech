extends Node
## Prueba la pantalla de inicio, las alucinaciones, la soledad afuera y el final
## en la Luna (salir por la esclusa, caminar y plantar la bandera). Guarda capturas
## en capturas/ (dentro del proyecto):
##   godot --path . res://tests/recorrido_final.tscn

var _carpeta := "res://capturas"  # dentro del proyecto (fuera de Git), no en el disco del sistema
var _fallos := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_carpeta)
	_recorrer.call_deferred()


func _process(_delta: float) -> void:
	# Que la prueba no le robe el mouse a quien esté usando la computadora.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _recorrer() -> void:
	var arbol := get_tree()
	reparent(arbol.root)
	arbol.current_scene = null

	# Pantalla de inicio.
	_comprobar(ProjectSettings.get_setting("application/run/main_scene") == GameState.ESCENA_INICIO, "el juego arranca en la pantalla de inicio")
	arbol.change_scene_to_file(GameState.ESCENA_INICIO)
	await _esperar(2.0)
	await _capturar("final_01_inicio")
	arbol.current_scene.comenzar()
	await _esperar(1.5)
	_comprobar(_escena() == "Cabina", "Comenzar misión lleva a la cabina")
	_comprobar(arbol.current_scene._motivo_puerta_cerrada() != "", "antes del despegue la puerta al habitáculo está cerrada")

	# Una partida en pleno viaje, con la cordura baja: alucinaciones.
	_preparar_viaje()
	GameState.ir_a("cabina")
	await _esperar(1.0)
	GameState.ops["cordura"] = 15.0
	await _esperar(4.5)
	_comprobar(Alucinaciones.intensidad > 0.5, "con poca cordura las alucinaciones crecen (%.2f)" % Alucinaciones.intensidad)
	Alucinaciones.forzar()
	await _esperar(1.5)
	await _capturar("final_02_alucinaciones")
	GameState.ops["durmiendo"] = true
	_comprobar(Alucinaciones.objetivo() == 0.0, "durmiendo no hay alucinaciones")
	GameState.ops["durmiendo"] = false
	GameState.ops["cordura"] = 90.0
	_comprobar(Alucinaciones.objetivo() == 0.0, "con buena cordura no hay alucinaciones")

	# Afuera, la soledad: pasados los 3 minutos la cordura baja, y desde los 5, más rápido.
	GameState.ir_a("exterior")
	await _esperar(1.2)
	var eva := arbol.current_scene
	var efectos: Dictionary = GameState.get_tripulacion()["zonas"]["eva"]
	eva._tiempo = 60.0
	var antes: float = GameState.ops["cordura"]
	eva._afectar_tripulacion(10.0, true)
	_comprobar(is_equal_approx(GameState.ops["cordura"], antes), "antes de los 3 minutos afuera la soledad no pesa")
	eva._tiempo = efectos["segundos_aislamiento"] + 1.0
	antes = GameState.ops["cordura"]
	eva._afectar_tripulacion(10.0, true)
	var leve: float = antes - GameState.ops["cordura"]
	eva._tiempo = efectos["segundos_aislamiento_fuerte"] + 1.0
	antes = GameState.ops["cordura"]
	eva._afectar_tripulacion(10.0, true)
	var fuerte: float = antes - GameState.ops["cordura"]
	_comprobar(leve > 0.0 and fuerte > leve, "la cordura baja desde los 3 minutos y más rápido desde los 5 (%.1f y %.1f en 10 s)" % [leve, fuerte])

	# Llegada: la nave aluniza y la esclusa da a la superficie.
	GameState.ops["terminada"] = true
	GameState.ops["motivo_fin"] = "llegada"
	_comprobar(GameState.alunizado(), "al llegar, la nave alunizó")
	GameState.ir_a("esclusa")
	await _esperar(1.2)
	var esclusa := arbol.current_scene
	esclusa._jugador.consola_usada.emit("consola_armario")
	await _esperar(2.6)
	esclusa._jugador.consola_usada.emit("consola_escotilla")
	await _esperar(esclusa.SEGUNDOS_CICLO + 2.0)
	esclusa._jugador.position = Vector3(0, 0.05, -2.75)
	await _esperar(2.5)
	_comprobar(_escena() == "Superficie", "con la nave en la Luna, la escotilla lleva a la superficie")
	var luna := arbol.current_scene
	await _esperar(0.8)
	await _capturar("final_03_superficie")
	var giro: float = luna._jugador.rotation.y
	luna._jugador.mirar_hacia(luna.POSICION_NAVE + Vector3(0, luna.altura(luna.POSICION_NAVE.x, luna.POSICION_NAVE.z) + 3.0, 0))
	await _esperar(0.4)
	await _capturar("final_03b_nave_alunizada")
	luna._jugador.rotation.y = giro
	_comprobar(luna._jugador.is_on_floor(), "el astronauta pisa el suelo lunar")

	# Salto con la gravedad lunar: sube más y tarda más en bajar.
	_tecla(KEY_SPACE, true)
	await _esperar(0.15)
	_tecla(KEY_SPACE, false)
	await _esperar(0.5)
	_comprobar(not luna._jugador.is_on_floor() and luna._jugador.velocity.y > -1.0, "salta con la gravedad de la Luna")
	await _esperar(2.5)

	# Ir hasta el lugar marcado y plantar la bandera manteniendo E.
	var lugar: Vector3 = luna.LUGAR_BANDERA
	luna._jugador.global_position = Vector3(lugar.x + 1.0, luna.altura(lugar.x + 1.0, lugar.z - 1.0) + 0.2, lugar.z - 1.0)
	luna._jugador.mirar_hacia(lugar + Vector3(0, luna.altura(lugar.x, lugar.z), 0))
	await _esperar(0.6)
	_comprobar(luna.hay_lugar_cerca(), "junto a la marca se puede plantar")
	await _capturar("final_04_lugar_bandera")
	_tecla(KEY_E, true)
	await _esperar(luna.SEGUNDOS_PLANTAR + 0.5)
	_tecla(KEY_E, false)
	_comprobar(GameState.ops.get("bandera_plantada", false), "mantener E planta la bandera")
	# La cinemática: camina con la bandera, la clava, la suelta y la saluda.
	await _esperar(1.0)
	await _capturar("final_05a_caminata")
	await _esperar(2.65)
	await _capturar("final_05b_clavando")
	await _esperar(1.0)
	await _capturar("final_05c_segundo_golpe")
	_comprobar(luna._bandera.global_position.y < luna.altura(lugar.x, lugar.z), "el astronauta clava el mástil en el suelo")
	await _esperar(1.6)
	await _capturar("final_05d_bandera")
	_comprobar(luna._tela.scale.x > 0.8, "al soltarla, la tela se despliega")
	await _esperar(4.0)
	await _capturar("final_06_mision_cumplida")
	await _esperar(1.5)
	_comprobar(luna._capa_final.find_children("*", "Button", true, false).size() == 2, "al final aparecen los botones")
	var informe := GameState.calcular_informe()
	_comprobar(GameState.desglose_puntaje()["bandera"] > 0.0, "la bandera suma puntos")
	_comprobar(informe["frases"].has(GameState._frase("bandera_plantada", {})), "el informe cuenta que se plantó la bandera")
	luna._ver_informe()
	await _esperar(0.8)
	await _capturar("final_07_informe")

	print("\n%s · capturas en %s" % ["TODO OK" if _fallos == 0 else "%d FALLOS" % _fallos, ProjectSettings.globalize_path(_carpeta)])
	arbol.quit(_fallos)


func _preparar_viaje() -> void:
	GameState.reiniciar()
	GameState.elegir_mision("luna")
	for id in ["cohete_mediano", "panel_grande", "antena_alta", "motor_quimico", "despensa_mediana", "camara", "espectrometro"]:
		GameState.elegir_pieza(id)
	GameState.lanzamiento = {"exito": true, "motivo": ""}
	GameState.iniciar_operaciones()


func _escena() -> String:
	var actual := get_tree().current_scene
	return actual.name if actual else ""


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
