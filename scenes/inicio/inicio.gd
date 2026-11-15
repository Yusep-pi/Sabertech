extends Node3D
## Pantalla de inicio: la nave en órbita de fondo, con la Tierra y la Luna, y una
## cámara que se mueve despacio. Comenzar misión, cómo se juega, gráficos y salir.
## Es la escena principal del juego.

const DISTANCIA_CAMARA := 15.0

var _nave: Nave3D
var _camara: Camera3D
var _tiempo := 0.0
var _menu: Control
var _ayuda: Control
var _boton_graficos: Button
var _fundido: ColorRect


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_child(Espacio.entorno())
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-25, -60, 0)
	sol.light_energy = 1.5
	add_child(sol)
	add_child(Espacio.estrellas(900, 1500))

	var tierra := Espacio.planeta("tierra", 600)
	tierra.position = Vector3(-500, -650, -900)
	add_child(tierra)
	var luna := Espacio.planeta("luna", 90)
	luna.position = Vector3(420, 160, -1100)
	add_child(luna)

	_nave = Nave3D.new()
	_nave.mostrar(GameState.datos.get("eva", {}).get("nave_por_defecto", []))
	_nave.rotation_degrees = Vector3(15, 0, -8)
	add_child(_nave)

	_camara = Camera3D.new()
	_camara.fov = 50
	_camara.current = true
	add_child(_camara)
	_mover_camara(0.0)

	_crear_interfaz()


func _process(delta: float) -> void:
	_tiempo += delta
	_nave.rotate_y(delta * 0.12)
	_mover_camara(_tiempo)


func _unhandled_key_input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if not tecla or not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and _menu.visible:
		comenzar()
	elif tecla.physical_keycode == KEY_ESCAPE and _ayuda.visible:
		_mostrar_ayuda(false)


## La cámara gira despacio alrededor de la nave, subiendo y bajando un poco.
func _mover_camara(t: float) -> void:
	var angulo := 0.6 + t * 0.05
	_camara.position = Vector3(sin(angulo) * DISTANCIA_CAMARA, 2.5 + sin(t * 0.2) * 1.2, cos(angulo) * DISTANCIA_CAMARA)
	_camara.look_at(Vector3(-3.5, 0, 0))


func comenzar() -> void:
	_menu.visible = false
	var tween := create_tween()
	tween.tween_property(_fundido, "color:a", 1.0, 0.6)
	tween.tween_callback(func() -> void:
		GameState.reiniciar()
		GameState.ir_a("cabina"))


# --- Interfaz ---------------------------------------------------------------

func _crear_interfaz() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 2
	add_child(capa)

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 64)
	capa.add_child(margen)

	_menu = Interfaz.vbox(14)
	_menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margen.add_child(_menu)

	var titulo := Interfaz.etiqueta("SABERTECH", Interfaz.AQUA, 72)
	titulo.add_theme_constant_override("outline_size", 10)
	titulo.add_theme_color_override("font_outline_color", Interfaz.FONDO)
	_menu.add_child(titulo)
	var subtitulo := Interfaz.etiqueta("Misión tripulada a la Luna", Interfaz.CIAN, 26)
	subtitulo.add_theme_constant_override("outline_size", 6)
	subtitulo.add_theme_color_override("font_outline_color", Interfaz.FONDO)
	_menu.add_child(subtitulo)
	var bajada := Interfaz.parrafo("Diseñá la nave, lanzala, cuidá a la tripulación durante el viaje y plantá la bandera en la Luna.", Interfaz.BLANCO, 17)
	bajada.custom_minimum_size.x = 460
	_menu.add_child(bajada)

	var espacio := Control.new()
	espacio.custom_minimum_size.y = 18
	_menu.add_child(espacio)

	var comenzar_boton := Interfaz.boton_principal("Comenzar misión  ⏎", 24)
	comenzar_boton.custom_minimum_size.x = 340
	comenzar_boton.pressed.connect(comenzar)
	_menu.add_child(comenzar_boton)
	var ayuda := _boton_menu("Cómo se juega")
	ayuda.pressed.connect(_mostrar_ayuda.bind(true))
	_boton_graficos = _boton_menu("")
	_boton_graficos.pressed.connect(func() -> void:
		Estilo.cambiar_modo((Estilo.modo + 1) % Estilo.MODOS.size())
		_actualizar_boton_graficos())
	_actualizar_boton_graficos()
	var salir := _boton_menu("Salir")
	salir.pressed.connect(func() -> void: get_tree().quit())

	var pie := Interfaz.etiqueta("Equipo Sabertech · Hackathon 2026", Color(Interfaz.CIAN, 0.7), 14)
	pie.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	pie.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pie.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pie.position += Vector2(-24, -20)
	capa.add_child(pie)

	_ayuda = _crear_ayuda()
	_ayuda.visible = false
	capa.add_child(_ayuda)

	_fundido = ColorRect.new()
	_fundido.color = Color(0, 0, 0, 1)
	_fundido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_fundido)
	create_tween().tween_property(_fundido, "color:a", 0.0, 1.0)


func _boton_menu(texto: String) -> Button:
	var boton := Interfaz.boton(texto, 20)
	boton.custom_minimum_size.x = 340
	boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu.add_child(boton)
	return boton


func _actualizar_boton_graficos() -> void:
	_boton_graficos.text = "Gráficos: %s" % Estilo.MODOS[Estilo.modo]["nombre"]


func _mostrar_ayuda(visible_ayuda: bool) -> void:
	_ayuda.visible = visible_ayuda
	_menu.visible = not visible_ayuda


func _crear_ayuda() -> Control:
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := Interfaz.panel(Color(Interfaz.PANEL, 0.95), 28)
	panel.custom_minimum_size.x = 820
	centro.add_child(panel)
	var caja := Interfaz.vbox(12)
	panel.add_child(caja)
	caja.add_child(Interfaz.etiqueta("Cómo se juega", Interfaz.AQUA, 30))
	var pasos := [
		"1. En la cabina, usá la computadora de misión: diseñá la nave con el presupuesto disponible y lanzala.",
		"2. Durante el viaje a la Luna, repartí la energía en cada tramo, transmití la ciencia y respondé a los imprevistos.",
		"3. Cuidá a la tripulación: comé con F, dormí en la cama del habitáculo para recuperar la cordura. Con poca cordura aparecen alucinaciones.",
		"4. Si algo se rompe afuera, salí por la esclusa con el traje. Pero no te quedes mucho: la soledad pesa.",
		"5. Al llegar, la nave aluniza: salí por la esclusa y plantá la bandera.",
	]
	for paso in pasos:
		caja.add_child(Interfaz.parrafo(paso, Interfaz.BLANCO, 17))
	caja.add_child(HSeparator.new())
	caja.add_child(Interfaz.parrafo(
		"WASD: caminar · Mouse: mirar · E o clic: usar · Mantener E: puertas · F: comer · F2: gráficos · Esc: soltar el mouse",
		Interfaz.CIAN, 15))
	var volver := Interfaz.boton_principal("Volver", 20)
	volver.pressed.connect(_mostrar_ayuda.bind(false))
	caja.add_child(volver)
	return centro
