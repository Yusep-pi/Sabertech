extends Control
## Fase 2: diseño de la nave. Interfaz provisoria, sin arte.
##
## Los botones se arman a partir de data/datos.json, así que agregar o cambiar
## piezas no requiere tocar esta escena. Todo el cálculo lo hace GameState.

const NavePreview := preload("res://scenes/diseno/nave_preview.gd")
## Las barras llegan hasta 150% del límite para que se vea cuánto se pasa.
const BARRA_MAXIMO := 1.5

var _botones_pieza: Dictionary = {}  # id de pieza -> BaseButton
var _barras: Dictionary = {}  # id de medidor -> {nombre, barra, valores}
var _nave: NavePreview
var _texto_mision: Label
var _texto_seleccion: Label
var _texto_fiabilidad: Label
var _aviso: Label
var _boton_lanzar: Button


func _ready() -> void:
	# Si se abre esta escena sola desde el editor, arrancamos con la primera misión.
	if GameState.mision.is_empty() and not GameState.get_misiones().is_empty():
		GameState.elegir_mision(GameState.get_misiones()[0]["id"])
	GameState.volver_a_diseno()

	_construir_ui()
	GameState.seleccion_cambiada.connect(_on_seleccion_cambiada)
	GameState.medidores_cambiados.connect(_on_medidores_cambiados)
	_on_seleccion_cambiada(GameState.seleccion)
	_on_medidores_cambiados(GameState.medidores)


# --- Construcción -----------------------------------------------------------

func _construir_ui() -> void:
	var columna := Interfaz.vbox(12)
	Interfaz.preparar_pantalla(self).add_child(columna)

	columna.add_child(_construir_barra_mision())

	var cuerpo := Interfaz.hbox(16)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(cuerpo)
	cuerpo.add_child(_construir_lista_piezas())
	cuerpo.add_child(_construir_centro())
	cuerpo.add_child(_construir_medidores())

	columna.add_child(_construir_pie())


func _construir_barra_mision() -> Control:
	var fila := Interfaz.hbox(12)
	var mision := GameState.mision
	fila.add_child(Interfaz.etiqueta(mision.get("nombre", ""), Interfaz.BLANCO, 20))
	_texto_mision = Interfaz.etiqueta(mision.get("objetivo", ""), Interfaz.CIAN)
	_texto_mision.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(_texto_mision)
	var cambiar := Interfaz.boton(tr("Cambiar misión"), 16)
	cambiar.pressed.connect(GameState.ir_a.bind("briefing"))
	fila.add_child(cambiar)
	return fila


func _construir_lista_piezas() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 440
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var lista := Interfaz.vbox(4)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)

	for categoria in GameState.get_categorias():
		var titulo: String = categoria["nombre"]
		if categoria.get("multiple", false):
			titulo += tr("  (varias)")
		lista.add_child(Interfaz.etiqueta(titulo, Interfaz.AQUA, 18))
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
	var centro := Interfaz.vbox()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_nave = NavePreview.new()
	_nave.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centro.add_child(_nave)

	_texto_seleccion = Interfaz.parrafo("", Interfaz.BLANCO)
	centro.add_child(_texto_seleccion)
	return centro


func _construir_medidores() -> Control:
	var panel := Interfaz.vbox(6)
	panel.custom_minimum_size.x = 300

	for id in ["costo", "masa", "energia", "datos", "delta_v"]:
		var nombre := Interfaz.etiqueta("", Interfaz.BLANCO, 18)
		var barra := Interfaz.barra(Interfaz.AQUA, BARRA_MAXIMO)
		var valores := Interfaz.etiqueta("", Interfaz.CIAN)
		panel.add_child(nombre)
		panel.add_child(barra)
		panel.add_child(valores)
		_barras[id] = {"nombre": nombre, "barra": barra, "valores": valores}

	panel.add_child(HSeparator.new())
	_texto_fiabilidad = Interfaz.etiqueta("", Interfaz.CIAN)
	panel.add_child(_texto_fiabilidad)
	return panel


