extends Node3D
## Sala 2 de la nave: Habitáculo / Módulo de descanso de la tripulación.
##
## Sala de planta cuadrada (a diferencia de la cabina alargada/cónica), equipada con:
## - Cama de tripulación (maqueta low-poly decorativa sin interacción).
## - Refrigerador / despensa criogénica (maqueta low-poly decorativa sin interacción).
## - Ventana panorámica con vista exterior (espacio/órbita o cielo) sobre la cama.
## - Compuerta de acceso con teletransporte a la cabina manteniendo pulsada la tecla E.
## - Tercera puerta decorativa (Módulo 03) en la pared sur, sellada y sin interacción.

const Jugador := preload("res://scenes/cabina/jugador.gd")
const TIEMPO_MANTENER_TELEPORT := 1.1
const COLOR_PLANETA := {"tierra": Color("#2E6FD0"), "luna": Color("#A3A6B0"), "marte": Color("#C1552B")}

var _jugador: Jugador
var _interior: Node3D
var _planeta: Node3D
var _marcador_puerta: Label3D
var _mira: Control
var _indicacion: Label
var _mensaje: Label
var _contenedor_teleport: VBoxContainer
var _barra_teleport: ProgressBar
var _telon_fade: ColorRect
var _tiempo_mantener_e := 0.0
var _cerca_de_puerta := false
var _transicionando := false


func _ready() -> void:
	_interior = Node3D.new()
	add_child(_interior)

	_crear_estructura_sala()
	_crear_cama()
	_crear_refrigerador()
	_crear_mobiliario_extra()
	_crear_puerta_decorativa()
	_crear_luces()
	_crear_marcador_puerta()

	if GameState.en_orbita():
		_armar_orbita()
	else:
		_armar_plataforma()

	_jugador = Jugador.new()
	# Aparece justo delante de la compuerta norte mirando hacia el centro de la sala
	_jugador.position = Vector3(0.0, 0.05, -2.3)
	_jugador.rotation.y = 0.0
	_interior.add_child(_jugador)

	_crear_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_mostrar_mensaje("Habitáculo de tripulación (Sala 2). Espacio de descanso y provisiones.")


func _process(delta: float) -> void:
	if _planeta:
		_planeta.rotate_y(delta * 0.01)
	if _marcador_puerta:
		_marcador_puerta.position.y = 2.05 + sin(Time.get_ticks_msec() / 350.0) * 0.04
	_procesar_teleport(delta)


func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and evento.physical_keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


# --- Teleport hacia la Cabina ------------------------------------------------

func _procesar_teleport(delta: float) -> void:
	if _transicionando or not _jugador.activo:
		return

	# La puerta hacia la cabina está en Z = -3.5 (frente/norte de la sala)
	var pos := _jugador.position
	_cerca_de_puerta = (pos.z < -1.8 and abs(pos.x) < 1.6)

	if _cerca_de_puerta:
		_indicacion.text = "[E] Mantener: Volver a Cabina"
		var e_presionada: bool = Input.is_physical_key_pressed(KEY_E)
		if e_presionada:
			_tiempo_mantener_e += delta
			_contenedor_teleport.visible = true
			_barra_teleport.value = clampf(_tiempo_mantener_e / TIEMPO_MANTENER_TELEPORT, 0.0, 1.0)
			if _tiempo_mantener_e >= TIEMPO_MANTENER_TELEPORT:
				_ejecutar_teleport()
		else:
			if _tiempo_mantener_e > 0.0:
				_tiempo_mantener_e = maxf(0.0, _tiempo_mantener_e - delta * 3.0)
				_barra_teleport.value = clampf(_tiempo_mantener_e / TIEMPO_MANTENER_TELEPORT, 0.0, 1.0)
			else:
				_contenedor_teleport.visible = false
	else:
		_indicacion.text = ""
		if _tiempo_mantener_e > 0.0:
			_tiempo_mantener_e = 0.0
			_contenedor_teleport.visible = false


