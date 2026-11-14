extends Node
## Prueba la esclusa sola: ponerse el traje, despresurizar, abrir, salir a la
## caminata, volver, presurizar y sacarse el traje. Guarda capturas en
## capturas/ (dentro del proyecto)/esclusa_*.png:
##   godot --path . res://tests/recorrido_esclusa.tscn

const ESCLUSA := "res://scenes/esclusa/esclusa.tscn"

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
	GameState.reiniciar()

	arbol.change_scene_to_file(ESCLUSA)
	await _esperar(1.2)
	var esclusa := arbol.current_scene
	var jugador = esclusa._jugador
	await _capturar("esclusa_01_inicio")
	_comprobar(esclusa.estado == "sin_traje", "se empieza sin traje")

	# El armario con el traje.
	jugador.mirar_hacia(Vector3(2.1, 1.3, -1.0))
	await _esperar(0.3)
	_comprobar(jugador.consola_mirada() == "consola_armario", "mirar el armario lo detecta")
	await _capturar("esclusa_02_armario")

	# Sin traje la escotilla no se abre.
	jugador.consola_usada.emit("consola_escotilla")
	await _esperar(0.2)
	_comprobar(esclusa.estado == "sin_traje", "sin traje no se despresuriza")

	jugador.consola_usada.emit("consola_armario")
	await _esperar(2.6)
	_comprobar(esclusa.estado == "con_traje" and not esclusa._traje.visible and esclusa._visor.visible, "ponerse el traje lo saca del armario y muestra el visor")
	# Caminar hasta el panel: E alcanza 3 m.
	jugador.position = Vector3(0.9, 0.05, -1.3)
	jugador.mirar_hacia(esclusa.PANTALLA_ESCOTILLA)
	await _esperar(0.3)
	_comprobar(jugador.consola_mirada() == "consola_escotilla", "mirar el panel de la escotilla lo detecta")
	await _capturar("esclusa_03_con_traje")

	# Despresurizar y abrir.
	jugador.consola_usada.emit("consola_escotilla")
	await _esperar(2.5)
	_comprobar(esclusa.estado == "despresurizando" and esclusa.presion < esclusa.PRESION, "la presión baja")
	await _capturar("esclusa_04_despresurizando")
	await _esperar(esclusa.SEGUNDOS_CICLO)
	_comprobar(esclusa.estado == "abierta" and esclusa.presion == 0.0, "la escotilla se abre sin aire")
	_comprobar(esclusa._puerta.position.x > 1.0, "la hoja de la escotilla se corrió")
	jugador.mirar_hacia(esclusa.CENTRO_ESCOTILLA)
	await _esperar(0.3)
	await _capturar("esclusa_05_abierta")

	# La vista por el ventanal.
	jugador.position = Vector3(-0.6, 0.05, 0.4)
	jugador.mirar_hacia(Vector3(-4.0, 1.0, -0.6))
	await _esperar(0.4)
	await _capturar("esclusa_06_ventanal")

	# Cruzar el umbral lleva a la caminata.
	jugador.position = Vector3(0, 0.05, -2.75)
	await _esperar(2.5)
	_comprobar(arbol.current_scene and arbol.current_scene.name == "Eva", "salir por la escotilla lleva a la caminata")

	# La vuelta: entra con la escotilla abierta, cierra, presuriza y se saca el traje.
	GameState.vuelve_de_caminata = true
	arbol.change_scene_to_file(ESCLUSA)
	await _esperar(1.2)
	esclusa = arbol.current_scene
	jugador = esclusa._jugador
	_comprobar(esclusa.estado == "abierta" and esclusa._volvio and esclusa._visor.visible, "al volver, la escotilla está abierta y el traje puesto")
	await _capturar("esclusa_07_vuelta")
	jugador.consola_usada.emit("consola_escotilla")
	await _esperar(1.5 + esclusa.SEGUNDOS_CICLO + 0.5)
	_comprobar(esclusa.estado == "con_traje" and esclusa.presion == esclusa.PRESION, "cerrar presuriza la esclusa")
	jugador.consola_usada.emit("consola_armario")
	await _esperar(2.6)
	_comprobar(esclusa.estado == "sin_traje" and esclusa._traje.visible and not esclusa._volvio, "el traje vuelve al armario")

	print("\n%s · capturas en %s" % ["TODO OK" if _fallos == 0 else "%d FALLOS" % _fallos, ProjectSettings.globalize_path(_carpeta)])
	arbol.quit(_fallos)


func _comprobar(condicion: bool, descripcion: String) -> void:
	print(("  ok  " if condicion else "  FALLA  ") + descripcion)
	if not condicion:
		_fallos += 1


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


func _capturar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_carpeta, nombre])
