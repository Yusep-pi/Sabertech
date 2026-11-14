extends Node3D
## Fase 3: lanzamiento en tercera persona, como una cinemática con varios planos.
##
## El resultado ya lo decidió GameState.lanzar(); acá solo se cuenta:
## plano general, motores, despegue, seguimiento con teleobjetivo y ascenso.
## Si el cohete falla, la secuencia cambia en el plano que corresponde.
## Espacio, Enter o Esc saltan al resultado.

const MODELO_PLATAFORMA := preload("res://assets/modelos/plataforma.glb")
const MODELO_COHETES := preload("res://assets/modelos/cohetes.glb")

var _vehiculo: Node3D  # cohete + nave; es lo que sube
var _altura_vehiculo := 20.0
var _velocidad := 0.0
var _aceleracion := 0.0
var _temblor := 0.0  # amplitud del temblor del vehículo (falla por masa)
var _llama: MeshInstance3D
var _luz_motor: OmniLight3D
var _humo_suelo: GPUParticles3D
var _estela: GPUParticles3D

var _camara: Camera3D
var _mirar_a: Callable  # devuelve el punto al que mira la cámara cada cuadro
var _vaiven := 0.0  # cámara en mano: cuánto se mueve sola
var _sacudida := 0.0
var _tiempo := 0.0

var _subtitulo: Label
var _terminado := false


func _ready() -> void:
	_armar_escenario()
	_armar_vehiculo()
	_armar_efectos()
	_armar_camara_y_hud()
	_secuencia()


func _process(delta: float) -> void:
	_tiempo += delta
	if _aceleracion > 0.0:
		_velocidad += _aceleracion * delta
		_vehiculo.position.y += _velocidad * delta
		# Una vez que el cohete dejó la plataforma, el humo del suelo se va disipando.
		if _humo_suelo.emitting and _vehiculo.position.y > 12.0:
			_humo_suelo.emitting = false
	if _temblor > 0.0:
		_vehiculo.position.x = randf_range(-_temblor, _temblor)
		_vehiculo.position.z = randf_range(-_temblor, _temblor)
	if _llama.visible:
		_llama.scale = Vector3(1, randf_range(0.85, 1.15), 1)
		_luz_motor.light_energy = randf_range(6.0, 9.0)

	if _mirar_a.is_valid():
		var objetivo: Vector3 = _mirar_a.call()
		# Un poco de cámara en mano y sacudida por el rugido de los motores, para que se sienta natural.
		var mano := Vector3(sin(_tiempo * 0.7), sin(_tiempo * 0.9 + 1.0), 0) * _vaiven
		var golpe := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _sacudida
		_camara.look_at(objetivo + mano + golpe)
	_sacudida = move_toward(_sacudida, 0.0, delta * 0.3)


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not _terminado:
		if evento.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			_terminar()


# --- Escenario --------------------------------------------------------------

func _armar_escenario() -> void:
	var cielo := ProceduralSkyMaterial.new()
	cielo.sky_top_color = Color("#3D7FD9")
	cielo.sky_horizon_color = Color("#BFE3F5")
	cielo.ground_horizon_color = Color("#9DB0A0")
	cielo.ground_bottom_color = Color("#4E5A48")
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_SKY
	entorno.sky = Sky.new()
	entorno.sky.sky_material = cielo
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	entorno.glow_enabled = true
	entorno.fog_enabled = true
	entorno.fog_light_color = Color("#BFE3F5")
	entorno.fog_density = 0.0006
	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	add_child(mundo)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, -40, 0)
	sol.light_energy = 1.2
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 300
	add_child(sol)

	add_child(MODELO_PLATAFORMA.instantiate())


func _armar_vehiculo() -> void:
	_vehiculo = Node3D.new()
	add_child(_vehiculo)
	var id_cohete: String = GameState.pieza_elegida("cohete").get("id", "cohete_mediano")
	var cohetes := MODELO_COHETES.instantiate()
	_vehiculo.add_child(cohetes)
	var cohete: Node3D
	for hijo in cohetes.get_children():
		hijo.visible = hijo.name == id_cohete
		if hijo.name == id_cohete:
			cohete = hijo
	# Los propulsores laterales quedan perpendiculares a la torre.
	cohetes.rotation_degrees.y = 90

	var nave := Nave3D.new()
	nave.mostrar(GameState.seleccion, true)
	var carga := cohete.find_child(id_cohete + "_carga", true, false) as Node3D
	carga.add_child(nave)
	_altura_vehiculo = carga.position.y + 3.0