func _ejecutar_teleport() -> void:
	_transicionando = true
	_jugador.activo = false
	var tween := create_tween()
	tween.tween_property(_telon_fade, "color:a", 1.0, 0.3)
	tween.tween_callback(func():
		GameState.origen_transicion = "sala_dos"
		GameState.ir_a("cabina")
	)


# --- Geometría y Estructura Cuadrada ----------------------------------------

func _crear_estructura_sala() -> void:
	# Sala cuadrada de 7.0m x 7.0m x 3.2m de altura interior.
	var mat_pared := StandardMaterial3D.new()
	mat_pared.albedo_color = Color("#141C3B")
	mat_pared.roughness = 0.65

	var mat_piso := StandardMaterial3D.new()
	mat_piso.albedo_color = Color("#0C1128")
	mat_piso.roughness = 0.45

	var mat_techo := StandardMaterial3D.new()
	mat_techo.albedo_color = Color("#111736")
	mat_techo.roughness = 0.8

	var mat_franja := StandardMaterial3D.new()
	mat_franja.albedo_color = Interfaz.AQUA
	mat_franja.roughness = 0.3
	mat_franja.emission_enabled = true
	mat_franja.emission = Color(Interfaz.AQUA) * 0.4

	var mat_marco := StandardMaterial3D.new()
	mat_marco.albedo_color = Color("#2C3A66")
	mat_marco.metallic = 0.6
	mat_marco.roughness = 0.3

	var mat_vidrio := StandardMaterial3D.new()
	mat_vidrio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_vidrio.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_vidrio.albedo_color = Color(Interfaz.CIAN, 0.12)

	# 1. Suelo
	_crear_bloque_con_colision(Vector3(0, -0.1, 0), Vector3(7.2, 0.2, 7.2), mat_piso)

	# Baldosas / franjas decorativas en el suelo
	for z_pos in [-2.0, 0.0, 2.0]:
		var linea := _crear_malla(Vector3(0, 0.005, z_pos), Vector3(6.6, 0.01, 0.06), mat_franja)
		_interior.add_child(linea)

	# 2. Techo
	_crear_bloque_con_colision(Vector3(0, 3.2, 0), Vector3(7.2, 0.2, 7.2), mat_techo)

	# Panel central lumínico en el techo
	var mat_luz_techo := StandardMaterial3D.new()
	mat_luz_techo.albedo_color = Color("#E6F6FF")
	mat_luz_techo.emission_enabled = true
	mat_luz_techo.emission = Color("#E6F6FF")
	mat_luz_techo.emission_energy_multiplier = 1.2
	var panel_techo := _crear_malla(Vector3(0, 3.09, 0), Vector3(3.0, 0.02, 3.0), mat_luz_techo)
	_interior.add_child(panel_techo)

	# 3. Paredes cuadradas (altura 3.2m)
	# Pared Este (+X = 3.5, con ventana panorámica sobre la cama)
	# El hueco va de Z = -0.7 a Z = 1.5 y de Y = 1.05 a Y = 2.35.
	_crear_bloque_con_colision(Vector3(3.55, 1.5, -2.15), Vector3(0.2, 3.2, 2.9), mat_pared)
	_crear_bloque_con_colision(Vector3(3.55, 1.5, 2.55), Vector3(0.2, 3.2, 2.1), mat_pared)
	_crear_bloque_con_colision(Vector3(3.55, 0.475, 0.4), Vector3(0.2, 1.15, 2.2), mat_pared)
	_crear_bloque_con_colision(Vector3(3.55, 2.725, 0.4), Vector3(0.2, 0.75, 2.2), mat_pared)

	# Franjas decorativas de la pared este, cortadas a la altura de la ventana
	var franja_este_n := _crear_malla(Vector3(3.44, 1.3, -2.05), Vector3(0.02, 0.08, 2.7), mat_franja)
	var franja_este_s := _crear_malla(Vector3(3.44, 1.3, 2.45), Vector3(0.02, 0.08, 1.9), mat_franja)
	_interior.add_child(franja_este_n)
	_interior.add_child(franja_este_s)

	# Marco de la ventana sobre la cama
	var marco_top := _crear_malla(Vector3(3.5, 2.35, 0.4), Vector3(0.15, 0.1, 2.3), mat_marco)
	var marco_bot := _crear_malla(Vector3(3.5, 1.05, 0.4), Vector3(0.15, 0.1, 2.3), mat_marco)
	var marco_der := _crear_malla(Vector3(3.5, 1.7, 1.5), Vector3(0.15, 1.4, 0.1), mat_marco)
	var marco_izq := _crear_malla(Vector3(3.5, 1.7, -0.7), Vector3(0.15, 1.4, 0.1), mat_marco)
	_interior.add_child(marco_top)
	_interior.add_child(marco_bot)
	_interior.add_child(marco_der)
	_interior.add_child(marco_izq)

	# Vidrio de la ventana
	var vidrio := _crear_malla(Vector3(3.52, 1.7, 0.4), Vector3(0.02, 1.3, 2.2), mat_vidrio)
	_interior.add_child(vidrio)

	# Pared Oeste (-X = -3.5)
	_crear_bloque_con_colision(Vector3(-3.55, 1.5, 0), Vector3(0.2, 3.2, 7.2), mat_pared)
	var franja_oeste := _crear_malla(Vector3(-3.44, 1.3, 0), Vector3(0.02, 0.08, 6.8), mat_franja)
	_interior.add_child(franja_oeste)

	# Pared Norte (-Z = -3.5, con marco y hueco de puerta central de 1.6m de ancho)
	_crear_bloque_con_colision(Vector3(-2.2, 1.5, -3.55), Vector3(2.8, 3.2, 0.2), mat_pared)
	_crear_bloque_con_colision(Vector3(2.2, 1.5, -3.55), Vector3(2.8, 3.2, 0.2), mat_pared)
	_crear_bloque_con_colision(Vector3(0, 2.7, -3.55), Vector3(1.6, 0.8, 0.2), mat_pared)

	# Hoja y marco de compuerta hacia la cabina
	var mat_puerta := StandardMaterial3D.new()
	mat_puerta.albedo_color = Color("#1D274D")
	mat_puerta.metallic = 0.5
	mat_puerta.roughness = 0.4
	var puerta_obj := _crear_bloque_con_colision(Vector3(0, 1.15, -3.52), Vector3(1.5, 2.3, 0.08), mat_puerta)
	
	# Franja luminosa en la compuerta
	var franja_puerta := _crear_malla(Vector3(0, 1.15, -3.47), Vector3(0.08, 2.0, 0.02), mat_franja)
	_interior.add_child(franja_puerta)

	# Pared Sur (+Z = +3.5, con hueco de puerta central de 1.6m para el Módulo 03)
	_crear_bloque_con_colision(Vector3(-2.2, 1.5, 3.55), Vector3(2.8, 3.2, 0.2), mat_pared)
	_crear_bloque_con_colision(Vector3(2.2, 1.5, 3.55), Vector3(2.8, 3.2, 0.2), mat_pared)
	_crear_bloque_con_colision(Vector3(0, 2.7, 3.55), Vector3(1.6, 0.8, 0.2), mat_pared)


