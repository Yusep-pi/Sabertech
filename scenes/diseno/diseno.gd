extends Control
## Pantalla de diseño mínima, sin arte, para probar los medidores.
##
## Los botones se arman a partir de data/datos.json, así que agregar o cambiar
## piezas no requiere tocar esta escena. Todo el cálculo lo hace GameState.

const COLOR_FONDO := Color("#0B1030")
const COLOR_OK := Color("#2EC4E6")
const COLOR_ALERTA := Color("#FF8A2B")
const COLOR_TEXTO := Color("#F2F7FA")
const COLOR_TENUE := Color("#8FE3FF")
## Las barras llegan hasta 150% del límite para que se vea cuánto se pasa.
const BARRA_MAXIMO := 1.5

var _botones_pieza: Dictionary = {}  # id de pieza -> BaseButton
var _barras: Dictionary = {}  # id de medidor -> {barra, estilo, etiqueta}
var _selector_mision: OptionButton
var _texto_mision: Label
var _texto_seleccion: Label
var _texto_fiabilidad: Label
var _aviso: Label
var _boton_lanzar: Button


func _ready() -> void:
	_construir_ui()
	GameState.mision_cambiada.connect(_on_mision_cambiada)
	GameState.seleccion_cambiada.connect(_on_seleccion_cambiada)
	GameState.medidores_cambiados.connect(_on_medidores_cambiados)

	# Mientras no exista el briefing, arrancamos con la primera misión.
	if GameState.mision.is_empty() and not GameState.get_misiones().is_empty():
		GameState.elegir_mision(GameState.get_misiones()[0]["id"])
	else:
		_on_mision_cambiada(GameState.mision)
	_on_seleccion_cambiada(GameState.seleccion)
	_on_medidores_cambiados(GameState.medidores)


# --- Construcción -----------------------------------------------------------

func _construir_ui() -> void:
	var fondo := ColorRect.new()
	fondo.color = COLOR_FONDO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 16)
	add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	margen.add_child(columna)

	columna.add_child(_construir_barra_mision())

	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 16)
	columna.add_child(cuerpo)
	cuerpo.add_child(_construir_lista_piezas())
	cuerpo.add_child(_construir_centro())
	cuerpo.add_child(_construir_medidores())

	columna.add_child(_construir_pie())


func _construir_barra_mision() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	fila.add_child(_etiqueta("Misión:", COLOR_TEXTO, 20))

	_selector_mision = OptionButton.new()
	for m in GameState.get_misiones():
		_selector_mision.add_item("%s (%s)" % [m["nombre"], m["dificultad"]])
		_selector_mision.set_item_metadata(_selector_mision.item_count - 1, m["id"])
	_selector_mision.item_selected.connect(func(indice: int) -> void:
		GameState.elegir_mision(_selector_mision.get_item_metadata(indice)))
	fila.add_child(_selector_mision)

	_texto_mision = _etiqueta("", COLOR_TENUE)
	_texto_mision.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_texto_mision.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fila.add_child(_texto_mision)
	return fila


func _construir_lista_piezas() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 420
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 4)
	scroll.add_child(lista)

	for categoria in GameState.get_categorias():
		var titulo: String = categoria["nombre"]
		if categoria.get("multiple", false):
			titulo += "  (varias)"
		lista.add_child(_etiqueta(titulo, COLOR_OK, 18))
		for pieza in GameState.get_piezas(categoria["id"]):
			var boton: BaseButton
			if categoria.get("multiple", false):
				boton = CheckBox.new()
			else:
				boton = Button.new()
				boton.toggle_mode = true
				boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
			boton.text = _texto_pieza(pieza)
			boton.tooltip_text = pieza.get("descripcion", "")
			boton.pressed.connect(GameState.alternar_pieza.bind(pieza["id"]))
			lista.add_child(boton)
			_botones_pieza[pieza["id"]] = boton
		lista.add_child(HSeparator.new())
	return scroll


func _construir_centro() -> Control:
	var centro := VBoxContainer.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Lugar reservado para la nave 3D (rol de arte).
	var nave := PanelContainer.new()
	nave.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var marcador := _etiqueta("[ nave 3D ]", COLOR_TENUE, 22)
	marcador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marcador.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nave.add_child(marcador)
	centro.add_child(nave)

	_texto_seleccion = _etiqueta("", COLOR_TEXTO)
	_texto_seleccion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	centro.add_child(_texto_seleccion)
	return centro


func _construir_medidores() -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 320
	panel.add_theme_constant_override("separation", 6)

	for id in ["costo", "masa", "energia", "datos", "delta_v"]:
		var nombre := _etiqueta("", COLOR_TEXTO, 18)
		panel.add_child(nombre)

		var barra := ProgressBar.new()
		barra.max_value = BARRA_MAXIMO
		barra.step = 0.0
		barra.show_percentage = false
		barra.custom_minimum_size.y = 18
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = COLOR_OK
		barra.add_theme_stylebox_override("fill", estilo)
		panel.add_child(barra)

		var valores := _etiqueta("", COLOR_TENUE)
		panel.add_child(valores)
		_barras[id] = {"nombre": nombre, "barra": barra, "estilo": estilo, "valores": valores}

	panel.add_child(HSeparator.new())
	_texto_fiabilidad = _etiqueta("", COLOR_TENUE)
	panel.add_child(_texto_fiabilidad)
	return panel


