extends Control
## Fase 5: informe final. Puntaje y frases que explican por qué salió así.


func _ready() -> void:
	var informe := GameState.calcular_informe()
	var columna := Interfaz.vbox(14)
	Interfaz.preparar_pantalla(self).add_child(columna)

	var titulo := Interfaz.etiqueta("Informe de misión · " + GameState.mision.get("nombre", ""), Interfaz.AQUA, 22)
	columna.add_child(titulo)

	var cabecera := Interfaz.hbox(32)
	columna.add_child(cabecera)
	var nota := Interfaz.etiqueta(informe["nota"], Interfaz.LIMA if informe["exito"] else Interfaz.ALERTA, 44)
	nota.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(nota)
	cabecera.add_child(Interfaz.etiqueta("%d puntos" % informe["puntaje"], Interfaz.BLANCO, 44))

	var cuerpo := Interfaz.hbox(16)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(cuerpo)

	var panel_frases := Interfaz.panel(Interfaz.PANEL, 20)
	panel_frases.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuerpo.add_child(panel_frases)
	var frases := Interfaz.vbox(14)
	panel_frases.add_child(frases)
	frases.add_child(Interfaz.etiqueta("Qué pasó", Interfaz.AQUA, 20))
	for frase in informe["frases"]:
		frases.add_child(Interfaz.parrafo("•  " + frase, Interfaz.BLANCO, 18))

	cuerpo.add_child(_panel_numeros(informe))

	var botones := Interfaz.hbox(12)
	botones.alignment = BoxContainer.ALIGNMENT_END
	columna.add_child(botones)
	var redisenar := Interfaz.boton("Rediseñar la nave", 20)
	redisenar.pressed.connect(GameState.ir_a.bind("diseno"))
	botones.add_child(redisenar)
	var otra := Interfaz.boton("Elegir otra misión", 20)
	otra.pressed.connect(func() -> void:
		GameState.reiniciar()
		GameState.ir_a("briefing"))
	botones.add_child(otra)


func _panel_numeros(informe: Dictionary) -> Control:
	var panel := Interfaz.panel(Interfaz.PANEL, 20)
	panel.custom_minimum_size.x = 380
	var caja := Interfaz.vbox(8)
	panel.add_child(caja)
	caja.add_child(Interfaz.etiqueta("Números", Interfaz.AQUA, 20))

	var ops := GameState.ops
	var costo: float = GameState.medidores["costo"]["valor"]
	var filas := [
		["Ciencia", "%d / %d" % [roundi(informe["ciencia"]), roundi(informe["objetivo"])]],
		["Presupuesto usado", "%d / %d M$" % [roundi(costo), roundi(GameState.mision.get("presupuesto", 0.0))]],
		["Salud final", "%d%%" % roundi(informe["salud"])],
		["Hambre / cordura final", "%d%% / %d%%" % [roundi(informe.get("hambre", 0.0)), roundi(informe.get("cordura", 0.0))]],
	]
	if not ops.is_empty():
		filas.append(["Datos captados", "%d" % roundi(ops["datos_generados"])])
		filas.append(["Datos enviados", "%d" % roundi(ops["datos_transmitidos"])])
		filas.append(["Datos perdidos", "%d" % roundi(ops["datos_perdidos"])])
		filas.append(["Delta-v de reserva", "%d m/s" % roundi(ops["dv_restante"])])
		var viaje: Dictionary = ops.get("viaje", {})
		if not viaje.is_empty():
			var horas: float = viaje["horas_totales"] if ops["motivo_fin"] == "llegada" else viaje["horas"]
			var texto_viaje := "%s km en %d h" % [GameState._miles(viaje["recorrido_km"]), roundi(horas)]
			var dormido: float = ops.get("segundos_dormidos", 0.0)
			if dormido >= 30.0:
				texto_viaje += " · %d min durmiendo" % maxi(1, roundi(dormido / 60.0))
			filas.append(["Viaje a la Luna", texto_viaje])
	for fila in filas:
		var linea := Interfaz.hbox()
		var nombre := Interfaz.etiqueta(fila[0], Interfaz.CIAN, 17)
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linea.add_child(nombre)
		linea.add_child(Interfaz.etiqueta(fila[1], Interfaz.BLANCO, 17))
		caja.add_child(linea)

	caja.add_child(HSeparator.new())
	caja.add_child(Interfaz.etiqueta("A bordo", Interfaz.AQUA, 18))
	var nombres := []
	for pieza in GameState.piezas_elegidas():
		nombres.append(pieza["nombre"])
	caja.add_child(Interfaz.parrafo(", ".join(nombres), Interfaz.CIAN, 15))
	return panel
