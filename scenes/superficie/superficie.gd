extends Node3D
## Final del juego: la superficie de la Luna.
##
## Se llega saliendo por la esclusa cuando la nave ya alunizó. El astronauta
## camina con la gravedad lunar (salta con Espacio) hasta el lugar marcado y
## planta la bandera manteniendo E. Ahí empieza la cinemática: el astronauta
## llega con la bandera del Paraguay, la clava en dos golpes, la tela se despliega
## y él la saluda, con la Tierra de fondo. Termina el juego: se puede ver el
## informe o volver al inicio.
##
## Se prueba sola: abrir scenes/superficie/superficie.tscn y pulsar F6.

const Jugador := preload("res://scenes/cabina/jugador.gd")

const GRAVEDAD_LUNAR := 1.62
const TAMANO := 180.0  # metros de lado del terreno
const CELDAS := 110
const RADIO_PLANO := 16.0  # zona plana alrededor del alunizaje
const POSICION_NAVE := Vector3(0, 0, -6)
const LUGAR_BANDERA := Vector3(0, 0, 14)
const DISTANCIA_PLANTAR := 2.6
const SEGUNDOS_PLANTAR := 1.5

# La bandera y el astronauta de la cinemática (metros).
const LARGO_MASTIL := 2.9
const ANCHO_TELA := 1.3
const ALTO_TELA := 0.72  # proporción de la bandera paraguaya (11:20)
const ENROLLADA := 0.07  # ancho de la tela enrollada, respecto del total
const HUNDIDA := 0.45  # cuánto queda clavado el mástil
const DELANTE := 0.42  # a qué distancia delante del astronauta va el mástil
const ALTO_CADERA := 0.84
const LARGO_BRAZO := 0.34  # cada tramo: brazo y antebrazo
# Momentos de la cinemática, en segundos desde que se planta.
const T_LLEGA := 3.0
const T_ALZA := 3.8
const T_GOLPE_1 := 4.1
const T_AGARRA := 4.6
const T_GOLPE_2 := 4.85
const T_SUELTA := 5.4
const T_PLANO_GENERAL := 5.8
const T_ATRAS := 6.0
const T_SALUDO := 7.3
const T_TITULO := 7.6
const T_BOTONES := 11.5
const T_BAJA_SALUDO := 11.8

var _ruido := FastNoiseLite.new()
var _crateres: Array = []  # [centro (Vector2), radio, profundidad]
var _jugador: Jugador
var _marca: Node3D
var _progreso_plantar := 0.0
var _plantada := false
var _camara_final: Camera3D
var _tiempo_final := 0.0
var _bandera: Node3D
var _tela: Node3D
var _tela_material: ShaderMaterial
var _astro := {}
var _frente := Vector3.LEFT  # hacia dónde mira el astronauta al clavarla: de cara al sol
var _postura: Vector3  # dónde se para para clavarla
var _pisadas := 0
var _saltos := 0
var _golpes := 0
var _sacudida := 0.0
var _azar := RandomNumberGenerator.new()

var _objetivo: Label
var _indicacion: Label
var _barra: ProgressBar
var _mensaje: Label
var _capa_final: CanvasLayer
var _hud: CanvasLayer


func _ready() -> void:
	if not GameState.alunizado():
		_preparar_partida_de_prueba()
	_ruido.seed = 7
	_ruido.frequency = 0.035
	_generar_crateres()

	_armar_cielo()
	_armar_terreno()
	_armar_nave()
	_armar_lugar_bandera()

	_jugador = Jugador.new()
	_jugador.gravedad = GRAVEDAD_LUNAR
	_jugador.salto = 2.2
	_jugador.velocidad = 2.4
	add_child(_jugador)
	_jugador.position = Vector3(3.5, altura(3.5, -1.5) + 0.1, -1.5)
	_jugador.mirar_hacia(LUGAR_BANDERA + Vector3(0, altura(LUGAR_BANDERA.x, LUGAR_BANDERA.z) + 1.0, 0))

	_crear_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mostrar_mensaje(tr("Un pequeño paso… Llevá la bandera hasta el lugar marcado y plantala."))


func _process(delta: float) -> void:
	if _plantada:
		_animar_final(delta)
		return
	var cerca := hay_lugar_cerca()
	_indicacion.text = tr("[Mantener E] Plantar la bandera") if cerca else ""
	if cerca and _jugador.activo and Input.is_physical_key_pressed(KEY_E):
		_progreso_plantar += delta
	else:
		_progreso_plantar = maxf(0.0, _progreso_plantar - delta * 2.0)
	_barra.visible = _progreso_plantar > 0.0
	_barra.value = _progreso_plantar / SEGUNDOS_PLANTAR
	if _progreso_plantar >= SEGUNDOS_PLANTAR:
		plantar()
	if _marca:
		_marca.rotate_y(delta * 0.6)


func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and evento.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()


