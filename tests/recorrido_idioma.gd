extends Node
## Prueba el cambio de idioma con las banderas del menú de inicio: en inglés el menú,
## los datos (piezas, frases del informe) y las pantallas cambian, y al volver a la
## bandera de Paraguay todo vuelve al español. Guarda capturas idioma_*.png en
## capturas/ (dentro del proyecto) para revisar a ojo restos en español o textos que
## no entran:
##   godot --path . res://tests/recorrido_idioma.tscn
## Al terminar deja el idioma que tenía guardado el jugador.

const PIEZAS := ["cohete_mediano", "panel_grande", "antena_alta", "motor_quimico", "despensa_mediana", "camara", "espectrometro"]

var _carpeta := "res://capturas"  # dentro del proyecto (fuera de Git), no en el disco del sistema
var _fallos := 0
var _idioma_del_jugador := ""


func _ready() -> void:
	_idioma_del_jugador = Idioma.actual
	Idioma.usar("es")
	DirAccess.make_dir_recursive_absolute(_carpeta)
	_recorrer.call_deferred()


func _process(_delta: float) -> void:
	# Que la prueba no le robe el mouse a quien esté usando la computadora.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _recorrer() -> void:
	var arbol := get_tree()
	reparent(arbol.root)
	arbol.current_scene = null

	# Menú en español, con dos banderas.
	arbol.change_scene_to_file(GameState.ESCENA_INICIO)
	await _esperar(1.5)
	var inicio := arbol.current_scene
	_comprobar(_botones_bandera(inicio).size() == 2, "el menú tiene dos banderas")
	_comprobar(_hay_texto(inicio, "Comenzar misión"), "en español el menú dice Comenzar misión")
	await _capturar("idioma_01_menu_es")

	# Bandera de EE.UU.: todo pasa al inglés al instante.
	inicio._elegir_idioma("en")
	await _esperar(0.5)
	_comprobar(Idioma.actual == "en" and TranslationServer.get_locale() == "en", "la bandera de EE.UU. pone el inglés")
	_comprobar(_hay_texto(inicio, "Start mission"), "el menú cambia a Start mission")
	_comprobar(not _hay_texto(inicio, "Comenzar misión"), "no queda el botón en español")
	var cohete: Dictionary = GameState.get_pieza("cohete_mediano")
	_comprobar(GameState.datos["categorias"][0]["nombre"] == "Rocket", "las categorías de piezas están en inglés")
	_comprobar(cohete.get("nombre", "") != "" and cohete["nombre"] != _en_espanol(cohete["nombre"]), "las piezas tienen nombre en inglés (%s)" % cohete.get("nombre", ""))
	_comprobar(GameState._miles(384400) == "384,400", "los miles se separan con coma")
	await _capturar("idioma_02_menu_en")
	inicio._mostrar_ayuda(true)
	await _esperar(0.3)
	await _capturar("idioma_03_ayuda_en")

	# Una partida en inglés: diseño, cabina con el HUD, operaciones e informe.
	GameState.reiniciar()
	GameState.rng.seed = 7
	arbol.change_scene_to_file(GameState.ESCENA_CABINA)
	await _esperar(1.0)
	await _capturar("idioma_04_cabina_en")
	arbol.current_scene.abrir_pantalla("briefing")
	await _esperar(0.5)
	await _capturar("idioma_05_briefing_en")
	GameState.elegir_mision("luna")
	for id in PIEZAS:
		GameState.elegir_pieza(id)
	GameState.ir_a("diseno")
	await _esperar(0.8)
	await _capturar("idioma_06_diseno_en")
	arbol.current_scene.cerrar_pantalla()
	GameState.lanzamiento = {"exito": true, "motivo": ""}
	GameState.iniciar_operaciones()
	GameState.ir_a("operaciones")
	await _esperar(1.0)
	await _capturar("idioma_07_cabina_viaje_en")
	GameState.ir_a("operaciones")
	await _esperar(0.5)
	await _capturar("idioma_08_operaciones_en")
	while not GameState.ops["terminada"]:
		if not GameState.ops["evento_actual"].is_empty():
			var opciones: Array = GameState.ops["evento_actual"]["opciones"]
			GameState.resolver_evento(0 if GameState.opcion_disponible(opciones[0]) else 1)
			var pantalla = arbol.current_scene._pantalla_abierta
			if is_instance_valid(pantalla) and is_instance_valid(pantalla._capa_evento):
				pantalla._capa_evento.queue_free()
				pantalla._boton_turno.disabled = false
		GameState.terminar_turno()
	GameState.ir_a("informe")
	await _esperar(0.8)
	await _capturar("idioma_09_informe_en")
	_comprobar(not _hay_texto(arbol.current_scene, "Rediseñar la nave") and not _hay_texto(arbol.current_scene, "Empezar de cero"), "el informe no tiene botones en español")

	# Bandera de Paraguay: vuelve todo al español.
	arbol.change_scene_to_file(GameState.ESCENA_INICIO)
	await _esperar(1.0)
	arbol.current_scene._elegir_idioma("es")
	await _esperar(0.5)
	_comprobar(Idioma.actual == "es", "la bandera de Paraguay vuelve al español")
	_comprobar(_hay_texto(arbol.current_scene, "Comenzar misión"), "el menú vuelve a Comenzar misión")
	_comprobar(GameState.datos["categorias"][0]["nombre"] == "Cohete", "las piezas vuelven al español")
	_comprobar(GameState._miles(384400) == "384.400", "los miles vuelven a separarse con punto")

	# Se deja el idioma que el jugador tenía elegido.
	Idioma.cambiar(_idioma_del_jugador)
	print("\n%s · capturas en %s" % ["TODO OK" if _fallos == 0 else "%d FALLOS" % _fallos, ProjectSettings.globalize_path(_carpeta)])
	arbol.quit(_fallos)


func _botones_bandera(nodo: Node) -> Array:
	return nodo.find_children("*", "TextureButton", true, false)


## Hay algún Label o Button visible cuyo texto empieza con el dado.
func _hay_texto(nodo: Node, texto: String) -> bool:
	for control in nodo.find_children("*", "", true, false):
		if (control is Label or control is Button) and control.is_visible_in_tree() and control.text.begins_with(texto):
			return true
	return false


## El texto original en español de una traducción (para comparar).
func _en_espanol(texto: String) -> String:
	var catalogo := TranslationServer.get_translation_object("en")
	for msgid in catalogo.get_message_list():
		if catalogo.get_message(msgid) == texto:
			return msgid
	return texto


func _comprobar(condicion: bool, descripcion: String) -> void:
	if not condicion:
		_fallos += 1
	print(("  ok  " if condicion else "  FALLA  ") + descripcion)


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


func _capturar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_carpeta, nombre])