# --- Mobiliario: Cama (Sin interacción) ---------------------------------------

func _crear_cama() -> void:
	var nodo_cama := Node3D.new()
	nodo_cama.name = "CamaTripulacion"
	# Pegada a la pared lateral derecha
	nodo_cama.position = Vector3(2.35, 0.0, 0.4)
	_interior.add_child(nodo_cama)

	# 1. Base metálica estructurada
	var mat_base := StandardMaterial3D.new()
	mat_base.albedo_color = Color("#17203E")
	mat_base.metallic = 0.4
	mat_base.roughness = 0.5
	_crear_bloque_con_colision(Vector3(0, 0.18, 0), Vector3(1.3, 0.36, 2.2), mat_base, nodo_cama)

	# Luz difusa inferior estilo Frutiger/sci-fi
	var mat_glow := StandardMaterial3D.new()
	mat_glow.albedo_color = Interfaz.AQUA
	mat_glow.emission_enabled = true
	mat_glow.emission = Color(Interfaz.AQUA) * 0.8
	var zocalo_glow := _crear_malla(Vector3(-0.6, 0.03, 0), Vector3(0.04, 0.05, 2.1), mat_glow)
	nodo_cama.add_child(zocalo_glow)

	# 2. Respaldo acolchado contra la pared
	var mat_respaldo := StandardMaterial3D.new()
	mat_respaldo.albedo_color = Color("#0C1226")
	mat_respaldo.roughness = 0.9
	var respaldo := _crear_malla(Vector3(0.66, 0.6, 0), Vector3(0.08, 0.8, 2.2), mat_respaldo)
	nodo_cama.add_child(respaldo)

	# 3. Colchón
	var mat_colchon := StandardMaterial3D.new()
	mat_colchon.albedo_color = Color("#D9E3ED")
	mat_colchon.roughness = 0.8
	var colchon := _crear_malla(Vector3(0, 0.44, 0), Vector3(1.2, 0.2, 2.1), mat_colchon)
	nodo_cama.add_child(colchon)

	# 4. Almohada
	var mat_almohada := StandardMaterial3D.new()
	mat_almohada.albedo_color = Interfaz.BLANCO
	mat_almohada.roughness = 0.95
	var almohada := _crear_malla(Vector3(0.1, 0.58, -0.75), Vector3(0.9, 0.12, 0.42), mat_almohada)
	nodo_cama.add_child(almohada)

	# 5. Frazada / edredón térmico con colores Sabertech
	var mat_frazada := StandardMaterial3D.new()
	mat_frazada.albedo_color = Color("#0E1638")
	mat_frazada.roughness = 0.7
	var frazada := _crear_malla(Vector3(0, 0.55, 0.35), Vector3(1.22, 0.05, 1.4), mat_frazada)
	nodo_cama.add_child(frazada)

	# Franja decorativa lima y cian en la frazada
	var franja_cama1 := _crear_malla(Vector3(0, 0.58, -0.2), Vector3(1.23, 0.02, 0.08), mat_glow)
	var mat_lima := StandardMaterial3D.new()
	mat_lima.albedo_color = Interfaz.LIMA
	mat_lima.emission_enabled = true
	mat_lima.emission = Color(Interfaz.LIMA) * 0.4
	var franja_cama2 := _crear_malla(Vector3(0, 0.58, -0.08), Vector3(1.23, 0.02, 0.05), mat_lima)
	nodo_cama.add_child(franja_cama1)
	nodo_cama.add_child(franja_cama2)

	# 6. Mesita de soporte lateral
	var mat_mesa := StandardMaterial3D.new()
	mat_mesa.albedo_color = Color("#222D54")
	_crear_bloque_con_colision(Vector3(0.1, 0.25, -1.35), Vector3(0.7, 0.5, 0.45), mat_mesa, nodo_cama)

	var reloj := Label3D.new()
	reloj.position = Vector3(0.1, 0.55, -1.35)
	reloj.rotation_degrees = Vector3(0, 90, 0)
	reloj.text = "04:20 MET\nCABIN OK"
	reloj.font_size = 20
	reloj.modulate = Interfaz.LIMA
	reloj.pixel_size = 0.002
	nodo_cama.add_child(reloj)