## El jugador está junto al lugar marcado para la bandera.
func hay_lugar_cerca() -> bool:
	var plano := Vector2(_jugador.global_position.x, _jugador.global_position.z)
	return plano.distance_to(Vector2(LUGAR_BANDERA.x, LUGAR_BANDERA.z)) < DISTANCIA_PLANTAR


# --- Terreno -----------------------------------------------------------------

func _generar_crateres() -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = 1969
	while _crateres.size() < 34:
		var centro := Vector2(azar.randf_range(-TAMANO / 2, TAMANO / 2), azar.randf_range(-TAMANO / 2, TAMANO / 2))
		var radio := azar.randf_range(2.5, 14.0)
		# Ningún cráter sobre la zona de alunizaje.
		if centro.length() - radio * 1.4 < RADIO_PLANO + 4.0:
			continue
		_crateres.append([centro, radio, radio * azar.randf_range(0.18, 0.3)])


## Altura del terreno en un punto: ondulación suave más los cráteres, con su borde.
func altura(x: float, z: float) -> float:
	var punto := Vector2(x, z)
	var h := _ruido.get_noise_2d(x, z) * 1.6 + _ruido.get_noise_2d(x * 4.0, z * 4.0) * 0.15
	for crater in _crateres:
		var r: float = punto.distance_to(crater[0]) / crater[1]
		if r < 1.0:
			h -= crater[2] * (1.0 - r * r)
		elif r < 1.45:
			var borde := (r - 1.0) / 0.45
			h += crater[2] * 0.35 * (1.0 - borde * borde)
	# La zona del alunizaje queda casi plana.
	var plano := smoothstep(RADIO_PLANO, RADIO_PLANO * 0.6, punto.length())
	return lerpf(h, h * 0.12, plano)


func _armar_terreno() -> void:
	var herramienta := SurfaceTool.new()
	herramienta.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paso := TAMANO / CELDAS
	for j in CELDAS:
		for i in CELDAS:
			var x0 := -TAMANO / 2 + i * paso
			var z0 := -TAMANO / 2 + j * paso
			var esquinas := [
				Vector3(x0, 0, z0), Vector3(x0 + paso, 0, z0),
				Vector3(x0 + paso, 0, z0 + paso), Vector3(x0, 0, z0 + paso),
			]
			for indice in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = esquinas[indice]
				v.y = altura(v.x, v.z)
				herramienta.set_uv(Vector2(v.x, v.z) / 6.0)
				herramienta.add_vertex(v)
	# Los vértices compartidos se unen: el suelo se sombrea suave, no en facetas.
	herramienta.index()
	herramienta.generate_normals()
	herramienta.generate_tangents()
	var terreno := MeshInstance3D.new()
	terreno.mesh = herramienta.commit()
	terreno.material_override = _material_regolito()
	add_child(terreno)
	terreno.create_trimesh_collision()


## Polvo lunar: gris con grano fino y relieve, generado con ruido.
func _material_regolito() -> StandardMaterial3D:
	var ruido := FastNoiseLite.new()
	ruido.seed = 3
	ruido.frequency = 0.03
	ruido.fractal_octaves = 5
	var color := NoiseTexture2D.new()
	color.noise = ruido
	color.seamless = true
	color.width = 256
	color.height = 256
	var gradiente := Gradient.new()
	gradiente.set_color(0, Color("#7C7E86"))
	gradiente.set_color(1, Color("#A6A8AF"))
	color.color_ramp = gradiente
	var relieve := NoiseTexture2D.new()
	relieve.noise = ruido
	relieve.seamless = true
	relieve.as_normal_map = true
	relieve.bump_strength = 2.5
	relieve.width = 256
	relieve.height = 256
	var material := StandardMaterial3D.new()
	material.albedo_texture = color
	material.normal_enabled = true
	material.normal_texture = relieve
	material.roughness = 0.95
	return material


# --- Cielo, nave y bandera ---------------------------------------------------

func _armar_cielo() -> void:
	var entorno := Espacio.entorno()
	entorno.environment.ambient_light_color = Color("#1A2040")
	add_child(entorno)
	# Sol bajo: sombras largas y duras, como en las fotos de las Apollo.
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-18, -125, 0)
	sol.light_energy = 1.8
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 120
	add_child(sol)
	add_child(Espacio.estrellas(900, 1500))
	var tierra := Espacio.planeta("tierra", 45)
	tierra.position = Vector3(-260, 260, 620)
	add_child(tierra)


