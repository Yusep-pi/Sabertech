extends Control
## Fase 4: operaciones. Cada turno se decide qué encender con la energía disponible.
## La ciencia solo cuenta cuando se transmite. Algunos turnos traen eventos.

var _turno: Label
var _condicion: Label
var _ciencia: Label
var _barra_ciencia: ProgressBar
var _estado: Dictionary = {}  # salud, bateria, memoria -> {barra, texto}
var _texto_dv: Label
var _texto_rotas: Label
var _texto_energia: Label
var _barra_energia: ProgressBar
var _interruptores: Dictionary = {}  # clave del plan -> CheckButton
var _prevision: Label
var _pronostico: Label
var _avisos: Label
var _bitacora: Label
var _paso: Label
var _boton_turno: Button
var _capa_evento: Control


func _ready() -> void:
	# Si se abre esta escena sola desde el editor, armamos una nave de prueba.
	if GameState.ops.is_empty():
		_preparar_partida_de_prueba()

	_construir_ui()
	GameState.plan_cambiado.connect(_actualizar)
	GameState.turno_iniciado.connect(_on_turno_iniciado)
	GameState.turno_terminado.connect(_on_turno_terminado)
	GameState.operaciones_terminadas.connect(_on_operaciones_terminadas)
	GameState.viaje_avanzado.connect(func(_p: float) -> void: _actualizar_boton_turno())
	_on_turno_iniciado(GameState.ops["turno"])


# --- Construcción -----------------------------------------------------------

func _construir_ui() -> void:
	var columna := Interfaz.vbox(12)
	Interfaz.preparar_pantalla(self).add_child(columna)

	var arriba := Interfaz.hbox(16)
	_turno = Interfaz.etiqueta("", Interfaz.BLANCO, 26)
	arriba.add_child(_turno)
	_condicion = Interfaz.etiqueta("", Interfaz.ALERTA, 18)
	_condicion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arriba.add_child(_condicion)
	var caja_ciencia := Interfaz.vbox(2)
	caja_ciencia.custom_minimum_size.x = 320
	_ciencia = Interfaz.etiqueta("", Interfaz.LIMA, 18)
	_barra_ciencia = Interfaz.barra(Interfaz.LIMA)
	caja_ciencia.add_child(_ciencia)
	caja_ciencia.add_child(_barra_ciencia)
	arriba.add_child(caja_ciencia)
	columna.add_child(arriba)

	var cuerpo := Interfaz.hbox(16)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(cuerpo)
	cuerpo.add_child(_construir_estado())
	cuerpo.add_child(_construir_plan())
	cuerpo.add_child(_construir_bitacora())

	var abajo := Interfaz.hbox(16)
	_paso = Interfaz.etiqueta("", Interfaz.LIMA, 18)
	_paso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paso.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	abajo.add_child(_paso)
	_boton_turno = Interfaz.boton_principal(tr("Terminar turno  ⏎"), 24)
	_boton_turno.pressed.connect(_on_boton_turno)
	abajo.add_child(_boton_turno)
	columna.add_child(abajo)


func _construir_estado() -> Control:
	var panel := Interfaz.panel()
	panel.custom_minimum_size.x = 280
	var caja := Interfaz.vbox(6)
	panel.add_child(caja)
	caja.add_child(Interfaz.etiqueta(tr("Estado de la nave"), Interfaz.AQUA, 18))
	for clave in ["salud", "bateria", "memoria"]:
		var texto := Interfaz.etiqueta("", Interfaz.BLANCO)
		var barra := Interfaz.barra()
		caja.add_child(texto)
		caja.add_child(barra)
		_estado[clave] = {"texto": texto, "barra": barra}
	caja.add_child(HSeparator.new())
	_texto_dv = Interfaz.parrafo("", Interfaz.CIAN)
	caja.add_child(_texto_dv)
	_texto_rotas = Interfaz.parrafo("", Interfaz.ALERTA)
	caja.add_child(_texto_rotas)
	return panel


