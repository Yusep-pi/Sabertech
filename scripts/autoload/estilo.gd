extends Node
## Estilo visual del juego (autoload "Estilo"): N64 con luz moderna.
##
## Actúa sobre cada escena al cargarse, sin que las escenas tengan que hacer nada:
## - A cada WorldEnvironment le suma tonemapping filmic, bloom, sombreado
##   ambiental, gradación de color y, en interiores, niebla volumétrica que dibuja
##   los haces de luz que entran por las ventanas.
## - Si en assets/texturas/ hay un archivo con el nombre de un material de los
##   modelos (casco.png, pared.png...), le pone el material retro
##   (scripts/material_retro.gdshader): píxel nítido, proyección triplanar, relieve
##   con <nombre>_normal.png y variación de tono para que no se note el mosaico.
##   Lo mismo con planeta_<destino>.png y fondo_espacio.png. La lista de archivos
##   y sus prompts está en arte/PROMPTS_GEMINI.md.
## - A cada cámara le agrega contornos en aristas y siluetas (scripts/contornos.gdshader),
##   y a las luces, sombras con penumbra.
## - Pone un filtro retro de pantalla completa por debajo de la interfaz.
##   F2 alterna entre retro, retro fuerte y moderno.

const CARPETA_TEXTURAS := "res://assets/texturas/"
## Cómo se ve cada material con textura: metros por repetición, rugosidad, metal,
## fuerza del relieve, tamaño de las manchas de variación (metros) y, si hace falta,
## cuánto cambia el tono entre manchas y cuánto se mezcla una segunda lectura a otra
## escala (las dos, en superficies grandes, donde el mosaico se nota más).
const MATERIALES := {
	"casco": {"metros": 3.0, "rugosidad": 0.55, "metal": 0.15, "relieve": 1.0, "manchas": 4.0},
	"casco_gris": {"metros": 2.0, "rugosidad": 0.45, "metal": 0.6, "relieve": 1.0, "manchas": 3.0},
	"oscuro": {"metros": 1.5, "rugosidad": 0.6, "metal": 0.35, "relieve": 1.0, "manchas": 2.5},
	"celda": {"metros": 1.2, "rugosidad": 0.25, "metal": 0.4, "relieve": 0.8, "manchas": 3.0},
	"dorado": {"metros": 1.5, "rugosidad": 0.35, "metal": 0.8, "relieve": 1.2, "manchas": 2.0},
	"pared": {"metros": 2.5, "rugosidad": 0.8, "metal": 0.0, "relieve": 1.0, "manchas": 3.0},
	"piso": {"metros": 2.5, "rugosidad": 0.85, "metal": 0.0, "relieve": 1.0, "manchas": 2.5},
	"concreto": {"metros": 8.0, "rugosidad": 0.9, "metal": 0.0, "relieve": 1.0, "manchas": 12.0, "variacion": 0.2, "otra_escala": 0.6},
	"suelo": {"metros": 30.0, "rugosidad": 1.0, "metal": 0.0, "relieve": 0.6, "manchas": 35.0, "variacion": 0.3, "otra_escala": 0.8},
}
## Niebla volumétrica según la escena: densidad y alcance en metros.
const NIEBLA := {
	"Cabina": [0.006, 30.0],
	"Esclusa": [0.008, 24.0],
	"SalaDos": [0.006, 24.0],
}
## Una esfera más grande que esto es un planeta.
const RADIO_PLANETA := 100.0
const MODOS := [
	{"nombre": "Retro", "pixel": 2.0, "niveles": 64.0, "tramado": 0.35, "grano": 0.015},
	{"nombre": "Retro fuerte", "pixel": 3.0, "niveles": 24.0, "tramado": 0.7, "grano": 0.03},
	{"nombre": "Moderno", "pixel": 0.0},
]

var modo := 0
var _materiales: Dictionary = {}  # nombre de material -> material texturizado, o null si no hay archivo
var _texturas: Dictionary = {}  # nombre de archivo -> Texture2D, o null
var _filtro: ColorRect
var _aviso: Label