## La nave posada sobre cuatro patas.
func _armar_nave() -> void:
	var nave := Nave3D.new()
	nave.scale = Vector3.ONE * 3.0
	nave.mostrar(GameState.seleccion if not GameState.seleccion.is_empty() else GameState.datos.get("eva", {}).get("nave_por_defecto", []))
	add_child(nave)
	var suelo := altura(POSICION_NAVE.x, POSICION_NAVE.z)
	# El fondo del módulo queda a 2,5 m del suelo, sobre las patas.
	nave.position = POSICION_NAVE + Vector3(0, suelo + 2.5 + 1.2 * 3.0, 0)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#C9D3DD")
	metal.metallic = 0.6
	metal.roughness = 0.4
	for i in 4:
		var angulo := TAU * i / 4.0 + PI / 4.0
		var afuera := Vector3(cos(angulo), 0, sin(angulo))
		var arriba := POSICION_NAVE + afuera * 2.6 + Vector3(0, suelo + 3.2, 0)
		var abajo := POSICION_NAVE + afuera * 5.0 + Vector3(0, suelo + 0.15, 0)
		var pata := MeshInstance3D.new()
		var malla := CylinderMesh.new()
		malla.top_radius = 0.12
		malla.bottom_radius = 0.12
		malla.height = arriba.distance_to(abajo)
		pata.mesh = malla
		pata.material_override = metal
		add_child(pata)
		pata.global_position = (arriba + abajo) / 2.0
		pata.look_at(abajo, Vector3.UP if absf((abajo - arriba).normalized().y) < 0.99 else Vector3.FORWARD)
		pata.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		var pie := MeshInstance3D.new()
		var disco := CylinderMesh.new()
		disco.top_radius = 0.45
		disco.bottom_radius = 0.55
		disco.height = 0.12
		pie.mesh = disco
		pie.material_override = metal
		add_child(pie)
		pie.global_position = abajo


## Un anillo que brilla en el suelo y un cartel: acá va la bandera.
func _armar_lugar_bandera() -> void:
	var suelo := altura(LUGAR_BANDERA.x, LUGAR_BANDERA.z)
	_marca = Node3D.new()
	add_child(_marca)
	_marca.position = LUGAR_BANDERA + Vector3(0, suelo + 0.05, 0)
	var anillo := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 1.1
	toro.outer_radius = 1.25
	anillo.mesh = toro
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Interfaz.AQUA
	material.emission_enabled = true
	material.emission = Interfaz.AQUA
	material.emission_energy_multiplier = 2.0
	anillo.material_override = material
	_marca.add_child(anillo)
	var luz := OmniLight3D.new()
	luz.light_color = Interfaz.AQUA
	luz.light_energy = 1.5
	luz.omni_range = 4.0
	luz.position.y = 0.6
	_marca.add_child(luz)
	var cartel := Label3D.new()
	cartel.text = tr("Plantá la bandera acá")
	cartel.position = LUGAR_BANDERA + Vector3(0, suelo + 2.2, 0)
	cartel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cartel.no_depth_test = true
	cartel.pixel_size = 0.004
	cartel.font_size = 48
	cartel.outline_size = 10
	cartel.outline_modulate = Interfaz.FONDO
	cartel.modulate = Interfaz.LIMA
	cartel.name = "CartelBandera"
	add_child(cartel)


## Planta la bandera: el jugador deja de tener el control y empieza la cinemática
## del astronauta clavándola (ver _animar_final).
func plantar() -> void:
	if _plantada:
		return
	_plantada = true
	GameState.plantar_bandera()
	_jugador.activo = false
	_jugador.visible = false
	_indicacion.text = ""
	_barra.visible = false
	_marca.queue_free()
	_marca = null
	var cartel := find_child("CartelBandera", true, false)
	if cartel:
		cartel.queue_free()

	_bandera = _crear_bandera()
	add_child(_bandera)
	_astro = _crear_astronauta()
	add_child(_astro["raiz"])
	_postura = LUGAR_BANDERA - _frente * DELANTE
	_empezar_final()
	# Que el primer cuadro ya muestre la pose.
	_animar_final(0.0)


## La bandera del Paraguay en un mástil con travesaño, como las de las Apollo (en
## la Luna no hay viento que la sostenga). La tela empieza enrollada contra el
## mástil y se despliega al soltarla; los colores están en bandera.gdshader.
func _crear_bandera() -> Node3D:
	var bandera := Node3D.new()
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#E6ECF2")
	metal.metallic = 0.7
	metal.roughness = 0.3
	var mastil := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 0.03
	cilindro.bottom_radius = 0.035
	cilindro.height = LARGO_MASTIL
	mastil.mesh = cilindro
	mastil.material_override = metal
	mastil.position.y = LARGO_MASTIL / 2.0
	bandera.add_child(mastil)
	var remate := MeshInstance3D.new()
	remate.mesh = _esfera(0.05)
	remate.material_override = metal
	remate.position.y = LARGO_MASTIL + 0.03
	bandera.add_child(remate)
	# La tela cuelga del travesaño: los dos se despliegan juntos desde el mástil.
	_tela = Node3D.new()
	_tela.position = Vector3(0.03, LARGO_MASTIL - 0.12, 0)
	bandera.add_child(_tela)
	var travesano := MeshInstance3D.new()
	var barra := CylinderMesh.new()
	barra.top_radius = 0.018
	barra.bottom_radius = 0.018
	barra.height = ANCHO_TELA + 0.04
	travesano.mesh = barra
	travesano.material_override = metal
	travesano.rotation_degrees.z = 90
	travesano.position.x = ANCHO_TELA / 2.0
	_tela.add_child(travesano)
	var plano := PlaneMesh.new()
	plano.orientation = PlaneMesh.FACE_Z
	plano.size = Vector2(ANCHO_TELA, ALTO_TELA)
	plano.subdivide_width = 28
	plano.subdivide_depth = 6
	_tela_material = ShaderMaterial.new()
	_tela_material.shader = preload("res://scenes/superficie/bandera.gdshader")
	_tela_material.set_shader_parameter("ancho", ANCHO_TELA)
	_tela_material.set_shader_parameter("alto", ALTO_TELA)
	var tela := MeshInstance3D.new()
	tela.mesh = plano
	tela.material_override = _tela_material
	tela.position = Vector3(ANCHO_TELA / 2.0, -ALTO_TELA / 2.0 - 0.02, 0)
	_tela.add_child(tela)
	_tela.scale.x = ENROLLADA
	return bandera


