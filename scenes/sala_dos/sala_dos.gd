extends Node3D
## Sala 2 de la nave: Habitáculo / Módulo de descanso de la tripulación (de Luis).
##
## Sala de planta cuadrada (a diferencia de la cabina alargada/cónica), equipada con:
## - Cama de tripulación: E para dormir (recupera cordura, da hambre y acelera el viaje).
## - Refrigerador / despensa criogénica: E para comer una ración.
## - Tablero de puntos en la pared oeste: cómo se suma y cuánto lleva la partida.
## - Ventana panorámica con vista exterior (espacio/órbita o cielo) sobre la cama.
## - Puerta norte: vuelve a la cabina. Puerta sur (Módulo 03): lleva a la esclusa.
##   Las dos se cruzan manteniendo E (ver scripts/compuerta.gd).

const Jugador := preload("res://scenes/cabina/jugador.gd")
## Los carteles flotantes van sobre el marco de cada puerta, bien visibles.
const ALTURA_CARTEL := 2.75
const NOMBRES_CONSOLA := {
	"consola_cama": "Dormir",
	"consola_refrigerador": "Comer una ración",
	"consola_tablero": "Cómo sumar puntos",
}

var _jugador: Jugador
var _interior: Node3D
var _planeta: Node3D
var _marcador_puerta: Label3D
var _marcador_esclusa: Label3D
var _compuerta: Compuerta
var _mira: Control
var _mensaje: Label
var _indicacion: Label
var _tripulacion: HudTripulacion
var _capa_guia: CanvasLayer
var _guia: Control  # la guía de puntos abierta, o null


func _ready() -> void:
	_interior = Node3D.new()
	add_child(_interior)

	_crear_estructura_sala()
	_crear_cama()
	_crear_refrigerador()
	_crear_mobiliario_extra()
	_crear_tablero()
	_crear_puerta_decorativa()
	_crear_luces()
	_crear_marcador_puerta()

	if GameState.en_orbita():
		_armar_orbita()
	else:
		_armar_plataforma()

	_jugador = Jugador.new()
	_jugador.consola_usada.connect(_usar)
	_interior.add_child(_jugador)
	# Aparece frente a la puerta por la que entró, mirando hacia el centro de la sala.
	if GameState.origen_transicion == "esclusa":
		_jugador.position = Vector3(0.0, 0.05, 2.3)
	else:
		_jugador.position = Vector3(0.0, 0.05, -2.3)
	_jugador.mirar_hacia(_interior.to_global(Vector3(0, 1.4, 0)))

	_crear_hud()
	_crear_compuerta()
	GameState.sueno_cambiado.connect(_on_sueno_cambiado)
	GameState.origen_transicion = ""
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_mostrar_mensaje("Habitáculo de tripulación. Al norte, la cabina; al sur, la esclusa para salir al exterior.")


func _process(delta: float) -> void:
	if _planeta:
		_planeta.rotate_y(delta * 0.01)
	var flotar := sin(Time.get_ticks_msec() / 350.0) * 0.04
	_marcador_puerta.position.y = ALTURA_CARTEL + flotar
	_marcador_esclusa.position.y = ALTURA_CARTEL + flotar
	var consola := _jugador.consola_mirada() if _jugador.activo else ""
	_indicacion.text = "[E] " + NOMBRES_CONSOLA[consola] if NOMBRES_CONSOLA.has(consola) else ""


func _input(evento: InputEvent) -> void:
	# Con la guía de puntos abierta, E o Esc la cierran.
	if _guia and evento is InputEventKey and evento.pressed and not evento.echo \
			and (evento.physical_keycode == KEY_E or evento.physical_keycode == KEY_ESCAPE):
		_cerrar_guia()
		get_viewport().set_input_as_handled()
		return
	if evento is InputEventKey and evento.pressed and evento.physical_keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


# --- Cama y refrigerador ----------------------------------------------------

func _usar(consola: String) -> void:
	match consola:
		"consola_cama":
			var motivo := GameState.dormir()
			if motivo != "":
				_tripulacion.avisar(motivo)
		"consola_refrigerador":
			if GameState.reloj_corriendo():
				_tripulacion.comer()
			else:
				_tripulacion.avisar("Las raciones son para el viaje.")
		"consola_tablero":
			_abrir_guia()


func _abrir_guia() -> void:
	_guia = TableroPuntos.crear_guia()
	_capa_guia.add_child(_guia)
	_jugador.activo = false
	_mira.visible = false


func _cerrar_guia() -> void:
	_guia.queue_free()
	_guia = null
	_jugador.activo = not GameState.durmiendo()
	_mira.visible = _jugador.activo