# --- Mobiliario: Refrigerador (Sin interacción) ------------------------------

func _crear_refrigerador() -> void:
	var nodo_refri := Node3D.new()
	nodo_refri.name = "RefrigeradorRaciones"
	# Apoyado a ras contra la pared oeste (cara interna en X = -3.45).
	nodo_refri.position = Vector3(-3.025, 0.0, -0.7)
	_interior.add_child(nodo_refri)

	# 1. Cuerpo principal del refrigerador
	var mat_refri := StandardMaterial3D.new()
	mat_refri.albedo_color = Color("#222E54")
	mat_refri.metallic = 0.4
	mat_refri.roughness = 0.35
	_crear_bloque_con_colision(Vector3(0, 1.05, 0), Vector3(0.85, 2.1, 0.9), mat_refri, nodo_refri)

	# 2. Puerta superior (congelador criogénico de muestras)
	var mat_puertas := StandardMaterial3D.new()
	mat_puertas.albedo_color = Color("#314173")
	mat_puertas.metallic = 0.5
	mat_puertas.roughness = 0.3
	var puerta_sup := _crear_malla(Vector3(0.44, 1.65, 0), Vector3(0.04, 0.75, 0.84), mat_puertas)
	nodo_refri.add_child(puerta_sup)

	# 3. Puerta inferior (conservador de raciones y bebidas)
	var puerta_inf := _crear_malla(Vector3(0.44, 0.65, 0), Vector3(0.04, 1.15, 0.84), mat_puertas)
	nodo_refri.add_child(puerta_inf)

	# 4. Manijas empotradas
	var mat_manija := StandardMaterial3D.new()
	mat_manija.albedo_color = Color("#A8BFDB")
	mat_manija.metallic = 0.8
	mat_manija.roughness = 0.2
	var manija_sup := _crear_malla(Vector3(0.48, 1.4, 0.3), Vector3(0.04, 0.22, 0.04), mat_manija)
	var manija_inf := _crear_malla(Vector3(0.48, 1.1, 0.3), Vector3(0.04, 0.35, 0.04), mat_manija)
	nodo_refri.add_child(manija_sup)
	nodo_refri.add_child(manija_inf)

	# 5. Display digital térmico
	var mat_display := StandardMaterial3D.new()
	mat_display.albedo_color = Color("#070B18")
	var pantalla_disp := _crear_malla(Vector3(0.47, 1.85, 0), Vector3(0.01, 0.14, 0.34), mat_display)
	nodo_refri.add_child(pantalla_disp)

	var texto_temp := Label3D.new()
	texto_temp.position = Vector3(0.48, 1.85, 0)
	texto_temp.rotation_degrees = Vector3(0, 90, 0)
	texto_temp.text = "-4°C | COLD"
	texto_temp.font_size = 20
	texto_temp.modulate = Interfaz.LIMA
	texto_temp.pixel_size = 0.002
	nodo_refri.add_child(texto_temp)

	# 6. Rejilla inferior de ventilación
	var mat_rejilla := StandardMaterial3D.new()
	mat_rejilla.albedo_color = Color("#080D1D")
	var rejilla := _crear_malla(Vector3(0.44, 0.06, 0), Vector3(0.03, 0.08, 0.8), mat_rejilla)
	nodo_refri.add_child(rejilla)