## Un astronauta articulado para la cinemática (el jugador no tiene cuerpo): el
## torso se inclina sobre la cadera, las piernas doblan la rodilla y los brazos,
## de dos tramos, se acomodan solos hasta donde tienen que llegar las manos.
## Mira hacia -Z, como todo en Godot.
func _crear_astronauta() -> Dictionary:
	var blanco := StandardMaterial3D.new()
	blanco.albedo_color = Color("#E9EEF3")
	blanco.roughness = 0.7
	var gris := StandardMaterial3D.new()
	gris.albedo_color = Color("#8D97A8")
	var dorado := StandardMaterial3D.new()
	dorado.albedo_color = Color("#D8B04A")
	dorado.metallic = 0.6
	dorado.roughness = 0.25
	var raiz := Node3D.new()
	var pelvis := Node3D.new()
	pelvis.position.y = ALTO_CADERA
	raiz.add_child(pelvis)
	var torso := Node3D.new()
	pelvis.add_child(torso)
	_piezas(torso, [
		[_capsula(0.27, 0.8), Vector3(0, 0.3, 0), blanco],
		[_esfera(0.23), Vector3(0, 0.88, 0), blanco],  # casco
		[_caja(Vector3(0.28, 0.19, 0.08)), Vector3(0, 0.89, -0.19), dorado],  # visor
		[_caja(Vector3(0.48, 0.58, 0.26)), Vector3(0, 0.36, 0.27), gris],  # mochila
		[_caja(Vector3(0.24, 0.14, 0.07)), Vector3(0, 0.34, -0.25), gris],  # panel del pecho
	])
	var caderas: Array[Node3D] = []
	var rodillas: Array[Node3D] = []
	var brazos: Array[Node3D] = []
	var antebrazos: Array[Node3D] = []
	for lado in [-1.0, 1.0]:
		var cadera := Node3D.new()
		cadera.position.x = 0.14 * lado
		pelvis.add_child(cadera)
		_piezas(cadera, [[_capsula(0.12, 0.5), Vector3(0, -0.21, 0), blanco]])
		var rodilla := Node3D.new()
		rodilla.position.y = -0.42
		cadera.add_child(rodilla)
		_piezas(rodilla, [
			[_capsula(0.11, 0.46), Vector3(0, -0.19, 0), blanco],
			[_caja(Vector3(0.24, 0.13, 0.34)), Vector3(0, -0.36, -0.04), gris],  # bota
		])
		# Los brazos cuelgan de la raíz: cada cuadro se ubican desde el hombro.
		var brazo := Node3D.new()
		raiz.add_child(brazo)
		_piezas(brazo, [[_capsula(0.095, 0.4), Vector3(0, -LARGO_BRAZO / 2.0, 0), blanco]])
		var antebrazo := Node3D.new()
		raiz.add_child(antebrazo)
		_piezas(antebrazo, [
			[_capsula(0.085, 0.36), Vector3(0, -0.16, 0), blanco],
			[_esfera(0.07), Vector3(0, -LARGO_BRAZO, 0), gris],  # guante
		])
		caderas.append(cadera)
		rodillas.append(rodilla)
		brazos.append(brazo)
		antebrazos.append(antebrazo)
	return {
		"raiz": raiz, "pelvis": pelvis, "torso": torso, "caderas": caderas,
		"rodillas": rodillas, "brazos": brazos, "antebrazos": antebrazos,
	}


static func _piezas(padre: Node3D, partes: Array) -> void:
	for parte in partes:
		var instancia := MeshInstance3D.new()
		instancia.mesh = parte[0]
		instancia.position = parte[1]
		instancia.material_override = parte[2]
		padre.add_child(instancia)


