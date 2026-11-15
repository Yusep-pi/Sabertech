class_name Compuerta
extends CanvasLayer
## Puertas entre ambientes de la nave (cabina, habitáculo, esclusa): se cruzan
## manteniendo E unos instantes cerca de la puerta. Muestra la indicación, una
## barra de progreso y un fundido a negro al salir y al entrar.
##
## Uso, desde un ambiente:
##   var compuerta := Compuerta.new()
##   compuerta.jugador = _jugador
##   compuerta.agregar(func(): return <el jugador está cerca>, "Ir al habitáculo", "habitaculo", "cabina")
##   add_child(compuerta)

const TIEMPO_MANTENER := 1.1
const FUNDIDO := 0.3

## Debe tener "activo" (bool); se desactiva al cruzar.
var jugador: Node3D

## {cerca: Callable -> bool, texto, destino, origen, bloqueo: Callable -> String}
var _puertas: Array = []
var _actual: Dictionary = {}
var _tiempo := 0.0
var _cruzando := false
var _indicacion: Label
var _caja_progreso: VBoxContainer
var _barra: ProgressBar
var _fundido: ColorRect


## cerca: si el jugador está junto a esta puerta. destino: ambiente de GameState.AMBIENTES.
## origen: cómo se llama este ambiente para el de destino. bloqueo (opcional):
## devuelve "" si se puede pasar, o el motivo por el que no.
func agregar(cerca: Callable, texto: String, destino: String, origen: String, bloqueo := Callable()) -> void:
	_puertas.append({"cerca": cerca, "texto": texto, "destino": destino, "origen": origen, "bloqueo": bloqueo})


func _ready() -> void:
	layer = 4
	_indicacion = Interfaz.etiqueta("", Interfaz.BLANCO, 20)
	_indicacion.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_indicacion.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_indicacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicacion.offset_top = 58
	add_child(_indicacion)

	_caja_progreso = Interfaz.vbox(4)
	_caja_progreso.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_caja_progreso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caja_progreso.custom_minimum_size.x = 240
	_caja_progreso.offset_top = 92
	_caja_progreso.visible = false
	add_child(_caja_progreso)
	_barra = Interfaz.barra(Interfaz.LIMA, 1.0)
	_barra.custom_minimum_size.y = 10
	_caja_progreso.add_child(_barra)

	_fundido = ColorRect.new()
	_fundido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundido.color = Color(0, 0, 0, 0)
	add_child(_fundido)
	for control in find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Si se llegó cruzando una puerta, la escena arranca en negro y aparece.
	if GameState.origen_transicion != "":
		_fundido.color.a = 1.0
		create_tween().tween_property(_fundido, "color:a", 0.0, FUNDIDO + 0.1)


func _process(delta: float) -> void:
	if _cruzando or not jugador or not jugador.get("activo"):
		_indicacion.text = ""
		_caja_progreso.visible = false
		_tiempo = 0.0
		return
	_actual = {}
	for puerta in _puertas:
		if puerta["cerca"].call():
			_actual = puerta
			break
	if _actual.is_empty():
		_indicacion.text = ""
		_caja_progreso.visible = false
		_tiempo = 0.0
		return

	var motivo: String = _actual["bloqueo"].call() if _actual["bloqueo"].is_valid() else ""
	if motivo != "":
		_indicacion.text = motivo
		_indicacion.add_theme_color_override("font_color", Interfaz.ALERTA)
		_caja_progreso.visible = false
		_tiempo = 0.0
		return
	_indicacion.text = tr("[Mantener E] %s") % tr(_actual["texto"])
	_indicacion.add_theme_color_override("font_color", Interfaz.BLANCO)
	if Input.is_physical_key_pressed(KEY_E):
		_tiempo += delta
	else:
		_tiempo = maxf(0.0, _tiempo - delta * 3.0)
	_caja_progreso.visible = _tiempo > 0.0
	_barra.value = _tiempo / TIEMPO_MANTENER
	if _tiempo >= TIEMPO_MANTENER:
		cruzar(_actual)


## Cruza una puerta: fundido a negro y cambio de ambiente. Lo usan también las pruebas.
func cruzar(puerta: Dictionary) -> void:
	_cruzando = true
	jugador.set("activo", false)
	_caja_progreso.visible = false
	var tween := create_tween()
	tween.tween_property(_fundido, "color:a", 1.0, FUNDIDO)
	tween.tween_callback(func() -> void:
		GameState.origen_transicion = puerta["origen"]
		GameState.ir_a(puerta["destino"]))


## La primera puerta agregada con ese destino (para pruebas).
func puerta_hacia(destino: String) -> Dictionary:
	for puerta in _puertas:
		if puerta["destino"] == destino:
			return puerta
	return {}