func _ready() -> void:
	get_tree().node_added.connect(_on_nodo_agregado)
	# Para comparar capturas: godot --path . <escena> -- --sin-filtro
	if "--sin-filtro" in OS.get_cmdline_user_args():
		modo = MODOS.size() - 1
	_crear_filtro()
	_aplicar_modo()


func _unhandled_key_input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla and tecla.pressed and not tecla.echo and tecla.physical_keycode == KEY_F2:
		cambiar_modo((modo + 1) % MODOS.size())


func cambiar_modo(nuevo: int) -> void:
	modo = nuevo
	_aplicar_modo()
	_aviso.text = "Gráficos: " + MODOS[modo]["nombre"] + "  (F2 para cambiar)"
	_aviso.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_aviso, "modulate:a", 0.0, 0.5)


## La textura de assets/texturas/<nombre>.png, o null si todavía no existe.
func textura(nombre: String) -> Texture2D:
	if _texturas.has(nombre):
		return _texturas[nombre]
	var ruta := CARPETA_TEXTURAS + nombre + ".png"
	var cargada: Texture2D = null
	if ResourceLoader.exists(ruta):
		cargada = load(ruta)
	elif FileAccess.file_exists(ruta):
		# Recién copiada y sin importar todavía: se lee directo del disco.
		var imagen := Image.load_from_file(ProjectSettings.globalize_path(ruta))
		if imagen:
			cargada = ImageTexture.create_from_image(imagen)
	_texturas[nombre] = cargada
	return cargada


# --- Escenas ----------------------------------------------------------------

func _on_nodo_agregado(nodo: Node) -> void:
	if nodo is WorldEnvironment:
		_mejorar_entorno(nodo)
	elif nodo is MeshInstance3D:
		_texturizar(nodo)
	elif nodo is Camera3D:
		_agregar_contornos(nodo)
	elif nodo is Light3D:
		_mejorar_luz(nodo)


func _mejorar_entorno(nodo: WorldEnvironment) -> void:
	var entorno := nodo.environment
	if not entorno:
		return
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	entorno.glow_enabled = true
	entorno.glow_intensity = 0.9
	entorno.glow_bloom = 0.08
	entorno.glow_hdr_threshold = 0.9
	entorno.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Sombreado en rincones y uniones, y un poco de luz rebotada entre superficies.
	entorno.ssao_enabled = true
	entorno.ssao_radius = 0.9
	entorno.ssao_intensity = 2.2
	entorno.ssao_detail = 0.8
	entorno.ssao_light_affect = 0.25
	entorno.ssil_enabled = true
	entorno.ssil_intensity = 0.8
	entorno.adjustment_enabled = true
	entorno.adjustment_contrast = 1.1
	entorno.adjustment_saturation = 1.25

	# El fondo del espacio, si ya está la imagen.
	var es_espacio := entorno.background_mode == Environment.BG_COLOR and entorno.background_color.v < 0.15
	if es_espacio and textura("fondo_espacio"):
		var cielo := PanoramaSkyMaterial.new()
		cielo.panorama = textura("fondo_espacio")
		cielo.filter = false
		# Un poco más tenue, para que el espacio siga oscuro y la nebulosa no domine.
		cielo.energy_multiplier = 0.6
		entorno.sky = Sky.new()
		entorno.sky.sky_material = cielo
		entorno.background_mode = Environment.BG_SKY

	# Niebla volumétrica solo en la vista principal (no en la nave del diseño, por ejemplo).
	var escena := _escena_de(nodo)
	if NIEBLA.has(escena) and nodo.get_viewport() == get_tree().root:
		entorno.volumetric_fog_enabled = true
		entorno.volumetric_fog_density = NIEBLA[escena][0]
		entorno.volumetric_fog_length = NIEBLA[escena][1]
		entorno.volumetric_fog_albedo = Color(0.85, 0.92, 1.0)
		entorno.volumetric_fog_anisotropy = 0.6
		# Que no tiña lo que se ve por la ventana: el espacio sigue siendo azul noche.
		entorno.volumetric_fog_sky_affect = 0.0