## Acomoda un brazo (0 el izquierdo, 1 el derecho) para que la mano llegue a
## `mano`, con el codo hacia `codo_hacia`. Todo en coordenadas del astronauta.
func _acomodar_brazo(i: int, mano: Vector3, codo_hacia: Vector3) -> void:
	var lado := -1.0 if i == 0 else 1.0
	var pelvis: Node3D = _astro["pelvis"]
	var torso: Node3D = _astro["torso"]
	var hombro := pelvis.transform * torso.transform * Vector3(0.3 * lado, 0.52, 0)
	var hacia_mano := mano - hombro
	var distancia := clampf(hacia_mano.length(), 0.05, LARGO_BRAZO * 2.0 - 0.001)
	var direccion := hacia_mano.normalized()
	# Dos tramos iguales: el codo queda a mitad de camino, corrido hacia un costado.
	var corrimiento := sqrt(maxf(LARGO_BRAZO * LARGO_BRAZO - distancia * distancia / 4.0, 0.0))
	var costado := codo_hacia - direccion * codo_hacia.dot(direccion)
	costado = costado.normalized() if costado.length() > 0.001 else Vector3.BACK
	var codo := hombro + direccion * distancia / 2.0 + costado * corrimiento
	_apuntar(_astro["brazos"][i], hombro, codo)
	_apuntar(_astro["antebrazos"][i], codo, hombro + direccion * distancia)


## Pone un tramo (que cuelga hacia -Y) en `desde`, apuntando a `hacia`.
static func _apuntar(nodo: Node3D, desde: Vector3, hacia: Vector3) -> void:
	var y := (desde - hacia).normalized()
	var x := y.cross(Vector3.BACK)
	x = x.normalized() if x.length() > 0.01 else Vector3.RIGHT
	nodo.transform = Transform3D(Basis(x, y, x.cross(y)), desde)


## El giro en Y para que algo que mira hacia -Z mire en `rumbo`.
static func _giro(rumbo: Vector3) -> float:
	return atan2(-rumbo.x, -rumbo.z)


## Arranca rápido, se pasa un poco y vuelve (para la tela que se despliega).
static func _con_rebote(x: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)


static func _capsula(radio: float, alto: float) -> CapsuleMesh:
	var malla := CapsuleMesh.new()
	malla.radius = radio
	malla.height = alto
	return malla


static func _esfera(radio: float) -> SphereMesh:
	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2.0
	return malla


static func _caja(tamano: Vector3) -> BoxMesh:
	var malla := BoxMesh.new()
	malla.size = tamano
	return malla


func _levantar_polvo(posicion: Vector3, cantidad := 60, velocidad := 1.6) -> void:
	var proceso := ParticleProcessMaterial.new()
	proceso.direction = Vector3(0, 1, 0)
	proceso.spread = 70.0
	proceso.initial_velocity_min = velocidad * 0.4
	proceso.initial_velocity_max = velocidad
	proceso.gravity = Vector3(0, -GRAVEDAD_LUNAR, 0)
	proceso.scale_min = 0.4
	proceso.scale_max = 0.9
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.75, 0.76, 0.8, 0.5)
	material.albedo_texture = Espacio.textura_bocanada()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5) * (1.0 if cantidad >= 40 else 0.6)
	quad.material = material
	var polvo := GPUParticles3D.new()
	polvo.amount = cantidad
	polvo.lifetime = 2.5
	polvo.one_shot = true
	polvo.explosiveness = 0.9
	polvo.process_material = proceso
	polvo.draw_pass_1 = quad
	add_child(polvo)
	polvo.global_position = posicion
	polvo.emitting = true
	get_tree().create_timer(3.0).timeout.connect(polvo.queue_free)


# --- Final -------------------------------------------------------------------

func _empezar_final() -> void:
	_camara_final = Camera3D.new()
	_camara_final.fov = 42
	add_child(_camara_final)
	_camara_final.current = true
	_tiempo_final = 0.0
	_hud.visible = false

	_capa_final = CanvasLayer.new()
	_capa_final.layer = 3
	add_child(_capa_final)
	for arriba in [true, false]:
		var banda := ColorRect.new()
		banda.color = Color.BLACK
		banda.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if arriba else Control.PRESET_BOTTOM_WIDE)
		_capa_final.add_child(banda)
		create_tween().tween_property(banda, "offset_bottom" if arriba else "offset_top", 70.0 if arriba else -70.0, 1.0)

	var titulo := Interfaz.etiqueta(tr("¡Misión cumplida!"), Interfaz.LIMA, 52)
	titulo.position = Vector2(64, 95)
	titulo.add_theme_constant_override("outline_size", 12)
	titulo.add_theme_color_override("font_outline_color", Interfaz.FONDO)
	titulo.modulate.a = 0.0
	_capa_final.add_child(titulo)
	var subtitulo := Interfaz.etiqueta(tr("La bandera del Paraguay ya flamea en la Luna."), Interfaz.BLANCO, 24)
	subtitulo.position = Vector2(64, 165)
	subtitulo.add_theme_constant_override("outline_size", 8)
	subtitulo.add_theme_color_override("font_outline_color", Interfaz.FONDO)
	subtitulo.modulate.a = 0.0
	_capa_final.add_child(subtitulo)
	var tween := create_tween()
	tween.tween_interval(T_TITULO)
	tween.tween_property(titulo, "modulate:a", 1.0, 1.0)
	tween.tween_property(subtitulo, "modulate:a", 1.0, 1.0)
	tween.tween_interval(T_BOTONES - T_TITULO - 2.0)
	tween.tween_callback(_mostrar_botones_finales)


