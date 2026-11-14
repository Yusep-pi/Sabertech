class_name Espacio
extends RefCounted
## Piezas del espacio exterior que comparten la cabina en órbita y la caminata
## espacial: entorno, estrellas y planetas.

const COLOR_PLANETA := {"tierra": Color("#2E6FD0"), "luna": Color("#A3A6B0")}


static func entorno() -> WorldEnvironment:
	var nuevo := Environment.new()
	nuevo.background_mode = Environment.BG_COLOR
	nuevo.background_color = Color("#04071A")
	nuevo.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	nuevo.ambient_light_color = Color("#2A3358")
	nuevo.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	nuevo.glow_enabled = true
	var nodo := WorldEnvironment.new()
	nodo.environment = nuevo
	return nodo


static func estrellas(cantidad: int = 700, radio: float = 700.0) -> MultiMeshInstance3D:
	var malla := QuadMesh.new()
	malla.size = Vector2(1.5, 1.5) * radio / 700.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Interfaz.BLANCO
	malla.material = material
	var multimalla := MultiMesh.new()
	multimalla.transform_format = MultiMesh.TRANSFORM_3D
	multimalla.mesh = malla
	multimalla.instance_count = cantidad
	var azar := RandomNumberGenerator.new()
	azar.seed = 42
	for i in cantidad:
		var direccion := Vector3(azar.randfn(), azar.randfn(), azar.randfn()).normalized()
		multimalla.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * azar.randf_range(0.5, 1.5)), direccion * radio))
	var nodo := MultiMeshInstance3D.new()
	nodo.multimesh = multimalla
	return nodo


## El planeta ("tierra" o "luna"); la Tierra lleva atmósfera.
static func planeta(destino: String, radio: float) -> Node3D:
	var nodo := Node3D.new()
	nodo.add_child(esfera(radio, COLOR_PLANETA.get(destino, Color.GRAY), 32))
	if destino == "tierra":
		var atmosfera := esfera(radio * 1.04, Color(Interfaz.CIAN, 0.18), 32)
		var material := atmosfera.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		nodo.add_child(atmosfera)
	return nodo


## Círculo blanco que se desvanece hacia el borde: para humo, vapor y bocanadas de partículas.
static func textura_bocanada() -> GradientTexture2D:
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


static func esfera(radio: float, color: Color, segmentos: int) -> MeshInstance3D:
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