func _armar_efectos() -> void:
	_llama = MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = 1.0
	cono.bottom_radius = 0.2
	cono.height = 7.0
	cono.radial_segments = 10
	var fuego := StandardMaterial3D.new()
	fuego.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fuego.albedo_color = Color("#FFC36B")
	fuego.emission_enabled = true
	fuego.emission = Interfaz.ALERTA
	fuego.emission_energy_multiplier = 3.0
	cono.material = fuego
	_llama.mesh = cono
	_llama.position.y = -4.5
	_llama.visible = false
	_vehiculo.add_child(_llama)

	_luz_motor = OmniLight3D.new()
	_luz_motor.light_color = Color("#FFB060")
	_luz_motor.omni_range = 40
	_luz_motor.position.y = -3
	_luz_motor.visible = false
	_vehiculo.add_child(_luz_motor)

	# El humo del suelo se abre en anillo y bajo, para no tapar al cohete.
	_humo_suelo = _humo(110, 2.5, Vector3(1, 0, 0), 7.0, 7.0, 0.4, true)
	_humo_suelo.position.y = 0.5
	add_child(_humo_suelo)
	_estela = _humo(140, 4.0, Vector3(0, -1, 0), 4.0, 5.0, 0.5)
	_estela.position.y = -4
	_vehiculo.add_child(_estela)


func _humo(cantidad: int, vida: float, direccion: Vector3, velocidad: float, tamano: float,
		opacidad := 0.7, en_anillo := false) -> GPUParticles3D:
	var proceso := ParticleProcessMaterial.new()
	proceso.direction = direccion
	proceso.spread = 180.0 if en_anillo else (70.0 if direccion.y > -0.5 else 15.0)
	# Con flatness 1 la dispersión queda en el plano horizontal: un anillo alrededor de la base.
	proceso.flatness = 1.0 if en_anillo else 0.0
	proceso.initial_velocity_min = velocidad * 0.5
	proceso.initial_velocity_max = velocidad
	proceso.gravity = Vector3(0, 0.2 if en_anillo else 0.6, 0)
	proceso.damping_min = 1.0
	proceso.damping_max = 2.0
	proceso.scale_min = 0.6
	proceso.scale_max = 1.2
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.3))
	curva.add_point(Vector2(1, 1.0))
	var textura_curva := CurveTexture.new()
	textura_curva.curve = curva
	proceso.scale_curve = textura_curva
	var gradiente := Gradient.new()
	gradiente.set_color(0, Color(0.95, 0.95, 0.95, opacidad))
	gradiente.set_color(1, Color(0.8, 0.82, 0.86, 0.0))
	var textura_color := GradientTexture1D.new()
	textura_color.gradient = gradiente
	proceso.color_ramp = textura_color

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _textura_bocanada()
	var quad := QuadMesh.new()
	quad.size = Vector2(tamano, tamano)
	quad.material = material

	var particulas := GPUParticles3D.new()
	particulas.amount = cantidad
	particulas.lifetime = vida
	particulas.process_material = proceso
	particulas.draw_pass_1 = quad
	particulas.emitting = false
	particulas.local_coords = false
	particulas.visibility_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 400, 400))
	return particulas


## Círculo blanco que se desvanece hacia el borde: cada partícula de humo es una bocanada redonda.
func _textura_bocanada() -> GradientTexture2D:
	var gradiente := Gradient.new()
	gradiente.set_color(0, Color(1, 1, 1, 0.9))
	gradiente.set_color(1, Color(1, 1, 1, 0.0))
	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = 64
	textura.height = 64
	return textura


