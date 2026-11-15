extends CenterContainer
## Panel de reparación de la caminata espacial: un pequeño puzzle.
##
## Hay perillas (de 0 a 10) e interruptores, e indicadores con una zona verde.
## Cada perilla mueve varios indicadores a la vez, con distinta fuerza y a veces
## al revés, así que no alcanza con subir una al máximo: hay que encontrar el
## punto intermedio donde todos quedan en verde. Siempre existe una solución con
## las perillas en valores intermedios (3 a 7).

signal resuelto

const MAXIMO := 10
const PESOS := [-2, -1, 1, 2, 3]
## Segundos que hay que sostener todo en verde para que cuente.
const CONFIRMACION := 0.8


## Una barra con la zona verde y una marca en el valor actual.
class Medidor extends Control:
	var minimo := 0.0
	var maximo := 1.0
	var zona := Vector2.ZERO  # desde, hasta
	var valor := 0.0

	func _draw() -> void:
		var ancho := size.x
		var alto := size.y
		draw_rect(Rect2(0, 0, ancho, alto), Interfaz.FONDO)
		var desde := _x(zona.x)
		draw_rect(Rect2(desde, 0, _x(zona.y) - desde, alto), Color(Interfaz.LIMA, 0.45))
		var en_zona := valor >= zona.x and valor <= zona.y
		draw_rect(Rect2(_x(valor) - 3, -4, 6, alto + 8), Interfaz.LIMA if en_zona else Interfaz.ALERTA)

	func _x(v: float) -> float:
		return clampf((v - minimo) / maxf(maximo - minimo, 0.001), 0.0, 1.0) * size.x


var titulo := ""
var _controles: Array = []  # {nombre, valor, solucion, texto, barra}
var _indicadores: Array = []  # {nombre, pesos, offsets, centro, medidor, estado}
var _interruptores: Array = []  # {nombre, encendido, correcto, boton}
var _tolerancia := 1.0
var _estado: Label
var _confirmando := 0.0
var _terminado := false


## Arma el puzzle de una tarea de datos.json ("controles", "indicadores", "interruptores").
func configurar(tarea: Dictionary, tolerancia: float, azar: RandomNumberGenerator) -> void:
	titulo = tarea["titulo"]
	_tolerancia = tolerancia
	for intento in 50:
		_generar(tarea, azar)
		if not esta_resuelto():
			break
	_construir_ui()
	_actualizar()


func _generar(tarea: Dictionary, azar: RandomNumberGenerator) -> void:
	_controles.clear()
	_indicadores.clear()
	_interruptores.clear()
	for nombre in tarea.get("controles", []):
		# La solución queda en el medio; el arranque, cerca de un extremo.
		var inicio := azar.randi_range(0, 2) if azar.randf() < 0.5 else azar.randi_range(8, MAXIMO)
		_controles.append({"nombre": nombre, "valor": inicio, "solucion": azar.randi_range(3, 7)})
	for nombre in tarea.get("interruptores", []):
		var correcto := azar.randf() < 0.5
		_interruptores.append({"nombre": nombre, "encendido": not correcto, "correcto": correcto})
	for nombre in tarea.get("indicadores", []):
		var pesos := []
		for c in _controles:
			pesos.append(PESOS[azar.randi_range(0, PESOS.size() - 1)])
		var offsets := []
		for s in _interruptores:
			offsets.append(azar.randi_range(3, 6) * (1 if azar.randf() < 0.5 else -1))
		_indicadores.append({"nombre": nombre, "pesos": pesos, "offsets": offsets, "centro": 0.0})
	# El centro de cada zona verde es el valor que da la solución.
	for indicador in _indicadores:
		indicador["centro"] = _valor(indicador, true)


## Valor de un indicador con los controles actuales (o con los de la solución).
func _valor(indicador: Dictionary, con_solucion := false) -> float:
	var total := 0.0
	for c in _controles.size():
		total += indicador["pesos"][c] * (_controles[c]["solucion"] if con_solucion else _controles[c]["valor"])
	for s in _interruptores.size():
		var encendido: bool = _interruptores[s]["correcto"] if con_solucion else _interruptores[s]["encendido"]
		if encendido:
			total += indicador["offsets"][s]
	return total


func esta_resuelto() -> bool:
	for indicador in _indicadores:
		if absf(_valor(indicador) - indicador["centro"]) > _tolerancia:
			return false
	return true


## Para pruebas: los valores que resuelven el panel.
func solucion() -> Dictionary:
	return {
		"controles": _controles.map(func(c): return c["solucion"]),
		"interruptores": _interruptores.map(func(s): return s["correcto"]),
	}


func poner_control(indice: int, valor: int) -> void:
	_controles[indice]["valor"] = clampi(valor, 0, MAXIMO)
	_actualizar()


func poner_interruptor(indice: int, encendido: bool) -> void:
	_interruptores[indice]["encendido"] = encendido
	_interruptores[indice]["boton"].set_pressed_no_signal(encendido)
	_actualizar()


func _process(delta: float) -> void:
	if not visible or _terminado:
		return
	if esta_resuelto():
		_confirmando += delta
		if _confirmando >= CONFIRMACION:
			_terminado = true
			resuelto.emit()
	else:
		_confirmando = 0.0


# --- Interfaz ---------------------------------------------------------------

