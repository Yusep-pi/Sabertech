class_name CartelesNitidos
extends CanvasLayer
## Dibuja en 2D los carteles 3D que flotan sobre todo (Label3D con billboard y sin
## prueba de profundidad: "[E] Diseñar y lanzar", los marcadores de la caminata…),
## siguiendo su posición en pantalla. Así no les afectan la profundidad de campo
## ni el filtro retro, y se leen siempre nítidos. El cartel 3D sigue existiendo
## (las escenas lo mueven, le cambian el texto, el color o lo ocultan) pero se
## vuelve invisible: este nodo copia todo eso en cada cuadro.
##
## Lo crea el autoload Estilo, que le pasa cada cartel con registrar().

const TAMANO_MINIMO := 10
const TAMANO_MAXIMO := 72

var _carteles: Array = []  # [{cartel: Label3D, etiqueta: Label}]


func _init() -> void:
	# Por encima del filtro retro (capa -1) y por debajo de las pantallas de interfaz.
	layer = 1


func registrar(cartel: Label3D) -> void:
	var etiqueta := Label.new()
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.visible = false
	add_child(etiqueta)
	_carteles.append({"cartel": cartel, "etiqueta": etiqueta})
	cartel.transparency = 1.0


func _process(_delta: float) -> void:
	var camara := get_viewport().get_camera_3d()
	var alto_pantalla := get_viewport().get_visible_rect().size.y
	for i in range(_carteles.size() - 1, -1, -1):
		var datos: Dictionary = _carteles[i]
		var etiqueta: Label = datos["etiqueta"]
		if not is_instance_valid(datos["cartel"]):
			etiqueta.queue_free()
			_carteles.remove_at(i)
			continue
		var cartel: Label3D = datos["cartel"]
		etiqueta.visible = camara != null and cartel.is_visible_in_tree() and not camara.is_position_behind(cartel.global_position)
		if not etiqueta.visible:
			continue

		# Mismo tamaño en pantalla que tendría el cartel 3D.
		var escala := alto_pantalla / (2.0 * tan(deg_to_rad(camara.fov) / 2.0))
		var distancia := 1.0 if cartel.fixed_size else maxf(camara.global_position.distance_to(cartel.global_position), 0.1)
		var tamano := clampi(roundi(cartel.font_size * cartel.pixel_size * escala / distancia), TAMANO_MINIMO, TAMANO_MAXIMO)
		etiqueta.text = cartel.text
		etiqueta.add_theme_font_size_override("font_size", tamano)
		etiqueta.add_theme_color_override("font_color", cartel.modulate)
		etiqueta.add_theme_constant_override("outline_size", maxi(roundi(cartel.outline_size * tamano / float(maxi(cartel.font_size, 1))), 2))
		etiqueta.add_theme_color_override("font_outline_color", cartel.outline_modulate)
		etiqueta.reset_size()
		etiqueta.position = camara.unproject_position(cartel.global_position) - etiqueta.size / 2.0