## La cinemática del final, cuadro a cuadro según el tiempo desde que se plantó:
## el astronauta camina con la bandera, la alza, la clava en dos golpes, la suelta
## (la tela se despliega y se mece), retrocede dos saltitos y la saluda.
func _animar_final(delta: float) -> void:
	if not _camara_final:
		return
	_tiempo_final += delta
	var t := _tiempo_final
	var raiz: Node3D = _astro["raiz"]
	var suelo := altura(LUGAR_BANDERA.x, LUGAR_BANDERA.z)
	var derecha := _frente.cross(Vector3.UP)

	# Dónde está el astronauta y hacia dónde mira.
	var pos := _postura
	var giro := _giro(_frente)
	var marcha := 0.0  # 0 quieto, 1 caminando a paso lleno
	var paso := 0.0  # fase de las piernas
	var rebote := 0.0  # los saltitos de la gravedad lunar
	if t < T_LLEGA:
		var inicio := _postura - _frente * 3.0
		var x := t / T_LLEGA
		pos = inicio.lerp(_postura, 1.0 - pow(1.0 - x, 2.0))
		marcha = clampf(2.0 * (1.0 - x), 0.0, 1.0)
		paso = pos.distance_to(inicio) / 0.9 * PI
		rebote = absf(sin(paso)) * 0.12 * marcha
		if int(paso / PI) > _pisadas:
			_pisadas = int(paso / PI)
			_levantar_polvo(Vector3(pos.x, altura(pos.x, pos.z) + 0.05, pos.z), 14, 0.6)
	elif t >= T_ATRAS:
		# Dos saltitos hacia atrás, girando para quedar de costado a la bandera.
		var lugar_final := LUGAR_BANDERA - _frente * 1.35 + derecha * 0.5
		var x := clampf((t - T_ATRAS) / 1.1, 0.0, 1.0)
		var salto := minf(floorf(x * 2.0), 1.0)
		var dentro := x * 2.0 - salto
		pos = _postura.lerp(lugar_final, (salto + smoothstep(0.0, 1.0, dentro)) / 2.0)
		rebote = sin(PI * dentro) * 0.1
		giro = lerp_angle(giro, _giro(LUGAR_BANDERA + derecha - lugar_final), smoothstep(0.0, 1.0, x))
		if int(x * 2.0) > _saltos:
			_saltos = int(x * 2.0)
			_levantar_polvo(Vector3(pos.x, altura(pos.x, pos.z) + 0.05, pos.z), 18, 0.7)
	raiz.global_position = Vector3(pos.x, altura(pos.x, pos.z), pos.z)
	raiz.rotation.y = giro

	# El mástil: a qué altura está el pie, cuánto se inclina hacia adelante y
	# dónde lo agarran las manos (derecha e izquierda, medido desde el pie).
	var alto_pie := 0.45 + rebote
	var inclinacion := 0.0
	var agarre := Vector2(0.65, 0.95)
	var inclina_torso := -0.1 * marcha
	var agacha := 0.0
	if t < T_LLEGA:
		inclinacion = 0.15
	elif t < T_ALZA:
		var x := smoothstep(T_LLEGA, T_ALZA, t)
		alto_pie = lerpf(0.45, 0.6, x)
		inclinacion = lerpf(0.15, 0.0, x)
		agarre = Vector2(0.65, 0.95).lerp(Vector2(0.75, 1.0), x)
		inclina_torso = 0.08 * x
	elif t < T_GOLPE_1:
		var x := pow((t - T_ALZA) / (T_GOLPE_1 - T_ALZA), 2.0)
		alto_pie = lerpf(0.6, -0.2, x)
		agarre = Vector2(0.75, 1.0)
		inclina_torso = lerpf(0.08, -0.55, x)
		agacha = 0.15 * x
	elif t < T_AGARRA:
		# Desliza las manos más arriba para el segundo golpe.
		var x := smoothstep(T_GOLPE_1, T_AGARRA, t)
		alto_pie = -0.2
		agarre = Vector2(0.75, 1.0).lerp(Vector2(1.15, 1.4), x)
		inclina_torso = lerpf(-0.55, -0.05, x)
		agacha = 0.15 * (1.0 - x)
	elif t < T_GOLPE_2:
		var x := pow((t - T_AGARRA) / (T_GOLPE_2 - T_AGARRA), 2.0)
		alto_pie = lerpf(-0.2, -HUNDIDA, x)
		agarre = Vector2(1.15, 1.4)
		inclina_torso = lerpf(-0.05, -0.4, x)
		agacha = 0.1 * x
	else:
		var x := smoothstep(T_GOLPE_2, T_GOLPE_2 + 0.6, t)
		alto_pie = -HUNDIDA
		agarre = Vector2(1.15, 1.4)
		inclina_torso = lerpf(-0.4, 0.0, x)
		agacha = 0.1 * (1.0 - x)
		# Queda vibrando un poco después del último golpe.
		var desde_golpe := t - T_GOLPE_2
		inclinacion = sin(desde_golpe * 17.0) * 0.045 * exp(-desde_golpe * 2.5)
	inclina_torso += sin(t * 1.7) * 0.015  # respira

	var base: Vector3
	if t < T_LLEGA:
		base = raiz.global_transform * Vector3(0, alto_pie, -DELANTE)
	else:
		base = LUGAR_BANDERA + Vector3(0, suelo + alto_pie, 0)
	var eje := Vector3.UP.rotated(derecha, -inclinacion)
	var orientacion := Basis(derecha, -inclinacion) * Basis(Vector3.UP, atan2(-_frente.z, _frente.x))
	_bandera.global_transform = Transform3D(orientacion, base)

	# El cuerpo: saltitos, agacharse con las rodillas y piernas que caminan.
	var pelvis: Node3D = _astro["pelvis"]
	pelvis.position.y = ALTO_CADERA + rebote - agacha
	(_astro["torso"] as Node3D).rotation.x = inclina_torso
	var doblez := acos(clampf(1.0 - agacha / ALTO_CADERA, -1.0, 1.0))
	for i in 2:
		var fase := paso + PI * i
		var cadera: Node3D = _astro["caderas"][i]
		var rodilla: Node3D = _astro["rodillas"][i]
		cadera.rotation.x = sin(fase) * 0.55 * marcha + doblez
		rodilla.rotation.x = -(0.15 + 0.4 * maxf(0.0, cos(fase))) * marcha - doblez * 2.0

	# Las manos: en el mástil, sueltas a los costados o (la derecha) saludando.
	var al_astronauta := raiz.global_transform.affine_inverse()
	var agarra := 1.0 - smoothstep(T_SUELTA, T_SUELTA + 0.5, t)
	var saluda := smoothstep(T_SALUDO, T_SALUDO + 0.5, t) * (1.0 - smoothstep(T_BAJA_SALUDO, T_BAJA_SALUDO + 0.6, t))
	for i in 2:
		var lado := -1.0 if i == 0 else 1.0
		var en_mastil := al_astronauta * (base + eje * (agarre.x if i == 1 else agarre.y) + derecha * 0.04 * lado)
		var mano := Vector3(0.38 * lado, 0.74, 0.02).lerp(en_mastil, agarra)
		var codo := Vector3(0.5 * lado, -0.3, 0.6)
		if i == 1:
			mano = mano.lerp(Vector3(0.14, 1.8, -0.17), saluda)
			codo = codo.lerp(Vector3(1.0, -0.2, -0.3), saluda)
		_acomodar_brazo(i, mano, codo)

	# La tela se despliega al soltarla y se mece hasta quedarse quieta.
	var despliegue := clampf((t - T_SUELTA + 0.1) / 1.1, 0.0, 1.0)
	_tela.scale.x = lerpf(ENROLLADA, 1.0, _con_rebote(despliegue))
	var desde_suelta := maxf(t - T_SUELTA, 0.0)
	_tela_material.set_shader_parameter("vaiven", 0.08 * exp(-desde_suelta * 0.6) if despliegue > 0.0 else 0.0)
	_tela_material.set_shader_parameter("fase", t * 4.5)

	# Cada golpe levanta polvo y sacude la cámara.
	if _golpes < 2 and t >= [T_GOLPE_1, T_GOLPE_2][_golpes]:
		_golpes += 1
		_levantar_polvo(LUGAR_BANDERA + Vector3(0, suelo + 0.1, 0), 45 if _golpes == 1 else 70, 1.4)
		_sacudida = 0.06 if _golpes == 1 else 0.09

	_mover_camara(t, delta, raiz.global_position, suelo, derecha)