func _construir_plan() -> Control:
	var panel := Interfaz.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var caja := Interfaz.vbox(8)
	panel.add_child(caja)
	caja.add_child(Interfaz.etiqueta(tr("Plan de energía del turno"), Interfaz.AQUA, 18))
	_texto_energia = Interfaz.parrafo("", Interfaz.BLANCO)
	caja.add_child(_texto_energia)
	_barra_energia = Interfaz.barra()
	caja.add_child(_barra_energia)
	caja.add_child(Interfaz.etiqueta(tr("Sistemas básicos: −%d W (siempre encendidos)") % roundi(GameState.get_nave_base().get("consumo", 0.0)), Interfaz.CIAN))

	_agregar_interruptor(caja, "calefaccion")
	_agregar_interruptor(caja, "transmitir")
	for pieza in GameState.piezas_elegidas("instrumento"):
		_agregar_interruptor(caja, pieza["id"])
	if GameState.piezas_elegidas("instrumento").is_empty():
		caja.add_child(Interfaz.parrafo(tr("La nave no lleva instrumentos: no hay ciencia para captar."), Interfaz.ALERTA))

	caja.add_child(HSeparator.new())
	_prevision = Interfaz.parrafo("", Interfaz.LIMA)
	caja.add_child(_prevision)
	_pronostico = Interfaz.parrafo("", Interfaz.CIAN)
	caja.add_child(_pronostico)
	_avisos = Interfaz.parrafo("", Interfaz.ALERTA)
	caja.add_child(_avisos)
	return panel


func _construir_bitacora() -> Control:
	var panel := Interfaz.panel()
	panel.custom_minimum_size.x = 320
	var caja := Interfaz.vbox(6)
	panel.add_child(caja)
	caja.add_child(Interfaz.etiqueta(tr("Bitácora"), Interfaz.AQUA, 18))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(scroll)
	_bitacora = Interfaz.parrafo("", Interfaz.CIAN, 14)
	_bitacora.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_bitacora)
	return panel


func _agregar_interruptor(caja: Control, clave: String) -> void:
	var interruptor := CheckButton.new()
	interruptor.add_theme_font_size_override("font_size", 16)
	# Sin foco, para que Enter termine el turno en vez de cambiar el último interruptor tocado.
	interruptor.focus_mode = Control.FOCUS_NONE
	interruptor.toggled.connect(_on_interruptor.bind(clave))
	caja.add_child(interruptor)
	_interruptores[clave] = interruptor


# --- Actualización ----------------------------------------------------------

func _actualizar() -> void:
	var ops := GameState.ops
	var mision := GameState.mision
	var energia := GameState.energia_turno()
	var condicion := GameState.condicion_turno()

	_turno.text = (tr("Tramo %d / %d") if GameState.tiene_viaje() else tr("Turno %d / %d")) % [mini(ops["turno"], ops["turnos"]), ops["turnos"]]
	_condicion.text = "" if condicion.is_empty() else "%s: %s" % [condicion["nombre"], condicion["descripcion"]]
	var objetivo: float = mision["objetivo_ciencia"]
	_ciencia.text = tr("Ciencia entregada: %d / %d") % [roundi(ops["ciencia"]), roundi(objetivo)]
	_barra_ciencia.value = minf(ops["ciencia"] / objetivo, 1.0)

	var base := GameState.get_nave_base()
	_pintar_estado("salud", tr("Salud: %d%%") % roundi(ops["salud"]), ops["salud"] / 100.0, ops["salud"] < 40.0)
	_pintar_estado("bateria", tr("Batería: %d / %d") % [roundi(ops["bateria"]), roundi(base["bateria"])], ops["bateria"] / base["bateria"], false)
	var memoria := GameState.datos_almacenados()
	_pintar_estado("memoria", tr("Memoria: %d / %d datos") % [roundi(memoria), roundi(base["almacenamiento"])], memoria / base["almacenamiento"], memoria >= base["almacenamiento"] * 0.9)
	if GameState.tiene_viaje():
		_texto_dv.text = (tr("Delta-v para frenar en la Luna: sobran %d m/s") if ops["dv_restante"] >= 0.0 else tr("¡Faltan %d m/s de delta-v para frenar en la Luna!")) % roundi(absf(ops["dv_restante"]))
		_texto_dv.add_theme_color_override("font_color", Interfaz.CIAN if ops["dv_restante"] >= 0.0 else Interfaz.ALERTA)
	else:
		_texto_dv.text = tr("Delta-v de reserva: %d m/s") % roundi(ops["dv_restante"])
	var rotas := []
	for id in ops["rotas"]:
		rotas.append(GameState.get_pieza(id)["nombre"])
	_texto_rotas.text = "" if rotas.is_empty() else tr("Fuera de servicio: %s") % ", ".join(rotas)

	_texto_energia.text = tr("Generación %d W + batería %d = %d W disponibles · usando %d W") % [
		roundi(energia["generacion"]), roundi(energia["bateria"]), roundi(energia["disponible"]), roundi(energia["consumo"])]
	_barra_energia.value = energia["consumo"] / energia["disponible"] if energia["disponible"] > 0.0 else 1.0
	Interfaz.color_barra(_barra_energia, Interfaz.ALERTA if energia["consumo"] > energia["disponible"] else Interfaz.AQUA)

	for clave in _interruptores:
		var interruptor: CheckButton = _interruptores[clave]
		interruptor.set_pressed_no_signal(_esta_encendido(clave))
		interruptor.text = _texto_interruptor(clave)
		interruptor.disabled = ops["terminada"] or _esta_roto(clave)

	_prevision.text = _texto_prevision()
	_pronostico.text = _texto_pronostico()
	_avisos.text = "\n".join(ops["avisos"])
	_actualizar_boton_turno()
	if ops["terminada"]:
		_paso.text = tr("La misión terminó. Mirá cómo te fue →")
	elif not ops["evento_actual"].is_empty():
		_paso.text = tr("Primero decidí qué hacer con el evento.")
	elif GameState.tiene_viaje():
		_paso.text = tr("Elegí qué encender: el tramo se cierra solo al avanzar el viaje →")
	else:
		_paso.text = tr("Paso siguiente: elegí qué encender y terminá el turno →")