func _armar_camara_y_hud() -> void:
	_camara = Camera3D.new()
	_camara.current = true
	add_child(_camara)

	var hud := CanvasLayer.new()
	add_child(hud)
	# Bandas negras arriba y abajo: formato de cine.
	for arriba in [true, false]:
		var banda := ColorRect.new()
		banda.color = Color.BLACK
		banda.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if arriba else Control.PRESET_BOTTOM_WIDE)
		if arriba:
			banda.offset_bottom = 70
		else:
			banda.offset_top = -70
		hud.add_child(banda)
	_subtitulo = Interfaz.etiqueta("", Interfaz.BLANCO, 26)
	_subtitulo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitulo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitulo.offset_top = -55
	hud.add_child(_subtitulo)
	var saltar := Interfaz.etiqueta("Espacio: saltar", Color(Interfaz.CIAN, 0.6), 14)
	saltar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	saltar.position += Vector2(-130, 24)
	hud.add_child(saltar)


# --- Secuencia --------------------------------------------------------------

func _secuencia() -> void:
	var motivo: String = GameState.lanzamiento.get("motivo", "")
	var alto := _altura_vehiculo

	# 1. Plano general: el cohete en la plataforma, la cámara se acerca despacio.
	_plano(Vector3(30, 7, 105), func() -> Vector3: return Vector3(0, alto * 0.45, 0), 40, 0.15)
	_mover_camara(Vector3(24, 9, 82), 4.5)
	for texto in ["T-3", "T-2", "T-1"]:
		_subtitulo.text = texto
		if not await _esperar(1.3):
			return

	# 2. Primer plano de los motores: ignición.
	_plano(Vector3(12, 1.2, 14), func() -> Vector3: return Vector3(0, 1.5, 0), 50, 0.05)
	_mover_camara(Vector3(10, 1.0, 12), 3.0)
	_subtitulo.text = "Ignición"
	if not await _esperar(0.6):
		return
	_encender_motores()
	if not await _esperar(1.8):
		return

	# 3. Contrapicado desde la base: el cohete se despega (o no) de la plataforma.
	_plano(Vector3(26, 2.0, 55), func() -> Vector3: return _vehiculo.position + Vector3(0, alto * 0.6, 0), 40, 0.1)
	if motivo == "masa":
		_subtitulo.text = "El cohete no logra levantar la nave..."
		_temblor = 0.12
		_sacudida = 0.6
		if not await _esperar(2.8):
			return
		_apagar_motores()
		_temblor = 0.0
		_subtitulo.text = "Apagado de emergencia"
		if not await _esperar(2.0):
			return
		_terminar()
		return
	_subtitulo.text = "¡Despegue!"
	_estela.emitting = true
	_aceleracion = 2.5
	_sacudida = 0.5
	if not await _esperar(3.2):
		return

	# 4. Seguimiento con teleobjetivo desde lejos.
	_plano(Vector3(170, 6, 140), func() -> Vector3: return _vehiculo.position + Vector3(0, alto * 0.5, 0), 9, 0.4)
	_subtitulo.text = ""
	_aceleracion = 7.0
	if motivo == "cohete":
		if not await _esperar(1.8):
			return
		_explotar()
		_subtitulo.text = "Se perdió la señal del cohete"
		if not await _esperar(3.0):
			return
		_terminar()
		return
	if not await _esperar(3.5):
		return

	# 5. Ascenso: desde el suelo, el cohete se pierde en el cielo.
	var lejos := func() -> Vector3: return _vehiculo.position + Vector3(0, alto * 0.5, 0)
	_plano(Vector3(-40, 2, -50), lejos, 32, 0.3)
	_aceleracion = 14.0
	_subtitulo.text = "Rumbo a " + GameState.mision.get("nombre", "la órbita").to_lower()
	if not await _esperar(3.5):
		return
	_terminar()


## Corte a un plano nuevo: posición de cámara, a qué mira, lente y cuánto se mueve en mano.
func _plano(posicion: Vector3, mirar_a: Callable, fov: float, vaiven: float) -> void:
	_camara.position = posicion
	_camara.fov = fov
	_mirar_a = mirar_a
	_vaiven = vaiven


func _mover_camara(destino: Vector3, duracion: float) -> void:
	create_tween().tween_property(_camara, "position", destino, duracion).set_trans(Tween.TRANS_SINE)


## Espera y devuelve false si mientras tanto se saltó la secuencia.
func _esperar(segundos: float) -> bool:
	await get_tree().create_timer(segundos).timeout
	return not _terminado