## Tres planos: de costado mientras camina (la nave atrás), bajo y de frente
## (del lado del sol) mientras la clava, y uno general que gira despacio con la
## Tierra sobre la bandera.
func _mover_camara(t: float, delta: float, astronauta: Vector3, suelo: float, derecha: Vector3) -> void:
	_sacudida = move_toward(_sacudida, 0.0, delta * 0.3)
	var centro := LUGAR_BANDERA + Vector3(0, suelo, 0)
	var desde: Vector3
	var hacia: Vector3
	if t < T_LLEGA:
		desde = astronauta - derecha * 4.6 + _frente * 1.0 + Vector3.UP * 1.3
		hacia = astronauta + Vector3.UP * 1.05 + _frente * 0.4
	elif t < T_PLANO_GENERAL:
		var x := smoothstep(T_LLEGA, T_PLANO_GENERAL, t)
		desde = centro + (_frente * 2.9 + derecha * 1.9).lerp(_frente * 2.4 + derecha * 1.5, x)
		desde.y = altura(desde.x, desde.z) + 0.7
		hacia = centro - _frente * 0.3 + Vector3.UP * 0.95
	else:
		var x := t - T_PLANO_GENERAL
		# Del lado opuesto a la Tierra, bajo y mirando un poco hacia arriba.
		var angulo := deg_to_rad(158.0) + x * 0.015
		var distancia := lerpf(8.5, 7.6, smoothstep(0.0, 8.0, x))
		desde = centro + Vector3(sin(angulo), 0, cos(angulo)) * distancia
		desde.y = altura(desde.x, desde.z) + 0.7 + sin(x * 0.3) * 0.15
		# Apunta un poco a la izquierda: la Tierra queda a la derecha del título.
		hacia = centro + Vector3.UP * 2.4 - Vector3(cos(angulo), 0, -sin(angulo)) * 0.8
	desde += Vector3(_azar.randf_range(-1.0, 1.0), _azar.randf_range(-1.0, 1.0), _azar.randf_range(-1.0, 1.0)) * _sacudida
	_camara_final.global_position = desde
	_camara_final.look_at(hacia)


