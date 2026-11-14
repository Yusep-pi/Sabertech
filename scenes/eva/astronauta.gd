extends CharacterBody3D
## Astronauta en gravedad cero con mochila propulsora, en primera persona.
##
## No hay arriba ni abajo: el mouse gira todo el cuerpo y Z/C lo rotan sobre sí
## mismo. El propulsor empuja en la dirección de las teclas y la inercia se
## conserva: para frenar hay que empujar al revés o usar el freno (X), y las dos
## cosas gastan combustible. Los choques fuertes dañan el traje.

signal choque(velocidad: float)

const SENSIBILIDAD := 0.0025
const VELOCIDAD_GIRO := 1.2  # rad/s con Z y C

## Lo ajusta el nivel con los valores de datos.json.
var empuje := 3.0
var consumo := 6.0
var velocidad_maxima := 9.0
var combustible := 100.0
var activo := true
var camara: Camera3D
## Para la interfaz: si en este cuadro el propulsor está encendido.
var propulsando := false


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var forma := CollisionShape3D.new()
	forma.shape = CapsuleShape3D.new()
	forma.shape.radius = 0.35
	forma.shape.height = 1.8
	add_child(forma)

	camara = Camera3D.new()
	camara.position.y = 0.6
	camara.fov = 80
	camara.far = 4000
	camara.current = true
	add_child(camara)


func _unhandled_input(evento: InputEvent) -> void:
	if not activo:
		return
	if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_object_local(Vector3.UP, -evento.relative.x * SENSIBILIDAD)
		rotate_object_local(Vector3.RIGHT, -evento.relative.y * SENSIBILIDAD)
	elif evento is InputEventMouseButton and evento.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	propulsando = false
	if activo:
		var giro := _tecla(KEY_Z) - _tecla(KEY_C)
		if giro != 0.0:
			rotate_object_local(Vector3.BACK, giro * VELOCIDAD_GIRO * delta)
		transform.basis = transform.basis.orthonormalized()

		var direccion := Vector3(
			_tecla(KEY_D) - _tecla(KEY_A),
			_tecla(KEY_SPACE) - _tecla(KEY_CTRL),
			_tecla(KEY_S) - _tecla(KEY_W))
		var turbo := 2.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
		if direccion != Vector3.ZERO and combustible > 0.0:
			velocity += global_transform.basis * direccion.normalized() * empuje * turbo * delta
			_gastar(consumo * turbo * delta)
		elif Input.is_physical_key_pressed(KEY_X) and combustible > 0.0 and velocity.length() > 0.02:
			# Freno: empuja contra el movimiento hasta quedar quieto.
			velocity = velocity.move_toward(Vector3.ZERO, empuje * 1.5 * delta)
			_gastar(consumo * delta)
	velocity = velocity.limit_length(velocidad_maxima)

	var antes := velocity
	move_and_slide()
	if get_slide_collision_count() > 0:
		var normal := get_slide_collision(0).get_normal()
		var impacto := -antes.dot(normal)
		if impacto > 0.0:
			choque.emit(impacto)
			# Un rebote suave: en el vacío nada frena el golpe.
			velocity = antes.bounce(normal) * 0.3


func _gastar(cantidad: float) -> void:
	combustible = maxf(0.0, combustible - cantidad)
	propulsando = true


func _tecla(tecla: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(tecla) else 0.0