func _texturizar(malla: MeshInstance3D) -> void:
	if not malla.mesh:
		return
	# Los planetas: esferas grandes con un material propio.
	if malla.mesh is SphereMesh and (malla.mesh as SphereMesh).radius >= RADIO_PLANETA:
		var material := malla.material_override as StandardMaterial3D
		var mapa := textura("planeta_" + GameState.mision.get("destino", "tierra"))
		if material and mapa and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			material.albedo_texture = mapa
			material.albedo_color = Color.WHITE
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		return
	for i in malla.mesh.get_surface_count():
		var original := malla.mesh.surface_get_material(i)
		if original:
			var texturizado := _material_texturizado(original)
			if texturizado:
				malla.set_surface_override_material(i, texturizado)


## El material retro de un material con textura (uno por nombre, compartido), o null si no hay archivo.
func _material_texturizado(original: Material) -> Material:
	var nombre := original.resource_name
	if not MATERIALES.has(nombre):
		return null
	if _materiales.has(nombre):
		return _materiales[nombre]
	var imagen := textura(nombre)
	var material: ShaderMaterial = null
	if imagen:
		var datos: Dictionary = MATERIALES[nombre]
		material = ShaderMaterial.new()
		material.shader = preload("res://scripts/material_retro.gdshader")
		material.set_shader_parameter("textura", imagen)
		material.set_shader_parameter("repeticiones", 1.0 / datos["metros"])
		material.set_shader_parameter("rugosidad", datos["rugosidad"])
		material.set_shader_parameter("metalico", datos["metal"])
		material.set_shader_parameter("fuerza_relieve", datos["relieve"])
		material.set_shader_parameter("tamano_variacion", datos["manchas"])
		for opcional in ["variacion", "otra_escala"]:
			if datos.has(opcional):
				material.set_shader_parameter(opcional, datos[opcional])
		var relieve := textura(nombre + "_normal")
		if relieve:
			material.set_shader_parameter("relieve", relieve)
			material.set_shader_parameter("con_relieve", true)
	_materiales[nombre] = material
	return material


## Un cuadro delante de la cámara que dibuja los contornos de todo lo que se ve.
func _agregar_contornos(camara: Camera3D) -> void:
	var cuadro := MeshInstance3D.new()
	cuadro.name = "Contornos"
	var malla := QuadMesh.new()
	malla.size = Vector2(2, 2)
	cuadro.mesh = malla
	cuadro.extra_cull_margin = 16384.0
	cuadro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/contornos.gdshader")
	# Primero entre lo transparente: humo, vidrios y textos se dibujan encima, sin contorno.
	material.render_priority = Material.RENDER_PRIORITY_MIN
	cuadro.material_override = material
	camara.add_child.call_deferred(cuadro)


## Sombras en todas las luces, y penumbra suave en el sol.
func _mejorar_luz(luz: Light3D) -> void:
	luz.shadow_enabled = true
	if luz is DirectionalLight3D:
		luz.light_angular_distance = 1.5
		luz.shadow_blur = 1.5
	else:
		luz.shadow_blur = 1.2


func _escena_de(nodo: Node) -> String:
	var actual := nodo
	while actual.get_parent() and actual.get_parent() != get_tree().root:
		actual = actual.get_parent()
	return actual.name


# --- Filtro retro -----------------------------------------------------------

func _crear_filtro() -> void:
	# Capa -1: se dibuja después del 3D y antes de toda la interfaz, que queda nítida.
	var capa := CanvasLayer.new()
	capa.layer = -1
	add_child(capa)
	_filtro = ColorRect.new()
	_filtro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_filtro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/retro.gdshader")
	_filtro.material = material
	capa.add_child(_filtro)

	var capa_aviso := CanvasLayer.new()
	capa_aviso.layer = 100
	add_child(capa_aviso)
	_aviso = Interfaz.etiqueta("", Interfaz.CIAN, 16)
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_aviso.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_aviso.position += Vector2(-20, -52)
	_aviso.modulate.a = 0.0
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa_aviso.add_child(_aviso)


func _aplicar_modo() -> void:
	var datos: Dictionary = MODOS[modo]
	_filtro.visible = datos["pixel"] > 0.0
	if _filtro.visible:
		var material := _filtro.material as ShaderMaterial
		for parametro in ["pixel", "niveles", "tramado", "grano"]:
			material.set_shader_parameter("tamano_pixel" if parametro == "pixel" else parametro, datos[parametro])
