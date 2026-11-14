class_name Interfaz
extends RefCounted
## Colores y piezas de interfaz provisorias que comparten todas las pantallas.
## Cuando llegue el tema de arte se cambia acá, no en cada pantalla.

const FONDO := Color("#0B1030")
const PANEL := Color("#151D4A")
const AQUA := Color("#2EC4E6")
const CIAN := Color("#8FE3FF")
const LIMA := Color("#8EDB4F")
const BLANCO := Color("#F2F7FA")
const ALERTA := Color("#FF8A2B")


## Pone el fondo de la pantalla y devuelve un contenedor con márgenes para el contenido.
static func preparar_pantalla(pantalla: Control) -> MarginContainer:
	var fondo := ColorRect.new()
	fondo.color = FONDO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pantalla.add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 16)
	pantalla.add_child(margen)
	return margen


static func etiqueta(texto: String, color: Color = BLANCO, tamano: int = 16) -> Label:
	var nueva := Label.new()
	nueva.text = texto
	nueva.add_theme_color_override("font_color", color)
	nueva.add_theme_font_size_override("font_size", tamano)
	return nueva


## Etiqueta de varias líneas que se ajusta al ancho disponible.
static func parrafo(texto: String, color: Color = BLANCO, tamano: int = 16) -> Label:
	var nueva := etiqueta(texto, color, tamano)
	nueva.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nueva.custom_minimum_size.x = 120
	return nueva


static func panel(color: Color = PANEL, relleno: int = 12) -> PanelContainer:
	var nuevo := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(relleno)
	nuevo.add_theme_stylebox_override("panel", estilo)
	return nuevo


static func boton(texto: String, tamano: int = 18) -> Button:
	var nuevo := Button.new()
	nuevo.text = texto
	nuevo.add_theme_font_size_override("font_size", tamano)
	return nuevo


## Botón de la acción principal de cada pantalla: lima, grande, imposible de no ver.
static func boton_principal(texto: String, tamano: int = 22) -> Button:
	var nuevo := boton(texto, tamano)
	var colores := {"normal": LIMA, "hover": LIMA.lightened(0.25), "pressed": LIMA.darkened(0.2), "focus": LIMA, "disabled": Color("#3A4466")}
	for estado in colores:
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = colores[estado]
		estilo.set_corner_radius_all(8)
		estilo.content_margin_left = 24
		estilo.content_margin_right = 24
		estilo.content_margin_top = 10
		estilo.content_margin_bottom = 10
		nuevo.add_theme_stylebox_override(estado, estilo)
	for estado in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		nuevo.add_theme_color_override(estado, FONDO)
	nuevo.add_theme_color_override("font_disabled_color", Color(BLANCO, 0.4))
	nuevo.focus_mode = Control.FOCUS_NONE
	return nuevo


static func barra(color: Color = AQUA, maximo: float = 1.0) -> ProgressBar:
	var nueva := ProgressBar.new()
	nueva.max_value = maximo
	nueva.step = 0.0
	nueva.show_percentage = false
	nueva.custom_minimum_size.y = 16
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = color
	nueva.add_theme_stylebox_override("fill", relleno)
	return nueva


static func color_barra(barra_a_pintar: ProgressBar, color: Color) -> void:
	(barra_a_pintar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = color


## Borde oscuro del visor del casco, para cuando se tiene puesto el traje.
static func visor_casco() -> TextureRect:
	var gradiente := Gradient.new()
	gradiente.set_color(0, Color(0, 0, 0, 0))
	gradiente.set_color(1, Color(FONDO, 0.85))
	gradiente.add_point(0.7, Color(0, 0, 0, 0))
	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.05, 0.5)
	var visor := TextureRect.new()
	visor.texture = textura
	visor.stretch_mode = TextureRect.STRETCH_SCALE
	visor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return visor


static func vbox(separacion: int = 8) -> VBoxContainer:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", separacion)
	return caja


static func hbox(separacion: int = 8) -> HBoxContainer:
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", separacion)
	return caja