## En el viaje a la Luna los turnos se cierran solos: el botón muestra cuánto falta.
func _actualizar_boton_turno() -> void:
	var ops := GameState.ops
	if ops["terminada"]:
		_boton_turno.text = tr("Ver informe  ⏎")
		_boton_turno.disabled = false
	elif GameState.tiene_viaje():
		_boton_turno.disabled = true
		if ops["evento_actual"].is_empty():
			_boton_turno.text = tr("Próximo tramo en %d s") % ceili(GameState.segundos_para_tramo())
		else:
			_boton_turno.text = tr("Viaje en espera")
	else:
		_boton_turno.text = tr("Terminar turno  ⏎")


func _pintar_estado(clave: String, texto: String, proporcion: float, alerta: bool) -> void:
	_estado[clave]["texto"].text = texto
	_estado[clave]["barra"].value = clampf(proporcion, 0.0, 1.0)
	Interfaz.color_barra(_estado[clave]["barra"], Interfaz.ALERTA if alerta else Interfaz.AQUA)


func _texto_interruptor(clave: String) -> String:
	var consumo := GameState.consumo_de(clave)
	match clave:
		"calefaccion":
			return tr("Calefacción  ·  −%d W  ·  sin ella la nave se daña") % roundi(consumo)
		"transmitir":
			var texto := tr("Transmitir a la Tierra  ·  −%d W  ·  envía hasta %d datos") % [roundi(consumo), roundi(GameState.capacidad_transmision())]
			return texto + (tr("  (antena dañada)") if _esta_roto(clave) else "")
	var pieza := GameState.get_pieza(clave)
	if _esta_roto(clave):
		return tr("%s  ·  fuera de servicio") % pieza["nombre"]
	return tr("%s  ·  −%d W  ·  +%d datos (×%.1f ciencia)") % [
		pieza["nombre"], roundi(consumo), roundi(GameState.datos_de_instrumento(clave)), pieza.get("ciencia", 1.0)]


func _texto_prevision() -> String:
	if GameState.ops["terminada"]:
		return tr("Operaciones terminadas.")
	var nuevos := 0.0
	for id in GameState.plan["instrumentos"]:
		if GameState.plan["instrumentos"][id]:
			nuevos += GameState.datos_de_instrumento(id)
	var memoria := GameState.datos_almacenados()
	var capacidad: float = GameState.get_nave_base()["almacenamiento"]
	var guardados := minf(memoria + nuevos, capacidad)
	var texto := tr("Este turno: +%d datos nuevos") % roundi(nuevos)
	if memoria + nuevos > capacidad:
		texto += tr(" (se perderán %d por memoria llena)") % roundi(memoria + nuevos - capacidad)
	if GameState.plan["transmitir"]:
		texto += tr(" · se enviarán %d") % roundi(minf(guardados, GameState.capacidad_transmision()))
	else:
		texto += tr(" · no se transmite nada")
	if GameState.ops["sin_ciencia_turnos"] > 0:
		texto += tr("\nLos instrumentos no captan nada este turno.")
	return texto


## Lo que viene: batería que queda y condición del próximo turno, para poder planificar.
func _texto_pronostico() -> String:
	var ops := GameState.ops
	if ops["terminada"]:
		return ""
	var texto := tr("Batería al terminar el turno: %d / %d") % [roundi(GameState.bateria_al_terminar()), roundi(GameState.get_nave_base()["bateria"])]
	var proxima := GameState.condicion_de_turno(ops["turno"] + 1)
	if ops["turno"] < ops["turnos"] and not proxima.is_empty():
		texto += tr("\nPróximo turno: %s. %s") % [proxima["nombre"], proxima["descripcion"]]
	return texto


func _esta_encendido(clave: String) -> bool:
	if clave == "calefaccion" or clave == "transmitir":
		return GameState.plan[clave]
	return GameState.plan["instrumentos"].get(clave, false)