func _mostrar_botones_finales() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var botones := Interfaz.hbox(14)
	botones.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	botones.grow_horizontal = Control.GROW_DIRECTION_BOTH
	botones.grow_vertical = Control.GROW_DIRECTION_BEGIN
	botones.offset_bottom = -95
	_capa_final.add_child(botones)
	var informe := Interfaz.boton_principal(tr("Ver informe"), 22)
	informe.pressed.connect(_ver_informe)
	botones.add_child(informe)
	var inicio := Interfaz.boton(tr("Volver al inicio"), 22)
	inicio.pressed.connect(func() -> void:
		GameState.reiniciar()
		get_tree().change_scene_to_file(GameState.ESCENA_INICIO))
	botones.add_child(inicio)


func _ver_informe() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 8
	add_child(capa)
	capa.add_child(load(GameState.ESCENAS["informe"]).instantiate())


# --- HUD ---------------------------------------------------------------------

func _crear_hud() -> void:
	var hud := CanvasLayer.new()
	_hud = hud
	add_child(hud)
	hud.add_child(Interfaz.visor_casco())

	_objetivo = Interfaz.etiqueta(tr("Objetivo: plantá la bandera en el lugar marcado."), Interfaz.CIAN, 18)
	_objetivo.position = Vector2(16, 12)
	hud.add_child(_objetivo)

	var mira := ColorRect.new()
	mira.color = Color(Interfaz.BLANCO, 0.8)
	mira.size = Vector2(4, 4)
	mira.set_anchors_preset(Control.PRESET_CENTER)
	mira.position -= Vector2(2, 2)
	hud.add_child(mira)

	_indicacion = Interfaz.etiqueta("", Interfaz.BLANCO, 22)
	_indicacion.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_indicacion.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_indicacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicacion.offset_top = 40
	hud.add_child(_indicacion)
	_barra = Interfaz.barra(Interfaz.LIMA, 1.0)
	_barra.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_barra.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_barra.custom_minimum_size = Vector2(240, 10)
	_barra.offset_top = 80
	_barra.visible = false
	hud.add_child(_barra)

	_mensaje = Interfaz.parrafo("", Interfaz.LIMA, 20)
	_mensaje.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_mensaje.custom_minimum_size.x = 760
	_mensaje.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.offset_top = 52
	hud.add_child(_mensaje)

	var controles := Interfaz.etiqueta(tr("WASD: caminar · Espacio: saltar · Mouse: mirar · Mantener E: plantar · Esc: soltar el mouse"), Color(Interfaz.CIAN, 0.7), 14)
	controles.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controles.position += Vector2(16, -28)
	hud.add_child(controles)

	for control in hud.find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _mostrar_mensaje(texto: String) -> void:
	_mensaje.text = texto
	_mensaje.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(_mensaje, "modulate:a", 0.0, 1.0)


## Abierta sola desde el editor: una partida de prueba que ya alunizó.
func _preparar_partida_de_prueba() -> void:
	GameState.reiniciar()
	GameState.elegir_mision("luna")
	for id in ["cohete_mediano", "panel_grande", "antena_alta", "motor_quimico", "despensa_mediana", "camara", "espectrometro"]:
		GameState.elegir_pieza(id)
	GameState.lanzamiento = {"exito": true, "motivo": ""}
	GameState.iniciar_operaciones()
	GameState.ops["terminada"] = true
	GameState.ops["motivo_fin"] = "llegada"
