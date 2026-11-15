extends Node
## Alucinaciones de la tripulación (autoload "Alucinaciones").
##
## Cuando la cordura baja de tripulacion.alucinaciones.cordura_desde, el juego
## empieza a "mentir", cada vez más fuerte a medida que baja:
## - la pantalla ondula, se ve doble, late de color y los bordes respiran;
## - aparece de reojo un "eco": la silueta de un astronauta que no está, y se
##   desvanece si se lo mira de frente;
## - llegan mensajes falsos de Control de Misión.
## Dormir (en la cama del habitáculo) recupera la cordura y las calma.
## Los valores están en el bloque "alucinaciones" de data/datos.json.

const ANGULO_DESVANECE := 14.0  # grados: mirado de frente, el eco se va

var intensidad := 0.0  # 0 a 1, suavizada

var _cfg: Dictionary
var _capa: CanvasLayer
var _distorsion: ColorRect
var _mensaje: Label
var _reloj_eco := 0.0
var _reloj_mensaje := 0.0
var _eco: Node3D
var _eco_vida := 0.0
var _azar := RandomNumberGenerator.new()


func _ready() -> void:
	_azar.randomize()
	_capa = CanvasLayer.new()
	# Encima del filtro retro (capa -1) y debajo de toda la interfaz.
	_capa.layer = 0
	add_child(_capa)
	_distorsion = ColorRect.new()
	_distorsion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_distorsion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_distorsion.material = ShaderMaterial.new()
	(_distorsion.material as ShaderMaterial).shader = preload("res://scripts/alucinacion.gdshader")
	_distorsion.visible = false
	_capa.add_child(_distorsion)

	var capa_mensajes := CanvasLayer.new()
	capa_mensajes.layer = 7
	add_child(capa_mensajes)
	_mensaje = Interfaz.etiqueta("", Color("#C9A3FF"), 22)
	_mensaje.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_mensaje.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.offset_top = 150
	_mensaje.add_theme_constant_override("outline_size", 8)
	_mensaje.add_theme_color_override("font_outline_color", Interfaz.FONDO)
	_mensaje.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mensaje.modulate.a = 0.0
	capa_mensajes.add_child(_mensaje)


func _process(delta: float) -> void:
	if _cfg.is_empty():
		_cfg = GameState.get_tripulacion().get("alucinaciones", {})
	intensidad = move_toward(intensidad, objetivo(), delta * 0.25)
	_distorsion.visible = intensidad > 0.01
	if _distorsion.visible:
		(_distorsion.material as ShaderMaterial).set_shader_parameter("intensidad", intensidad)
	_actualizar_eco(delta)
	_actualizar_mensajes(delta)



## Cuánto alucina la tripulación ahora (0 a 1), según la cordura.
func objetivo() -> float:
	var ops: Dictionary = GameState.ops
	if ops.is_empty() or ops.get("terminada", true) or ops.get("durmiendo", false):
		return 0.0
	var desde: float = _cfg.get("cordura_desde", 60.0)
	return clampf((desde - ops.get("cordura", 100.0)) / desde, 0.0, 1.0)


# --- El eco ------------------------------------------------------------------

func _actualizar_eco(delta: float) -> void:
	if is_instance_valid(_eco):
		_eco_vida -= delta
		var camara := get_viewport().get_camera_3d()
		var mirado := false
		if camara:
			var hacia := (_eco.global_position + Vector3.UP - camara.global_position).normalized()
			mirado = rad_to_deg((-camara.global_transform.basis.z).angle_to(hacia)) < ANGULO_DESVANECE
		var material := _eco.get_meta("material") as StandardMaterial3D
		var alfa := material.albedo_color.a
		var meta: float = 0.0 if mirado or _eco_vida <= 0.0 else _cfg.get("eco_opacidad", 0.35)
		material.albedo_color.a = move_toward(alfa, meta, delta * (1.5 if mirado else 0.6))
		if (mirado or _eco_vida <= 0.0) and material.albedo_color.a <= 0.001:
			_eco.queue_free()
		return
	if intensidad < _cfg.get("eco_desde", 0.25):
		return
	_reloj_eco -= delta
	if _reloj_eco <= 0.0:
		var rango: Array = _cfg.get("eco_cada_segundos", [12, 28])
		_reloj_eco = _azar.randf_range(rango[0], rango[1]) / maxf(intensidad, 0.3)
		_aparecer_eco()