func _construir_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_top = 150
	var panel := Interfaz.panel(Color(Interfaz.PANEL, 0.94), 20)
	panel.custom_minimum_size = Vector2(800, 0)
	add_child(panel)
	var caja := Interfaz.vbox(12)
	panel.add_child(caja)

	caja.add_child(Interfaz.etiqueta(tr("Panel de reparación · %s") % titulo, Interfaz.AQUA, 22))
	caja.add_child(Interfaz.parrafo(tr("Ajustá los controles hasta que todos los indicadores queden en la zona verde. Cada perilla mueve más de un indicador. El oxígeno sigue corriendo."), Interfaz.CIAN, 15))

	var columnas := Interfaz.hbox(28)
	caja.add_child(columnas)
	var izquierda := Interfaz.vbox(10)
	izquierda.custom_minimum_size.x = 340
	columnas.add_child(izquierda)
	izquierda.add_child(Interfaz.etiqueta(tr("Indicadores"), Interfaz.BLANCO, 17))
	for indicador in _indicadores:
		izquierda.add_child(Interfaz.etiqueta(indicador["nombre"], Interfaz.CIAN, 15))
		var medidor := Medidor.new()
		medidor.custom_minimum_size = Vector2(320, 22)
		var limites := _limites(indicador)
		medidor.minimo = limites.x
		medidor.maximo = limites.y
		medidor.zona = Vector2(indicador["centro"] - _tolerancia, indicador["centro"] + _tolerancia)
		izquierda.add_child(medidor)
		indicador["medidor"] = medidor
		indicador["estado"] = Interfaz.etiqueta("", Interfaz.ALERTA, 13)
		izquierda.add_child(indicador["estado"])

	var derecha := Interfaz.vbox(10)
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columnas.add_child(derecha)
	derecha.add_child(Interfaz.etiqueta(tr("Controles"), Interfaz.BLANCO, 17))
	for i in _controles.size():
		var fila := Interfaz.hbox(8)
		var nombre := Interfaz.etiqueta(_controles[i]["nombre"], Interfaz.CIAN, 15)
		nombre.custom_minimum_size.x = 140
		fila.add_child(nombre)
		var menos := Interfaz.boton(" − ", 18)
		menos.pressed.connect(func() -> void: poner_control(i, _controles[i]["valor"] - 1))
		fila.add_child(menos)
		var barra := Interfaz.barra(Interfaz.AQUA, MAXIMO)
		barra.custom_minimum_size = Vector2(120, 14)
		barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fila.add_child(barra)
		var mas := Interfaz.boton(" + ", 18)
		mas.pressed.connect(func() -> void: poner_control(i, _controles[i]["valor"] + 1))
		fila.add_child(mas)
		var texto := Interfaz.etiqueta("", Interfaz.BLANCO, 16)
		texto.custom_minimum_size.x = 28
		fila.add_child(texto)
		_controles[i]["barra"] = barra
		_controles[i]["texto"] = texto
		derecha.add_child(fila)
	for i in _interruptores.size():
		var boton := CheckButton.new()
		boton.text = _interruptores[i]["nombre"]
		boton.add_theme_font_size_override("font_size", 15)
		boton.button_pressed = _interruptores[i]["encendido"]
		boton.toggled.connect(func(encendido: bool) -> void: poner_interruptor(i, encendido))
		_interruptores[i]["boton"] = boton
		derecha.add_child(boton)

	_estado = Interfaz.etiqueta("", Interfaz.ALERTA, 18)
	caja.add_child(_estado)
	caja.add_child(Interfaz.etiqueta(tr("Esc: soltarte del panel (lo que ajustaste queda así)"), Color(Interfaz.CIAN, 0.7), 13))


## El rango que puede recorrer un indicador con todas las combinaciones posibles.
func _limites(indicador: Dictionary) -> Vector2:
	var minimo := 0.0
	var maximo := 0.0
	for peso in indicador["pesos"]:
		minimo += minf(0.0, peso * MAXIMO)
		maximo += maxf(0.0, peso * MAXIMO)
	for offset in indicador["offsets"]:
		minimo += minf(0.0, offset)
		maximo += maxf(0.0, offset)
	return Vector2(minimo, maximo)


func _actualizar() -> void:
	if not _estado:
		return
	for control in _controles:
		control["barra"].value = control["valor"]
		control["texto"].text = str(control["valor"])
	var en_verde := 0
	for indicador in _indicadores:
		var valor := _valor(indicador)
		indicador["medidor"].valor = valor
		indicador["medidor"].queue_redraw()
		var diferencia: float = valor - indicador["centro"]
		if absf(diferencia) <= _tolerancia:
			indicador["estado"].text = tr("En rango ✓")
			indicador["estado"].add_theme_color_override("font_color", Interfaz.LIMA)
			en_verde += 1
		else:
			indicador["estado"].text = tr("Muy alto") if diferencia > 0 else tr("Muy bajo")
			indicador["estado"].add_theme_color_override("font_color", Interfaz.ALERTA)
	if en_verde == _indicadores.size():
		_estado.text = tr("¡Funciona! Mantené así...")
		_estado.add_theme_color_override("font_color", Interfaz.LIMA)
	else:
		_estado.text = tr("%d de %d indicadores en verde") % [en_verde, _indicadores.size()]
		_estado.add_theme_color_override("font_color", Interfaz.ALERTA)