# --- Puerta decorativa del Módulo 03 (solo adorno, sin acceso) ----------------

func _crear_puerta_decorativa() -> void:
	# Tercera puerta en la pared sur, en el mismo hueco donde antes estaba la
	# ventana panorámica. Es únicamente fachada: no abre, no tiene colisión
	# propia ni teletransporte; la ventana ahora va sobre la cama (pared este).
	var nodo_puerta := Node3D.new()
	nodo_puerta.name = "PuertaDecorativaModulo3"
	nodo_puerta.position = Vector3(0.0, 0.0, 3.44)
	_interior.add_child(nodo_puerta)

	# 1. Hoja sellada, rehundida en el hueco de la pared
	var mat_hoja := StandardMaterial3D.new()
	mat_hoja.albedo_color = Color("#1B2447")
	mat_hoja.metallic = 0.55
	mat_hoja.roughness = 0.45
	var hoja := _crear_malla(Vector3(0, 1.15, 0.08), Vector3(1.5, 2.3, 0.06), mat_hoja)
	nodo_puerta.add_child(hoja)

	# 2. Marco metálico por el lado de la sala
	var mat_marco := StandardMaterial3D.new()
	mat_marco.albedo_color = Color("#2C3A66")
	mat_marco.metallic = 0.7
	mat_marco.roughness = 0.25
	var poste_izq := _crear_malla(Vector3(-0.78, 1.25, 0), Vector3(0.12, 2.5, 0.1), mat_marco)
	var poste_der := _crear_malla(Vector3(0.78, 1.25, 0), Vector3(0.12, 2.5, 0.1), mat_marco)
	var dintel := _crear_malla(Vector3(0, 2.44, 0), Vector3(1.68, 0.14, 0.1), mat_marco)
	nodo_puerta.add_child(poste_izq)
	nodo_puerta.add_child(poste_der)
	nodo_puerta.add_child(dintel)

	# 3. Franja luminosa central de estado
	var mat_franja := StandardMaterial3D.new()
	mat_franja.albedo_color = Interfaz.AQUA
	mat_franja.emission_enabled = true
	mat_franja.emission = Color(Interfaz.AQUA) * 0.8
	var franja := _crear_malla(Vector3(0, 1.15, 0.04), Vector3(0.08, 1.9, 0.02), mat_franja)
	nodo_puerta.add_child(franja)

	# 4. Manija empotrada
	var mat_manija := StandardMaterial3D.new()
	mat_manija.albedo_color = Color("#A8BFDB")
	mat_manija.metallic = 0.8
	mat_manija.roughness = 0.2
	var manija := _crear_malla(Vector3(0.55, 1.1, 0.04), Vector3(0.05, 0.35, 0.05), mat_manija)
	nodo_puerta.add_child(manija)

	# 5. Panel de identificación del módulo
	var mat_panel := StandardMaterial3D.new()
	mat_panel.albedo_color = Color("#070B18")
	var panel := _crear_malla(Vector3(-0.5, 1.9, 0.05), Vector3(0.3, 0.18, 0.008), mat_panel)
	nodo_puerta.add_child(panel)

	var rotulo := Label3D.new()
	rotulo.position = Vector3(-0.5, 1.9, 0.043)
	rotulo.rotation_degrees = Vector3(0, 180, 0)
	rotulo.text = "MÓDULO 03"
	rotulo.font_size = 16
	rotulo.modulate = Interfaz.CIAN
	rotulo.pixel_size = 0.002
	nodo_puerta.add_child(rotulo)

	# 6. Luz de acento sobre la puerta
	var luz_puerta := OmniLight3D.new()
	luz_puerta.position = Vector3(0, 2.3, 2.9)
	luz_puerta.light_color = Color(Interfaz.AQUA)
	luz_puerta.light_energy = 0.4
	luz_puerta.omni_range = 3.0
	_interior.add_child(luz_puerta)