## La silueta aparece de reojo, a unos metros, mirando al jugador.
func _aparecer_eco() -> void:
	var camara := get_viewport().get_camera_3d()
	var escena := get_tree().current_scene
	if not camara or not escena or not escena is Node3D:
		return
	var adelante := -camara.global_transform.basis.z
	adelante.y = 0.0
	if adelante.length() < 0.1:
		return
	var lado := 1.0 if _azar.randf() < 0.5 else -1.0
	var direccion := adelante.normalized().rotated(Vector3.UP, deg_to_rad(_azar.randf_range(40.0, 60.0) * lado))
	var posicion := camara.global_position + direccion * _azar.randf_range(3.0, 4.5) - Vector3.UP * 1.55

	_eco = Node3D.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.6, 0.85, 1.0, 0.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_eco.set_meta("material", material)
	for parte in [
		[CapsuleMesh.new(), Vector3(0, 0.95, 0), Vector3(0.36, 1.2, 0.36)],
		[SphereMesh.new(), Vector3(0, 1.75, 0), Vector3(0.34, 0.34, 0.34)],
		[BoxMesh.new(), Vector3(0, 1.05, 0.22), Vector3(0.4, 0.55, 0.2)],
	]:
		var malla: PrimitiveMesh = parte[0]
		var instancia := MeshInstance3D.new()
		instancia.mesh = malla
		instancia.material_override = material
		instancia.position = parte[1]
		instancia.scale = parte[2] / _medida_base(malla)
		instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_eco.add_child(instancia)
	escena.add_child(_eco)
	_eco.global_position = posicion
	_eco.look_at(Vector3(camara.global_position.x, posicion.y, camara.global_position.z))
	_eco_vida = _azar.randf_range(2.0, 4.0)


static func _medida_base(malla: PrimitiveMesh) -> Vector3:
	if malla is CapsuleMesh:
		return Vector3(1.0, 2.0, 1.0)
	return Vector3.ONE


# --- Mensajes falsos ----------------------------------------------------------

func _actualizar_mensajes(delta: float) -> void:
	if intensidad < _cfg.get("mensajes_desde", 0.4):
		_mensaje.modulate.a = move_toward(_mensaje.modulate.a, 0.0, delta)
		return
	_reloj_mensaje -= delta
	if _reloj_mensaje > 0.0:
		return
	var rango: Array = _cfg.get("mensajes_cada_segundos", [15, 35])
	_reloj_mensaje = _azar.randf_range(rango[0], rango[1]) / maxf(intensidad, 0.4)
	var mensajes: Array = _cfg.get("mensajes", [])
	if mensajes.is_empty():
		return
	_mensaje.text = mensajes[_azar.randi_range(0, mensajes.size() - 1)]
	# Aparece titilando y se borra, como una transmisión que no llega bien.
	var tween := create_tween()
	for i in 3:
		tween.tween_property(_mensaje, "modulate:a", 1.0, 0.08)
		tween.tween_property(_mensaje, "modulate:a", 0.3, 0.08)
	tween.tween_property(_mensaje, "modulate:a", 1.0, 0.1)
	tween.tween_interval(2.8)
	tween.tween_property(_mensaje, "modulate:a", 0.0, 0.8)


## Para pruebas: hace aparecer un eco y un mensaje ya.
func forzar() -> void:
	_aparecer_eco()
	_reloj_mensaje = 0.0
