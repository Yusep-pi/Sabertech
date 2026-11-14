extends Control
## Fase 1: briefing. Elegir una de las misiones; cada una funciona como dificultad.


func _ready() -> void:
	var columna := Interfaz.vbox(16)
	Interfaz.preparar_pantalla(self).add_child(columna)

	var titulo := Interfaz.etiqueta("SABERTECH · Director de misión", Interfaz.AQUA, 34)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(titulo)
	var subtitulo := Interfaz.etiqueta("Elegí una misión. Después vas a diseñar la nave, lanzarla y operarla.", Interfaz.CIAN, 18)
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(subtitulo)

	var tarjetas := Interfaz.hbox(16)
	tarjetas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(tarjetas)
	for mision in GameState.get_misiones():
		tarjetas.add_child(_tarjeta(mision))


func _tarjeta(mision: Dictionary) -> Control:
	var panel := Interfaz.panel(Interfaz.PANEL, 16)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var caja := Interfaz.vbox(10)
	panel.add_child(caja)

	caja.add_child(Interfaz.etiqueta(mision["dificultad"].to_upper(), _color_dificultad(mision["dificultad"]), 16))
	caja.add_child(Interfaz.parrafo(mision["nombre"], Interfaz.BLANCO, 24))
	caja.add_child(Interfaz.parrafo(mision["descripcion"], Interfaz.CIAN))
	caja.add_child(HSeparator.new())

	var luz: float = 100.0 / pow(mision["distancia_ua"], 2)
	var senal: float = 100.0 / mision["factor_datos"]
	var datos := [
		["Presupuesto", "%d M$" % roundi(mision["presupuesto"])],
		["Delta-v necesario", "%d m/s" % roundi(mision["delta_v"])],
		["Luz solar", "%d%%" % roundi(luz)],
		["Señal de radio", "%d%%" % roundi(senal)],
		["Capacidad del cohete", "%d%% de la normal" % roundi(mision["factor_capacidad"] * 100)],
		["Ciencia objetivo", "%d puntos" % roundi(mision["objetivo_ciencia"])],
	]
	for fila in datos:
		var linea := Interfaz.hbox()
		var nombre := Interfaz.etiqueta(fila[0], Interfaz.CIAN)
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linea.add_child(nombre)
		linea.add_child(Interfaz.etiqueta(fila[1], Interfaz.BLANCO))
		caja.add_child(linea)

	var espacio := Control.new()
	espacio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(espacio)
	caja.add_child(Interfaz.parrafo("Objetivo: " + mision["objetivo"], Interfaz.LIMA))

	var elegir := Interfaz.boton("Elegir esta misión", 20)
	elegir.pressed.connect(_on_elegir.bind(mision["id"]))
	caja.add_child(elegir)
	return panel


func _on_elegir(id: String) -> void:
	GameState.elegir_mision(id)
	GameState.ir_a("diseno")


static func _color_dificultad(dificultad: String) -> Color:
	match dificultad:
		"Fácil":
			return Interfaz.LIMA
		"Media":
			return Interfaz.AQUA
	return Interfaz.ALERTA