# --- Mobiliario extra y detalles --------------------------------------------

func _crear_mobiliario_extra() -> void:
	# Casilleros de tripulación junto al refrigerador
	var mat_casillero := StandardMaterial3D.new()
	mat_casillero.albedo_color = Color("#182348")
	mat_casillero.roughness = 0.6
	_crear_bloque_con_colision(Vector3(-2.95, 1.1, 1.1), Vector3(0.85, 2.2, 1.2), mat_casillero)

	var rotulo := Label3D.new()
	rotulo.position = Vector3(-2.5, 2.0, 1.1)
	rotulo.rotation_degrees = Vector3(0, 90, 0)
	rotulo.text = "LOCKERS 01-04"
	rotulo.font_size = 18
	rotulo.modulate = Interfaz.CIAN
	rotulo.pixel_size = 0.002
	_interior.add_child(rotulo)

	# Alfombra central cuadrangular
	var mat_alfombra := StandardMaterial3D.new()
	mat_alfombra.albedo_color = Color("#111A3E")
	mat_alfombra.roughness = 0.9
	var alfombra := _crear_malla(Vector3(0, 0.01, 0.2), Vector3(2.6, 0.01, 2.6), mat_alfombra)
	_interior.add_child(alfombra)


# --- Iluminación -------------------------------------------------------------

