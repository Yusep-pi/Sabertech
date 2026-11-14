extends SubViewportContainer
## Vista 3D de la nave en la pantalla de diseño: el modelo de Blender girando,
## con las piezas elegidas a la vista.

const VELOCIDAD_GIRO := 0.4

var _nave: Nave3D


func _ready() -> void:
	stretch = true
	var vista := SubViewport.new()
	vista.own_world_3d = true
	vista.msaa_3d = Viewport.MSAA_2X
	add_child(vista)

	var entorno := WorldEnvironment.new()
	entorno.environment = Environment.new()
	entorno.environment.background_mode = Environment.BG_COLOR
	entorno.environment.background_color = Interfaz.PANEL
	entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.environment.ambient_light_color = Color(0.5, 0.55, 0.7)
	vista.add_child(entorno)

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-40, 30, 0)
	vista.add_child(luz)

	var camara := Camera3D.new()
	camara.position = Vector3(0, 3.5, 15)
	camara.rotation_degrees.x = -12
	camara.fov = 45
	vista.add_child(camara)

	_nave = Nave3D.new()
	_nave.rotation_degrees = Vector3(15, 30, 0)
	vista.add_child(_nave)


func _process(delta: float) -> void:
	_nave.rotate_y(delta * VELOCIDAD_GIRO)


func mostrar(ids: Array) -> void:
	_nave.mostrar(ids)
