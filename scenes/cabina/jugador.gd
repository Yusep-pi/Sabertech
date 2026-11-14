extends CharacterBody3D
## Jugador en primera persona: WASD o flechas para caminar, mouse para mirar,
## E o clic para usar la consola que se está mirando.

signal consola_usada(consola: String)

const VELOCIDAD := 3.0
const SENSIBILIDAD := 0.0025
const ALTURA_OJOS := 1.6
const ALCANCE := 3.0
## La mirada es un cilindro de este radio, no una línea: no hace falta apuntar con precisión.
const RADIO_MIRADA := 0.25

## Desactivado mientras hay una pantalla abierta.
var activo := true
var camara: Camera3D

var _mirada: ShapeCast3D
var _gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	var forma := CollisionShape3D.new()
	forma.shape = CapsuleShape3D.new()
	forma.shape.radius = 0.3
	forma.shape.height = 1.7
	forma.position.y = 0.85
	add_child(forma)

	camara = Camera3D.new()
	camara.position.y = ALTURA_OJOS
	camara.fov = 75
	camara.current = true
	add_child(camara)

	_mirada = ShapeCast3D.new()
	_mirada.shape = SphereShape3D.new()
	_mirada.shape.radius = RADIO_MIRADA
	_mirada.target_position = Vector3(0, 0, -ALCANCE)
	_mirada.add_exception(self)
	camara.add_child(_mirada)


func _unhandled_input(evento: InputEvent) -> void:
	if not activo:
		return
	if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-evento.relative.x * SENSIBILIDAD)
		camara.rotation.x = clampf(camara.rotation.x - evento.relative.y * SENSIBILIDAD, deg_to_rad(-80), deg_to_rad(80))
	elif _es_usar(evento):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif consola_mirada() != "":
			consola_usada.emit(consola_mirada())


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravedad * delta
	var entrada := Vector2.ZERO
	if activo:
		entrada.x = _tecla(KEY_D, KEY_RIGHT) - _tecla(KEY_A, KEY_LEFT)
		entrada.y = _tecla(KEY_S, KEY_DOWN) - _tecla(KEY_W, KEY_UP)
	# La velocidad va en coordenadas del mundo, y la cabina puede estar girada: hay que usar la base global.
	var direccion := (global_transform.basis * Vector3(entrada.x, 0, entrada.y)).normalized()
	direccion.y = 0.0
	velocity.x = direccion.x * VELOCIDAD
	velocity.z = direccion.z * VELOCIDAD
	move_and_slide()


## Nombre de la consola a la que apunta la mirada ("consola_energia"...), o "".
func consola_mirada() -> String:
	for i in _mirada.get_collision_count():
		var consola := _consola_de(_mirada.get_collider(i))
		if consola != "":
			return consola
	return ""


## Mira hacia un punto (en coordenadas globales): para arrancar mirando la consola.
func mirar_hacia(punto: Vector3) -> void:
	if not is_inside_tree():
		return
	var ojos := global_position + Vector3.UP * ALTURA_OJOS
	var direccion := punto - ojos
	var padre := get_parent_node_3d()
	rotation.y = atan2(-direccion.x, -direccion.z) - (padre.global_rotation.y if padre else 0.0)
	camara.rotation.x = atan2(direccion.y, Vector2(direccion.x, direccion.z).length())


## Las piezas de una consola también empiezan con "consola_": nos quedamos con la de más arriba.
func _consola_de(nodo: Node) -> String:
	var consola := ""
	while nodo:
		if String(nodo.name).begins_with("consola_"):
			consola = nodo.name
		nodo = nodo.get_parent()
	return consola


func _es_usar(evento: InputEvent) -> bool:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		return evento.physical_keycode == KEY_E
	return evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT


func _tecla(principal: Key, alternativa: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(principal) or Input.is_physical_key_pressed(alternativa) else 0.0