func _crear_luces() -> void:
	for pos in [Vector3(-1.3, 2.7, 0.0), Vector3(1.3, 2.7, 0.0)]:
		var luz := OmniLight3D.new()
		luz.position = pos
		luz.light_color = Color("#E6F3FF")
		luz.light_energy = 0.85
		luz.omni_range = 6.5
		_interior.add_child(luz)

	# Luz suave de acento sobre la compuerta
	var luz_puerta := OmniLight3D.new()
	luz_puerta.position = Vector3(0, 2.6, -3.0)
	luz_puerta.light_color = Color(Interfaz.AQUA)
	luz_puerta.light_energy = 0.5
	luz_puerta.omni_range = 3.5
	_interior.add_child(luz_puerta)


func _crear_marcador_puerta() -> void:
	_marcador_puerta = Label3D.new()
	_marcador_puerta.position = Vector3(0, 2.05, -3.3)
	_marcador_puerta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marcador_puerta.no_depth_test = true
	_marcador_puerta.pixel_size = 0.002
	_marcador_puerta.font_size = 38
	_marcador_puerta.outline_size = 10
	_marcador_puerta.outline_modulate = Interfaz.FONDO
	_marcador_puerta.modulate = Interfaz.CIAN
	_marcador_puerta.text = "PUERTA A CABINA\n[Mantener E para volver]"
	_interior.add_child(_marcador_puerta)


# --- Entorno Exterior (Espacio / Cielo) --------------------------------------

func _armar_plataforma() -> void:
	var cielo := ProceduralSkyMaterial.new()
	cielo.sky_top_color = Color("#3D7FD9")
	cielo.sky_horizon_color = Color("#BFE3F5")
	cielo.ground_horizon_color = Color("#9DB0A0")
	cielo.ground_bottom_color = Color("#4E5A48")
	_entorno(Environment.BG_SKY, cielo, Color.BLACK)
	_sol(Vector3(-35, -40, 0), 1.2)


func _armar_orbita() -> void:
	_entorno(Environment.BG_COLOR, null, Color("#04071A"))
	_sol(Vector3(-20, 60, 0), 1.4)
	_crear_estrellas()

	var destino: String = GameState.mision.get("destino", "tierra")
	_planeta = Node3D.new()
	_planeta.position = Vector3(-40, -80, 260)
	add_child(_planeta)
	_planeta.add_child(_esfera(120, COLOR_PLANETA.get(destino, Color.GRAY), 32))
	if destino == "tierra":
		var atmosfera := _esfera(125, Color(Interfaz.CIAN, 0.18), 32)
		var material := atmosfera.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_planeta.add_child(atmosfera)


func _entorno(fondo: Environment.BGMode, cielo: Material, color: Color) -> void:
	var entorno := Environment.new()
	entorno.background_mode = fondo
	entorno.background_color = color
	if cielo:
		entorno.sky = Sky.new()
		entorno.sky.sky_material = cielo
		entorno.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	else:
		entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		entorno.ambient_light_color = Color("#2A3358")
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	entorno.glow_enabled = true
	var nodo := WorldEnvironment.new()
	nodo.environment = entorno
	add_child(nodo)


func _sol(rotacion: Vector3, energia: float) -> void:
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = rotacion
	sol.light_energy = energia
	sol.shadow_enabled = true
	add_child(sol)


func _crear_estrellas() -> void:
	var malla := QuadMesh.new()
	malla.size = Vector2(1.5, 1.5)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Interfaz.BLANCO
	malla.material = material

	var multimalla := MultiMesh.new()
	multimalla.transform_format = MultiMesh.TRANSFORM_3D
	multimalla.mesh = malla
	multimalla.instance_count = 600
	var azar := RandomNumberGenerator.new()
	azar.seed = 99
	for i in multimalla.instance_count:
		var direccion := Vector3(azar.randfn(), azar.randfn(), azar.randfn()).normalized()
		multimalla.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * azar.randf_range(0.5, 1.5)), direccion * 600))
	var estrellas := MultiMeshInstance3D.new()
	estrellas.multimesh = multimalla
	add_child(estrellas)