func _construir_pie() -> Control:
	var fila := HBoxContainer.new()
	_aviso = _etiqueta("", COLOR_ALERTA)
	_aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(_aviso)

	_boton_lanzar = Button.new()
	_boton_lanzar.text = "  LANZAR  "
	_boton_lanzar.add_theme_font_size_override("font_size", 22)
	_boton_lanzar.pressed.connect(_on_lanzar)
	fila.add_child(_boton_lanzar)
	return fila


# --- Actualización ----------------------------------------------------------

func _on_mision_cambiada(mision: Dictionary) -> void:
	if mision.is_empty():
		_texto_mision.text = ""
		return
	for i in _selector_mision.item_count:
		if _selector_mision.get_item_metadata(i) == mision["id"]:
			_selector_mision.select(i)
	_texto_mision.text = mision.get("objetivo", "")


func _on_seleccion_cambiada(ids: Array) -> void:
	for id in _botones_pieza:
		_botones_pieza[id].set_pressed_no_signal(id in ids)

	var nombres := []
	for pieza in GameState.piezas_elegidas():
		nombres.append(pieza["nombre"])
	_texto_seleccion.text = "A bordo: " + (", ".join(nombres) if not nombres.is_empty() else "nada todavía")


func _on_medidores_cambiados(medidores: Dictionary) -> void:
	for id in _barras:
		if not medidores.has(id):
			continue
		var m: Dictionary = medidores[id]
		var ui: Dictionary = _barras[id]
		var limite: float = m["limite"]
		var valor: float = m["valor"]
		var proporcion := valor / limite if limite > 0.0 else (BARRA_MAXIMO if valor > 0.0 else 0.0)
		var color := COLOR_OK if m["ok"] else COLOR_ALERTA

		ui["nombre"].text = m["nombre"] + ("" if m["ok"] else "  ⚠")
		ui["barra"].value = minf(proporcion, BARRA_MAXIMO)
		ui["estilo"].bg_color = color
		var signo := "≥" if m["mayor_es_mejor"] else "≤"
		ui["valores"].text = "%s  %s  %s %s" % [_numero(valor), signo, _numero(limite), m["unidad"]]
		ui["valores"].add_theme_color_override("font_color", COLOR_TENUE if m["ok"] else COLOR_ALERTA)

	var detalle := GameState.detalle
	_texto_fiabilidad.text = "Fiabilidad del lanzamiento: %d%%\nFiabilidad de la nave: %d%%" % [
		roundi(detalle.get("fiabilidad_lanzamiento", 0.0) * 100),
		roundi(detalle.get("fiabilidad_nave", 0.0) * 100),
	]
	_actualizar_aviso()


func _actualizar_aviso() -> void:
	var faltan := GameState.categorias_faltantes()
	_boton_lanzar.disabled = not GameState.puede_lanzar()
	if not faltan.is_empty():
		_aviso.text = "Falta elegir: " + ", ".join(faltan)
		return
	var en_rojo := []
	for m in GameState.medidores.values():
		if not m["ok"]:
			en_rojo.append(m["nombre"])
	_aviso.text = "" if en_rojo.is_empty() else "Podés lanzar, pero hay problemas con: " + ", ".join(en_rojo)


func _on_lanzar() -> void:
	# La fase de lanzamiento todavía no existe: dejamos constancia y nada más.
	print("Lanzar con: ", GameState.seleccion, "  medidores: ", GameState.medidores)
	_aviso.text = "Lanzamiento pendiente: la pantalla de la fase 3 todavía no existe."


# --- Utilidades -------------------------------------------------------------

func _texto_pieza(pieza: Dictionary) -> String:
	var partes := [pieza["nombre"], "%s M$" % _numero(pieza.get("costo", 0.0))]
	if pieza.get("masa", 0.0) > 0.0:
		partes.append("%s kg" % _numero(pieza["masa"]))
	if pieza.get("potencia", 0.0) > 0.0:
		partes.append("+%s W" % _numero(pieza["potencia"]))
	if pieza.get("consumo", 0.0) > 0.0:
		partes.append("−%s W" % _numero(pieza["consumo"]))
	if pieza.has("capacidad"):
		partes.append("carga %s kg" % _numero(pieza["capacidad"]))
	if pieza.has("isp"):
		partes.append("Isp %s s" % _numero(pieza["isp"]))
	if pieza.has("tasa"):
		partes.append("%s u/turno" % _numero(pieza["tasa"]))
	if pieza.has("datos"):
		partes.append("%s datos" % _numero(pieza["datos"]))
	return "  ·  ".join(partes)


static func _numero(valor: float) -> String:
	return str(roundi(valor))


static func _etiqueta(texto: String, color: Color, tamano: int = 16) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	return etiqueta