func _on_sueno_cambiado(dormido: bool, _motivo: String) -> void:
	_jugador.activo = not dormido
	_mira.visible = not dormido


# --- Puertas ----------------------------------------------------------------

func _crear_compuerta() -> void:
	_compuerta = Compuerta.new()
	_compuerta.jugador = _jugador
	_compuerta.agregar(func() -> bool: return _jugador.position.z < -2.0 and absf(_jugador.position.x) < 1.2,
		"Volver a la cabina", "cabina", "habitaculo")
	_compuerta.agregar(func() -> bool: return _jugador.position.z > 2.0 and absf(_jugador.position.x) < 1.2,
		"Ir a la esclusa", "esclusa", "habitaculo")
	add_child(_compuerta)


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


# --- Mobiliario: Cama ---------------------------------------------------------

func _crear_cama() -> void:
	var nodo_cama := Node3D.new()
	# "consola_": el jugador la puede usar (ver jugador.gd).
	nodo_cama.name = "consola_cama"
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


# --- Mobiliario: Refrigerador ------------------------------------------------

func _crear_refrigerador() -> void:
	var nodo_refri := Node3D.new()
	nodo_refri.name = "consola_refrigerador"
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
	# Puerta de la pared sur (Módulo 03): lleva a la esclusa. La hoja tiene
	# colisión para que no se pueda atravesar el hueco caminando.
	var nodo_puerta := Node3D.new()
	nodo_puerta.name = "PuertaDecorativaModulo3"
	nodo_puerta.position = Vector3(0.0, 0.0, 3.44)
	_interior.add_child(nodo_puerta)

	# 1. Hoja sellada, rehundida en el hueco de la pared
	var mat_hoja := StandardMaterial3D.new()
	mat_hoja.albedo_color = Color("#1B2447")
	mat_hoja.metallic = 0.55
	mat_hoja.roughness = 0.45
	_crear_bloque_con_colision(Vector3(0, 1.15, 0.08), Vector3(1.5, 2.3, 0.06), mat_hoja, nodo_puerta)

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
	rotulo.text = "MÓDULO 03\nESCLUSA"
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


# --- Tablero de puntos -------------------------------------------------------

func _crear_tablero() -> void:
	var tablero := TableroPuntos.new()
	tablero.name = "consola_tablero"  # "consola_": se usa con E (ver jugador.gd)
	# Pared oeste, entre la puerta de la cabina y el refrigerador, mirando a la sala.
	tablero.position = Vector3(-3.4, 1.65, -2.3)
	tablero.rotation_degrees.y = 90
	_interior.add_child(tablero)


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
	_marcador_puerta.position = Vector3(0, ALTURA_CARTEL, -3.3)
	_marcador_puerta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marcador_puerta.no_depth_test = true
	_marcador_puerta.pixel_size = 0.003
	_marcador_puerta.font_size = 48
	_marcador_puerta.outline_size = 10
	_marcador_puerta.outline_modulate = Interfaz.FONDO
	_marcador_puerta.modulate = Interfaz.CIAN
	_marcador_puerta.text = "CABINA"
	_interior.add_child(_marcador_puerta)

	_marcador_esclusa = _marcador_puerta.duplicate()
	_marcador_esclusa.position = Vector3(0, ALTURA_CARTEL, 3.3)
	_marcador_esclusa.text = "ESCLUSA · SALIDA AL EXTERIOR"
	_interior.add_child(_marcador_esclusa)


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
	add_child(Espacio.estrellas(600, 600))
	_planeta = Espacio.planeta(GameState.mision.get("destino", "tierra"), 120)
	_planeta.position = Vector3(260, -80, 40)
	add_child(_planeta)


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

	_mensaje = Interfaz.parrafo("", Interfaz.LIMA, 20)
	_mensaje.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_mensaje.custom_minimum_size.x = 700
	_mensaje.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.offset_top = 60
	hud.add_child(_mensaje)

	_indicacion = Interfaz.etiqueta("", Interfaz.BLANCO, 20)
	_indicacion.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_indicacion.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_indicacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicacion.offset_top = 30
	hud.add_child(_indicacion)

	var controles := Interfaz.etiqueta("WASD: caminar · Mouse: mirar · E: usar · Mantener E: puertas · F: comer · Esc: soltar mouse", Color(Interfaz.CIAN, 0.7), 14)
	controles.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controles.position += Vector2(16, -28)
	hud.add_child(controles)

	_tripulacion = HudTripulacion.new()
	add_child(_tripulacion)

	_capa_guia = CanvasLayer.new()
	_capa_guia.layer = 5
	add_child(_capa_guia)


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