## La estela se enciende recién al despegar: en la plataforma solo se acumularía en la base.
func _encender_motores() -> void:
	_llama.visible = true
	_luz_motor.visible = true
	_humo_suelo.emitting = true
	_sacudida = 0.4


func _apagar_motores() -> void:
	_llama.visible = false
	_luz_motor.visible = false
	_humo_suelo.emitting = false
	_estela.emitting = false


func _explotar() -> void:
	var punto := _vehiculo.global_position + Vector3(0, _altura_vehiculo * 0.5, 0)
	_vehiculo.visible = false
	_aceleracion = 0.0
	_velocidad = 0.0
	_mirar_a = func() -> Vector3: return punto
	_estela.emitting = false

	var bola := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 4.0
	esfera.height = 8.0
	var fuego := StandardMaterial3D.new()
	fuego.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fuego.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fuego.albedo_color = Color("#FFC36B")
	fuego.emission_enabled = true
	fuego.emission = Interfaz.ALERTA
	fuego.emission_energy_multiplier = 4.0
	esfera.material = fuego
	bola.mesh = esfera
	bola.position = punto
	add_child(bola)
	var destello := OmniLight3D.new()
	destello.position = punto
	destello.light_color = Color("#FFB060")
	destello.light_energy = 16.0
	destello.omni_range = 120
	add_child(destello)

	var humo := _humo(120, 4.0, Vector3(0, 1, 0), 10.0, 10.0)
	humo.position = punto
	humo.one_shot = true
	humo.explosiveness = 0.9
	add_child(humo)
	humo.emitting = true

	var tween := create_tween().set_parallel()
	tween.tween_property(bola, "scale", Vector3.ONE * 4.0, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(fuego, "albedo_color:a", 0.0, 1.5)
	tween.tween_property(destello, "light_energy", 0.0, 1.5)


func _terminar() -> void:
	if _terminado:
		return
	_terminado = true
	_subtitulo.text = ""
	_mostrar_resultado(GameState.lanzamiento.get("motivo", ""))


func _mostrar_resultado(motivo: String) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 2
	add_child(capa)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(centro)
	var panel := Interfaz.panel(Interfaz.PANEL, 24)
	panel.custom_minimum_size = Vector2(620, 0)
	centro.add_child(panel)

	var caja := Interfaz.vbox(16)
	panel.add_child(caja)
	var exito := motivo == ""
	var titulo := ("¡Rumbo a la Luna!" if GameState.mision.has("viaje") else "¡Nave en órbita!") if exito else "Misión fallida"
	caja.add_child(Interfaz.etiqueta(titulo, Interfaz.LIMA if exito else Interfaz.ALERTA, 30))

	var texto := "El cohete hizo su trabajo y la nave llegó a destino con %d m/s de delta-v de sobra para maniobrar." % roundi(
		GameState.medidores["delta_v"]["valor"] - GameState.medidores["delta_v"]["limite"])
	if exito and GameState.mision.has("viaje"):
		var sobra: float = GameState.medidores["delta_v"]["valor"] - GameState.medidores["delta_v"]["limite"]
		if sobra >= 0.0:
			texto = "El cohete hizo su trabajo: la nave va rumbo a la Luna con %d m/s de delta-v de sobra para frenar al llegar." % roundi(sobra)
		else:
			texto = "El cohete hizo su trabajo y la nave va rumbo a la Luna... pero le faltan %d m/s de delta-v para frenar al llegar." % roundi(-sobra)
	if not exito:
		texto = GameState.texto_fallo_lanzamiento()
	caja.add_child(Interfaz.parrafo(texto, Interfaz.BLANCO, 18))

	var botones := Interfaz.hbox(12)
	caja.add_child(botones)
	if exito:
		var seguir := Interfaz.boton_principal("Ir a la cabina", 20)
		seguir.pressed.connect(func() -> void:
			GameState.iniciar_operaciones()
			GameState.ir_a("operaciones"))
		botones.add_child(seguir)
	else:
		var informe := Interfaz.boton("Ver informe", 20)
		informe.pressed.connect(GameState.ir_a.bind("informe"))
		botones.add_child(informe)
		var redisenar := Interfaz.boton("Rediseñar la nave", 20)
		redisenar.pressed.connect(GameState.ir_a.bind("diseno"))
		botones.add_child(redisenar)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
