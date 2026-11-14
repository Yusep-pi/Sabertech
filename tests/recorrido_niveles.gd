extends Node
## Recorre los ambientes de la nave a pie, ida y vuelta:
## cabina → habitáculo → esclusa → exterior → esclusa → habitáculo → cabina.
## Prueba mantener E en una puerta real, las reglas de la esclusa (traje, presión,
## solo en órbita) y que cada ambiente ubique al jugador frente a la puerta por la
## que entró. Guarda capturas en capturas/ (dentro del proyecto):
##   godot --path . res://tests/recorrido_niveles.tscn

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

	# Una nave ya en órbita, para que la escotilla se pueda abrir.
	GameState.reiniciar()
	GameState.elegir_mision("luna")
	for id in ["cohete_chico", "panel_chico", "antena_media", "motor_quimico", "despensa_mediana", "camara"]:
		GameState.elegir_pieza(id)
	GameState.lanzamiento = {"exito": true, "motivo": ""}
	GameState.iniciar_operaciones()

	# Cabina → habitáculo, manteniendo E de verdad junto a la puerta trasera.
	GameState.ir_a("cabina")
	await _esperar(1.0)
	var cabina := arbol.current_scene
	cabina._jugador.position = Vector3(0, 0.05, 3.0)
	await _esperar(0.3)
	await _capturar("niveles_01_cabina_puerta")
	_tecla(KEY_E, true)
	await _esperar(cabina._compuerta.TIEMPO_MANTENER + 1.0)
	_tecla(KEY_E, false)
	_comprobar(_escena() == "SalaDos", "mantener E en la puerta trasera lleva al habitáculo")
	await _esperar(0.6)
	var sala := arbol.current_scene
	_comprobar(sala._jugador.position.z < -2.0, "en el habitáculo se aparece junto a la puerta de la cabina")
	await _capturar("niveles_02_habitaculo")
	sala._jugador.mirar_hacia(sala._interior.to_global(Vector3(0, 1.3, 3.4)))
	await _esperar(0.3)
	await _capturar("niveles_03_habitaculo_puerta_esclusa")

	# Habitáculo → esclusa.
	await _cruzar(sala, "esclusa")
	_comprobar(_escena() == "Esclusa", "la puerta sur del habitáculo lleva a la esclusa")
	var esclusa := arbol.current_scene
	_comprobar(esclusa._jugador.position.z > 1.5, "en la esclusa se aparece junto a la puerta interior")
	await _capturar("niveles_04_esclusa")

	# Con el traje puesto no se vuelve a la nave; sin traje, sí.
	esclusa.estado = "con_traje"
	_comprobar(esclusa._motivo_puerta_cerrada() != "", "con el traje puesto la puerta interior no abre")
	esclusa.estado = "sin_traje"
	_comprobar(esclusa._motivo_puerta_cerrada() == "", "sin traje y con aire, la puerta interior abre")

	# Afuera: traje, despresurizar y cruzar la escotilla.
	esclusa._jugador.consola_usada.emit("consola_armario")
	await _esperar(2.6)
	esclusa._jugador.consola_usada.emit("consola_escotilla")
	await _esperar(esclusa.SEGUNDOS_CICLO + 2.0)
	_comprobar(esclusa.estado == "abierta", "en órbita la escotilla se abre")
	_comprobar(esclusa._motivo_puerta_cerrada() != "", "sin aire la puerta interior no abre")
	esclusa._jugador.position = Vector3(0, 0.05, -2.75)
	await _esperar(2.5)
	_comprobar(_escena() == "Eva", "la escotilla lleva al exterior")
	await _capturar("niveles_05_exterior")

	# De vuelta: exterior → esclusa (como al ganar la caminata) → presurizar → sacarse el traje.
	GameState.vuelve_de_caminata = true
	arbol.change_scene_to_file(GameState.AMBIENTES["esclusa"])
	await _esperar(1.2)
	esclusa = arbol.current_scene
	esclusa._jugador.consola_usada.emit("consola_escotilla")
	await _esperar(1.5 + esclusa.SEGUNDOS_CICLO + 0.5)
	esclusa._jugador.consola_usada.emit("consola_armario")
	await _esperar(2.6)
	_comprobar(esclusa._motivo_puerta_cerrada() == "", "presurizada y sin traje, se puede volver a la nave")
	await _cruzar(esclusa, "habitaculo")
	sala = arbol.current_scene
	_comprobar(_escena() == "SalaDos" and sala._jugador.position.z > 2.0, "volviendo de la esclusa se aparece junto a la puerta sur")
	await _cruzar(sala, "cabina")
	cabina = arbol.current_scene
	_comprobar(_escena() == "Cabina" and cabina._jugador.position.z > 2.0, "volviendo del habitáculo se aparece en la puerta trasera de la cabina")
	_comprobar(GameState.en_orbita(), "la misión sigue en curso después del recorrido")
	await _capturar("niveles_06_cabina_vuelta")

	# En la plataforma la escotilla no se abre.
	GameState.volver_a_diseno()
	GameState.ir_a("esclusa")
	await _esperar(1.2)
	esclusa = arbol.current_scene
	esclusa._jugador.consola_usada.emit("consola_armario")
	await _esperar(2.6)
	esclusa._jugador.consola_usada.emit("consola_escotilla")
	await _esperar(0.5)
	_comprobar(esclusa.estado == "con_traje", "en la plataforma la escotilla no se abre")
	esclusa._jugador.position = Vector3(-0.6, 0.05, 0.4)
	esclusa._jugador.mirar_hacia(Vector3(-4.0, 1.4, -0.6))
	await _esperar(0.4)
	await _capturar("niveles_07_esclusa_plataforma")

	print("\n%s · capturas en %s" % ["TODO OK" if _fallos == 0 else "%d FALLOS" % _fallos, ProjectSettings.globalize_path(_carpeta)])
	arbol.quit(_fallos)


## Cruza la puerta de un ambiente hacia un destino y espera a que cargue el siguiente.
func _cruzar(ambiente: Node, destino: String) -> void:
	var compuerta: Compuerta = ambiente.find_children("*", "Compuerta", true, false)[0]
	compuerta.cruzar(compuerta.puerta_hacia(destino))
	await _esperar(compuerta.FUNDIDO + 1.0)


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