func _construir_pie() -> Control:
	var fila := Interfaz.hbox()
	_aviso = Interfaz.etiqueta("", Interfaz.ALERTA)
	_aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(_aviso)

	_boton_lanzar = Interfaz.boton_principal(tr("LANZAR"), 22)
	_boton_lanzar.pressed.connect(_on_lanzar)
	fila.add_child(_boton_lanzar)
	return fila


# --- Actualización ----------------------------------------------------------

func _on_seleccion_cambiada(ids: Array) -> void:
	for id in _botones_pieza:
		_botones_pieza[id].set_pressed_no_signal(id in ids)
	_nave.mostrar(ids)

	var nombres := []
	for pieza in GameState.piezas_elegidas():
		nombres.append(pieza["nombre"])
	_texto_seleccion.text = tr("A bordo: %s") % (", ".join(nombres) if not nombres.is_empty() else tr("nada todavía"))


func _on_medidores_cambiados(medidores: Dictionary) -> void:
	for id in _barras:
		if not medidores.has(id):
			continue
		var m: Dictionary = medidores[id]
		var ui: Dictionary = _barras[id]
		var limite: float = m["limite"]
		var valor: float = m["valor"]
		var proporcion := valor / limite if limite > 0.0 else (BARRA_MAXIMO if valor > 0.0 else 0.0)
		var color := Interfaz.AQUA if m["ok"] else Interfaz.ALERTA

		ui["nombre"].text = m["nombre"] + ("" if m["ok"] else "  ⚠")
		ui["barra"].value = minf(proporcion, BARRA_MAXIMO)
		Interfaz.color_barra(ui["barra"], color)
		var signo := "≥" if m["mayor_es_mejor"] else "≤"
		ui["valores"].text = "%d  %s  %d %s" % [roundi(valor), signo, roundi(limite), m["unidad"]]
		ui["valores"].add_theme_color_override("font_color", Interfaz.CIAN if m["ok"] else Interfaz.ALERTA)

	var detalle := GameState.detalle
	_texto_fiabilidad.text = tr("Fiabilidad del lanzamiento: %d%%\nFiabilidad de la nave: %d%%") % [
		roundi(detalle.get("fiabilidad_lanzamiento", 0.0) * 100),
		roundi(detalle.get("fiabilidad_nave", 0.0) * 100),
	]
	_actualizar_aviso()


func _actualizar_aviso() -> void:
	var faltan := GameState.categorias_faltantes()
	_boton_lanzar.disabled = not GameState.puede_lanzar()
	if not faltan.is_empty():
		_aviso.text = tr("Falta elegir: %s") % ", ".join(faltan)
		return
	var en_rojo := []
	for m in GameState.medidores.values():
		if not m["ok"]:
			en_rojo.append(m["nombre"])
	_aviso.text = "" if en_rojo.is_empty() else tr("Podés lanzar, pero hay problemas con: %s") % ", ".join(en_rojo)


func _on_lanzar() -> void:
	GameState.lanzar()
	GameState.ir_a("lanzamiento")


# --- Utilidades -------------------------------------------------------------

func _texto_pieza(pieza: Dictionary) -> String:
	var partes := [pieza["nombre"], tr("%d M$") % roundi(pieza.get("costo", 0.0))]
	if pieza.get("masa", 0.0) > 0.0:
		partes.append("%d kg" % roundi(pieza["masa"]))
	if pieza.get("potencia", 0.0) > 0.0:
		partes.append("+%d W" % roundi(pieza["potencia"]))
	if pieza.get("consumo", 0.0) > 0.0:
		partes.append("−%d W" % roundi(pieza["consumo"]))
	if pieza.has("capacidad"):
		partes.append(tr("carga %d kg") % roundi(pieza["capacidad"]))
	if pieza.has("isp"):
		partes.append("Isp %d s" % roundi(pieza["isp"]))
	if pieza.has("tasa"):
		partes.append(tr("%d u/turno") % roundi(pieza["tasa"]))
	if pieza.has("datos"):
		partes.append(tr("%d datos") % roundi(pieza["datos"]))
	return "  ·  ".join(partes)