func _esfera(radio: float, color: Color, segmentos: int) -> MeshInstance3D:
	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2
	malla.radial_segments = segmentos
	malla.rings = segmentos / 2
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	var instancia := MeshInstance3D.new()
	instancia.mesh = malla
	instancia.material_override = material
	return instancia


# --- HUD e Indicadores ------------------------------------------------------

func _crear_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	_mira = ColorRect.new()
	(_mira as ColorRect).color = Color(Interfaz.BLANCO, 0.8)
	_mira.size = Vector2(4, 4)
	_mira.set_anchors_preset(Control.PRESET_CENTER)
	_mira.position -= Vector2(2, 2)
	_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_mira)

	_indicacion = Interfaz.etiqueta("", Interfaz.BLANCO, 20)
	_indicacion.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_indicacion.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_indicacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicacion.offset_top = 30
	hud.add_child(_indicacion)

	_contenedor_teleport = VBoxContainer.new()
	_contenedor_teleport.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_contenedor_teleport.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_contenedor_teleport.grow_vertical = Control.GROW_DIRECTION_BOTH
	_contenedor_teleport.position.y += 65
	_contenedor_teleport.custom_minimum_size = Vector2(260, 40)
	_contenedor_teleport.visible = false
	hud.add_child(_contenedor_teleport)

	var lbl_mantener := Interfaz.etiqueta("MANTENIENDO [E]...", Interfaz.CIAN, 14)
	lbl_mantener.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contenedor_teleport.add_child(lbl_mantener)

	_barra_teleport = Interfaz.barra(Interfaz.LIMA, 1.0)
	_barra_teleport.custom_minimum_size = Vector2(240, 10)
	_contenedor_teleport.add_child(_barra_teleport)

	_mensaje = Interfaz.parrafo("", Interfaz.LIMA, 20)
	_mensaje.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_mensaje.custom_minimum_size.x = 700
	_mensaje.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.offset_top = 60
	hud.add_child(_mensaje)

	var controles := Interfaz.etiqueta("WASD: caminar · Mouse: mirar · E: interactuar · Esc: soltar mouse", Color(Interfaz.CIAN, 0.7), 14)
	controles.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controles.position += Vector2(16, -28)
	hud.add_child(controles)

	_telon_fade = ColorRect.new()
	_telon_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_telon_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_telon_fade.color = Color(0, 0, 0, 1.0)
	hud.add_child(_telon_fade)

	var tween := create_tween()
	tween.tween_property(_telon_fade, "color:a", 0.0, 0.4)


func _mostrar_mensaje(texto: String) -> void:
	_mensaje.text = texto
	_mensaje.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(_mensaje, "modulate:a", 0.0, 1.0)


# --- Utilidades de Creación de Geometría -------------------------------------

func _crear_malla(pos: Vector3, tam: Vector3, mat: Material) -> MeshInstance3D:
	var caja := BoxMesh.new()
	caja.size = tam
	var inst := MeshInstance3D.new()
	inst.mesh = caja
	inst.position = pos
	inst.material_override = mat
	return inst


func _crear_bloque_con_colision(pos: Vector3, tam: Vector3, mat: Material, padre: Node3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos

	var caja := BoxMesh.new()
	caja.size = tam
	var inst := MeshInstance3D.new()
	inst.mesh = caja
	inst.material_override = mat
	body.add_child(inst)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = tam
	col.shape = shape
	body.add_child(col)

	# Godot 4.7 no re-parenta al hacer add_child: hay que colgar el bloque del
	# contenedor correcto desde el principio (mueble o sala) para que la
	# posición local quede relativa a ese nodo.
	var contenedor: Node3D = padre if padre else _interior
	contenedor.add_child(body)
	return body