func _esta_roto(clave: String) -> bool:
	if clave == "calefaccion":
		return false
	if clave == "transmitir":
		return false
	return GameState.esta_rota(clave)


# --- Eventos de la partida --------------------------------------------------

func _on_interruptor(activo: bool, clave: String) -> void:
	if not GameState.cambiar_plan(clave, activo):
		_interruptores[clave].set_pressed_no_signal(not activo)
		_avisos.text = tr("No alcanza la energía para encender eso. Apagá otra cosa primero.")


func _unhandled_key_input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla and tecla.pressed and not tecla.echo and tecla.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		if not _boton_turno.disabled:
			_on_boton_turno()
			get_viewport().set_input_as_handled()


func _on_boton_turno() -> void:
	if GameState.ops["terminada"]:
		GameState.ir_a("informe")
	else:
		GameState.terminar_turno()


func _on_turno_iniciado(_turno_nuevo: int) -> void:
	_actualizar()
	# Destello en el número de turno: que se note que el turno cambió.
	_turno.modulate = Interfaz.LIMA
	_turno.pivot_offset = _turno.size / 2
	_turno.scale = Vector2.ONE * 1.25
	var tween := create_tween().set_parallel()
	tween.tween_property(_turno, "modulate", Color.WHITE, 0.8)
	tween.tween_property(_turno, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	if not GameState.ops["evento_actual"].is_empty():
		_mostrar_evento(GameState.ops["evento_actual"])


func _on_turno_terminado(resumen: Dictionary) -> void:
	var cifras := [roundi(resumen["generados"]), roundi(resumen["transmitidos"]), roundi(resumen["ciencia"])]
	var linea: String
	if resumen["condicion"] != "":
		linea = tr("T%d (%s): +%d datos, enviados %d, ciencia +%d.") % ([resumen["turno"], resumen["condicion"]] + cifras)
	else:
		linea = tr("T%d: +%d datos, enviados %d, ciencia +%d.") % ([resumen["turno"]] + cifras)
	for mensaje in resumen["mensajes"]:
		linea += " " + mensaje
	_bitacora.text = linea + "\n\n" + _bitacora.text
	if GameState.ops["terminada"]:
		_actualizar()


## La misión puede terminar fuera de un turno (hambre o cordura de la tripulación).
func _on_operaciones_terminadas(_motivo: String) -> void:
	if is_instance_valid(_capa_evento):
		_capa_evento.queue_free()
	_boton_turno.disabled = false
	_actualizar()


func _mostrar_evento(evento: Dictionary) -> void:
	_boton_turno.disabled = true
	_capa_evento = ColorRect.new()
	(_capa_evento as ColorRect).color = Color(0, 0, 0, 0.6)
	_capa_evento.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_capa_evento)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capa_evento.add_child(centro)
	var panel := Interfaz.panel(Interfaz.PANEL, 24)
	panel.custom_minimum_size.x = 640
	centro.add_child(panel)
	var caja := Interfaz.vbox(14)
	panel.add_child(caja)

	caja.add_child(Interfaz.etiqueta(tr("¡%s!") % evento["titulo"], Interfaz.ALERTA, 28))
	caja.add_child(Interfaz.parrafo(evento["texto"], Interfaz.BLANCO, 18))
	for i in evento["opciones"].size():
		var opcion: Dictionary = evento["opciones"][i]
		var boton := Interfaz.boton(opcion["texto"], 18)
		boton.disabled = not GameState.opcion_disponible(opcion)
		if boton.disabled:
			boton.text += tr("  (no alcanza el delta-v)")
		boton.pressed.connect(_on_opcion.bind(i, caja))
		caja.add_child(boton)


func _on_opcion(indice: int, caja: VBoxContainer) -> void:
	var resultado := GameState.resolver_evento(indice)
	_bitacora.text = tr("Evento: %s\n\n%s") % [resultado, _bitacora.text]
	for hijo in caja.get_children():
		if hijo is Button:
			hijo.queue_free()
	caja.add_child(Interfaz.parrafo(resultado, Interfaz.LIMA, 18))
	var continuar := Interfaz.boton(tr("Continuar"), 18)
	continuar.pressed.connect(func() -> void:
		_capa_evento.queue_free()
		_boton_turno.disabled = false
		_actualizar())
	caja.add_child(continuar)


func _preparar_partida_de_prueba() -> void:
	GameState.reiniciar()
	GameState.elegir_mision("luna")
	for id in ["cohete_mediano", "panel_grande", "antena_alta", "motor_quimico", "camara", "espectrometro"]:
		GameState.elegir_pieza(id)
	GameState.lanzamiento = {"exito": true, "motivo": ""}
	GameState.iniciar_operaciones()
