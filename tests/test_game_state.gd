extends SceneTree
## Prueba de GameState sin abrir el editor. Correr desde la carpeta del proyecto:
##   godot --headless --path . -s res://tests/test_game_state.gd
## Termina con código 0 si todo pasa. Al final imprime una simulación de balance.

var _fallos := 0


func _initialize() -> void:
	var gs: Node = load("res://scripts/autoload/game_state.gd").new()
	gs.cargar_datos()
	gs.rng.seed = 1234

	_probar_datos(gs)
	_probar_formulas(gs)
	_probar_seleccion(gs)
	_probar_medidores(gs)
	_probar_lanzamiento(gs)
	_probar_operaciones(gs)
	_probar_tripulacion(gs)
	_probar_viaje(gs)
	_probar_dormir(gs)
	_simular_balance(gs)

	gs.free()
	print("\n%s" % ("TODO OK" if _fallos == 0 else "%d FALLOS" % _fallos))
	quit(_fallos)


func _probar_datos(gs: Node) -> void:
	_comprobar(gs.get_misiones().size() == 1 and gs.get_misiones()[0]["id"] == "luna", "la única misión es la Luna")
	for pieza in gs.get_piezas():
		_comprobar(not gs.get_categoria(pieza["categoria"]).is_empty(), "categoría válida para " + pieza["id"])
	for clave in ["fallo_masa", "fallo_cohete", "fallo_delta_v", "ciencia", "transmision_baja"]:
		_comprobar(gs.datos["frases"].has(clave), "existe la frase " + clave)


func _probar_formulas(gs: Node) -> void:
	_cerca(gs.calcular_delta_v(300, 2000, 1000), 300 * 9.81 * log(2.0), "delta-v de Tsiolkovsky")
	_cerca(gs.calcular_generacion({"potencia": 1000, "tipo": "solar"}, 1.52), 432.8, "el panel solar rinde menos lejos del Sol")
	_cerca(gs.calcular_generacion({"potencia": 350, "tipo": "rtg"}, 1.52), 350, "RTG no depende de la distancia")


func _probar_seleccion(gs: Node) -> void:
	gs.reiniciar()
	gs.elegir_pieza("cohete_chico")
	gs.elegir_pieza("cohete_mediano")
	_comprobar(gs.seleccion == ["cohete_mediano"], "el cohete se reemplaza")
	gs.alternar_pieza("camara")
	gs.alternar_pieza("radar")
	_comprobar(gs.piezas_elegidas("instrumento").size() == 2, "se pueden llevar varios instrumentos")
	gs.alternar_pieza("radar")
	_comprobar(not gs.tiene_pieza("radar"), "alternar quita el instrumento")
	gs.reiniciar()
	_comprobar(not gs.puede_lanzar(), "no se lanza sin misión ni piezas")


func _probar_medidores(gs: Node) -> void:
	_armar(gs, "luna", ["cohete_chico", "panel_grande", "antena_alta", "motor_quimico", "despensa_mediana", "camara", "espectrometro"])
	_comprobar(not gs.medidores["masa"]["ok"], "luna + cohete chico: excede la capacidad")
	gs.elegir_pieza("cohete_mediano")
	_comprobar(gs.puede_lanzar(), "luna + cohete mediano: se puede lanzar")
	_todo_verde(gs, "luna + cohete mediano")
	_cerca(gs.medidores["costo"]["valor"], 340, "luna: costo total")
	_cerca(gs.medidores["masa"]["valor"], 1205, "luna: masa con combustible")
	gs.elegir_pieza("radar")
	_comprobar(not gs.medidores["costo"]["ok"], "luna + radar: se pasa del presupuesto")

	_armar(gs, "luna", ["cohete_chico", "panel_grande", "antena_alta", "motor_ionico", "despensa_mediana", "camara", "espectrometro"])
	_todo_verde(gs, "luna iónica en cohete chico")

	_armar(gs, "luna", ["cohete_pesado", "panel_chico", "antena_alta", "motor_quimico", "despensa_mediana", "espectrometro", "radar"])
	_comprobar(not gs.medidores["energia"]["ok"], "luna + panel chico + radar: falta energía")

	var antes: float = gs.detalle["fiabilidad_nave"]
	gs.elegir_pieza("redundancia")
	_comprobar(gs.detalle["fiabilidad_nave"] > antes, "la redundancia sube la fiabilidad")


func _probar_lanzamiento(gs: Node) -> void:
	_armar(gs, "luna", ["cohete_chico", "panel_grande", "antena_alta", "motor_quimico", "despensa_mediana", "camara"])
	_comprobar(gs.lanzar()["motivo"] == "masa", "lanzamiento falla por masa")
	_comprobar(gs.texto_fallo_lanzamiento().contains("kg"), "el fallo por masa se explica con números")
	_comprobar(gs.calcular_informe()["puntaje"] == 0, "sin lanzamiento no hay puntaje")

	var motivo := ""
	# En la Luna el delta-v se juzga al llegar, no al despegar.
	_armar(gs, "luna", ["cohete_pesado", "panel_grande", "antena_alta", "motor_quimico", "despensa_mediana", "camara"], false)
	gs.mision = gs.mision.duplicate(true)
	gs.mision["delta_v"] = 9000.0  # una Luna imposible de frenar
	gs.recalcular()
	_comprobar(not gs.medidores["delta_v"]["ok"], "luna exigente: falta delta-v")
	gs.rng.seed = 99
	motivo = gs.lanzar()["motivo"]
	_comprobar(motivo != "delta_v", "luna: el delta-v no se juzga al despegar (motivo %s)" % motivo)
	gs.lanzamiento = {"exito": true, "motivo": ""}
	gs.iniciar_operaciones()
	gs.ops["eventos"] = {}
	gs.ops["evento_actual"] = {}
	while not gs.ops["terminada"]:
		gs.terminar_turno()
	_comprobar(gs.ops["motivo_fin"] == "frenado", "luna sin delta-v: pasa de largo al llegar (motivo %s)" % gs.ops["motivo_fin"])
	var informe: Dictionary = gs.calcular_informe()
	_comprobar(informe["nota"] == "No pudo frenar" and not informe["exito"], "el informe explica que no pudo frenar")
	_comprobar(informe["frases"].any(func(f): return f.contains("frenar")), "frase de frenado")


func _probar_operaciones(gs: Node) -> void:
	_armar(gs, "luna", ["cohete_mediano", "panel_grande", "antena_alta", "motor_quimico", "despensa_mediana", "camara", "espectrometro"])
	gs.lanzamiento = {"exito": true, "motivo": ""}
	gs.iniciar_operaciones()
	_comprobar(gs.ops["turno"] == 1 and gs.ops["eventos"].size() == 3, "operaciones arrancan con 3 eventos")

	# Con un evento pendiente no se puede terminar el turno.
	while gs.ops["evento_actual"].is_empty():
		gs.terminar_turno()
	_comprobar(gs.terminar_turno().is_empty(), "no se termina el turno con un evento sin decidir")
	_comprobar(gs.resolver_evento(gs.ops["evento_actual"]["opciones"].size() - 1) != "", "el evento se resuelve")

	# Encender algo que no entra en la energía se rechaza.
	gs.cambiar_plan("camara", false)
	var bateria_original: float = gs.ops["bateria"]
	gs.ops["bateria"] = -10000.0
	_comprobar(not gs.cambiar_plan("camara", true), "no se enciende un instrumento sin energía")
	gs.ops["bateria"] = bateria_original

	while not gs.ops["terminada"]:
		if not gs.ops["evento_actual"].is_empty():
			gs.resolver_evento(0 if gs.opcion_disponible(gs.ops["evento_actual"]["opciones"][0]) else 1)
		gs.terminar_turno()
	var informe: Dictionary = gs.calcular_informe()
	_comprobar(informe["frases"].size() >= 2, "el informe tiene frases")
	_comprobar(informe["ciencia"] > 0.0, "la luna entrega algo de ciencia")
	for frase in informe["frases"]:
		_comprobar(not frase.contains("{"), "frase sin marcadores sueltos: " + frase)


func _probar_tripulacion(gs: Node) -> void:
	var trip: Dictionary = gs.get_tripulacion()
	_armar(gs, "luna", ["cohete_mediano", "panel_grande", "antena_alta", "motor_quimico", "despensa_mediana", "camara"], false)
	gs.lanzamiento = {"exito": true, "motivo": ""}
	gs.iniciar_operaciones()
	_comprobar(gs.reloj_corriendo(), "el reloj de la tripulación corre en órbita")
	_cerca(gs.ops["hambre"], trip["hambre_inicial"], "hambre inicial")
	_comprobar(not gs.comer_racion(), "no se come con el hambre llena")

	gs.avanzar_tiempo(60.0)
	_cerca(gs.ops["hambre"], trip["hambre_inicial"] - trip["hambre_por_minuto"], "el hambre baja por minuto")
	_cerca(gs.ops["cordura"], trip["cordura_inicial"] - trip["cordura_por_minuto"], "la cordura baja por minuto")

	var raciones: int = gs.ops["raciones"]
	gs.cambiar_tripulacion(-50.0, 0.0)
	var antes: float = gs.ops["hambre"]
	_comprobar(gs.comer_racion(), "se come una ración")
	_comprobar(gs.ops["raciones"] == raciones - 1, "comer gasta una ración")
	_cerca(gs.ops["hambre"], antes + trip["hambre_por_racion"], "la ración recupera hambre")
	gs.ops["raciones"] = 0
	gs.cambiar_tripulacion(-20.0, 0.0)
	_comprobar(not gs.comer_racion(), "sin raciones no se come")

	var cordura: float = gs.ops["cordura"]
	gs._aplicar_efectos({"cordura": -10}, "")
	_cerca(gs.ops["cordura"], cordura - 10.0, "un evento baja la cordura")

	gs.cambiar_tripulacion(-200.0, 0.0)
	_comprobar(gs.ops["terminada"] and gs.ops["motivo_fin"] == "hambre", "el hambre en 0 termina la misión")
	_comprobar(not gs.reloj_corriendo(), "el reloj se detiene al terminar")
	var informe: Dictionary = gs.calcular_informe()
	_comprobar(informe["nota"] == "Tripulación perdida", "el informe dice tripulación perdida")
	_comprobar(not informe["exito"], "morir de hambre no es un éxito")
	for frase in informe["frases"]:
		_comprobar(not frase.contains("{"), "frase sin marcadores sueltos: " + frase)

	gs.iniciar_operaciones()
	gs.cambiar_tripulacion(0.0, -200.0)
	_comprobar(gs.ops["motivo_fin"] == "cordura", "la cordura en 0 termina la misión")


func _probar_viaje(gs: Node) -> void:
	var viaje: Dictionary = gs.get_mision("luna")["viaje"]
	var base: float = viaje["velocidad_base"]
	_cerca(gs.calcular_velocidad_viaje(viaje, 0.0, 1.0), base, "sin delta-v sobrante se viaja a la velocidad base")
	_comprobar(gs.calcular_velocidad_viaje(viaje, 400.0, 1.0) > base, "el delta-v sobrante acelera el viaje")
	_cerca(gs.calcular_velocidad_viaje(viaje, 100000.0, 1.0), viaje["velocidad_maxima"], "la velocidad tiene tope")
	_comprobar(gs.calcular_velocidad_viaje(viaje, 400.0, 0.85) < gs.calcular_velocidad_viaje(viaje, 400.0, 1.0), "el iónico llega más lento")

	# Una misión sin bloque "viaje" se juega por turnos, sin barra de viaje.
	_armar(gs, "luna", ["cohete_mediano", "panel_grande", "antena_alta", "motor_quimico", "despensa_mediana", "camara"], false)
	gs.mision = gs.mision.duplicate(true)
	gs.mision.erase("viaje")
	gs.lanzamiento = {"exito": true, "motivo": ""}
	gs.iniciar_operaciones()
	_comprobar(not gs.tiene_viaje(), "sin bloque viaje no hay viaje")

	var piezas_luna := ["cohete_mediano", "panel_grande", "antena_alta", "motor_quimico", "despensa_mediana", "camara", "espectrometro"]
	_armar(gs, "luna", piezas_luna, false)
	gs.lanzamiento = {"exito": true, "motivo": ""}
	gs.iniciar_operaciones()
	_comprobar(gs.tiene_viaje(), "la misión Luna tiene viaje")
	var minutos: float = gs.minutos_para_llegar()
	print("  [viaje] %.0f m/s, %.1f h de misión, %.1f min reales" % [gs.ops["viaje"]["velocidad"], gs.ops["viaje"]["horas_totales"], minutos])
	_comprobar(minutos >= 12.0 and minutos <= 15.0, "el viaje dura entre 12 y 15 minutos (dio %.1f)" % minutos)

	# Avanza solo: cierra tramos, espera los eventos y llega.
	gs.ops["hambre"] = 100.0
	var pasos := 0
	var evento_frena := false
	while not gs.ops["terminada"] and pasos < 5000:
		pasos += 1
		gs.ops["raciones"] = 9  # que la tripulación no se muera en esta prueba
		if gs.ops["hambre"] < 60.0:
			gs.comer_racion()
		gs.cambiar_tripulacion(0.0, 100.0)
		if not gs.ops["evento_actual"].is_empty():
			var turno: int = gs.ops["turno"]
			gs.avanzar_tiempo(60.0)
			evento_frena = evento_frena or gs.ops["turno"] == turno
			gs.resolver_evento(gs.ops["evento_actual"]["opciones"].size() - 1)
		gs.avanzar_tiempo(1.0)
	_comprobar(evento_frena, "un evento sin decidir frena el cierre del tramo")
	_comprobar(gs.ops["motivo_fin"] == "llegada", "el viaje termina al llegar a la Luna (motivo %s)" % gs.ops["motivo_fin"])
	_cerca(gs.progreso_viaje(), 1.0, "al llegar el progreso es 100%")
	var informe: Dictionary = gs.calcular_informe()
	_comprobar(informe["exito"], "llegar a la Luna es un éxito")
	_comprobar(informe["frases"].any(func(f): return f.contains("llegó a la Luna")), "el informe cuenta la llegada")

	# Morir a mitad de camino.
	_armar(gs, "luna", piezas_luna, false)
	gs.lanzamiento = {"exito": true, "motivo": ""}
	gs.iniciar_operaciones()
	gs.ops["eventos"] = {}
	gs.avanzar_tiempo(120.0)
	gs.cambiar_tripulacion(-200.0, 0.0)
	_comprobar(gs.progreso_viaje() > 0.0 and gs.progreso_viaje() < 1.0, "la tripulación cayó a mitad de camino")
	informe = gs.calcular_informe()
	_comprobar(not informe["exito"], "no llegar no es un éxito")
	_comprobar(informe["frases"].any(func(f): return f.contains("de la Luna")), "el informe dice cuánto faltó")
	for frase in informe["frases"]:
		_comprobar(not frase.contains("{"), "frase sin marcadores sueltos: " + frase)


func _probar_dormir(gs: Node) -> void:
	var cfg: Dictionary = gs.get_tripulacion()["dormir"]
	_armar(gs, "luna", ["cohete_mediano", "panel_grande", "antena_alta", "motor_quimico", "despensa_mediana", "camara"], false)
	gs.lanzamiento = {"exito": true, "motivo": ""}
	gs.iniciar_operaciones()
	gs.ops["eventos"] = {}  # sin eventos que despierten
	gs.ops["evento_actual"] = {}
	_comprobar(gs.dormir() != "" and not gs.durmiendo(), "con la cordura alta no hay sueño")

	gs.ops["cordura"] = 80.0
	_comprobar(gs.dormir() == "" and gs.durmiendo(), "con la cordura baja se duerme")
	var hambre: float = gs.ops["hambre"]
	var cordura: float = gs.ops["cordura"]
	var horas: float = gs.ops["viaje"]["horas"]
	gs.avanzar_tiempo(60.0)
	_cerca(gs.ops["hambre"], hambre - cfg["hambre_por_minuto"], "durmiendo baja el hambre")
	_cerca(gs.ops["cordura"], cordura + cfg["cordura_por_minuto"], "durmiendo sube la cordura")
	var avance_dormido: float = gs.ops["viaje"]["horas"] - horas
	_cerca(avance_dormido, 60.0 * cfg["aceleracion"] / gs.ops["viaje"]["segundos_por_hora"], "durmiendo el viaje se acelera")

	_avanzar(gs, 600.0)
	_comprobar(not gs.durmiendo() and not gs.ops["terminada"], "se despierta solo al recuperar la cordura")
	_cerca(gs.ops["cordura"], 100.0, "despierta con la cordura llena")

	gs.ops["cordura"] = 80.0
	gs.dormir()
	gs.despertar()
	_comprobar(not gs.durmiendo(), "el jugador puede despertar")

	gs.cambiar_tripulacion(0.0, 0.0)
	gs.ops["hambre"] = cfg["hambre_minima"] + 1.0
	_comprobar(gs.dormir() == "", "se duerme con poca hambre de margen")
	_avanzar(gs, 10.0)
	_comprobar(not gs.durmiendo() and not gs.ops["terminada"], "el hambre despierta")
	_comprobar(gs.dormir() != "", "con mucha hambre no se duerme")

	gs.comer_racion()
	gs.comer_racion()
	gs.ops["eventos"] = {gs.ops["turno"] + 1: "tormenta_solar"}
	gs.ops["cordura"] = 60.0
	_comprobar(gs.dormir() == "", "se duerme antes del evento")
	_avanzar(gs, gs.segundos_para_tramo() / cfg["aceleracion"] + 1.0)
	_comprobar(not gs.ops["evento_actual"].is_empty() and not gs.durmiendo(), "un evento despierta a la tripulación")
	_comprobar(gs.dormir() != "", "con un evento pendiente no se duerme")
	_comprobar(gs.ops["segundos_dormidos"] > 0.0, "se cuenta el tiempo dormido")


## Avanza el reloj de a medio segundo, como en el juego; para si la tripulación se despierta.
func _avanzar(gs: Node, segundos: float) -> void:
	var paso := 0.5
	var t := 0.0
	while t < segundos and not gs.ops["terminada"] and gs.durmiendo():
		gs.avanzar_tiempo(minf(paso, segundos - t))
		t += paso


## Juega muchas partidas con naves razonables y una estrategia simple
## (todo encendido, primera opción posible en cada evento) para ver el balance.
func _simular_balance(gs: Node) -> void:
	var naves := {
		"luna": [
			["cohete_mediano", "panel_grande", "antena_alta", "motor_quimico", "despensa_mediana", "camara", "espectrometro"],
			["cohete_chico", "panel_grande", "antena_alta", "motor_ionico", "despensa_mediana", "camara", "espectrometro"],
			["cohete_mediano", "rtg", "antena_alta", "motor_quimico", "despensa_mediana", "espectrometro", "radar"],
		],
	}
	print("\nSimulación de balance (200 partidas por nave, estrategia simple):")
	for mision in naves:
		for piezas in naves[mision]:
			var puntajes := 0.0
			var ciencia := 0.0
			var exitos := 0
			for i in 200:
				_armar(gs, mision, piezas, false)
				gs.lanzar()
				if gs.lanzamiento["exito"]:
					gs.iniciar_operaciones()
					while not gs.ops["terminada"]:
						if not gs.ops["evento_actual"].is_empty():
							gs.resolver_evento(0 if gs.opcion_disponible(gs.ops["evento_actual"]["opciones"][0]) else 1)
						gs.terminar_turno()
				var informe: Dictionary = gs.calcular_informe()
				puntajes += informe["puntaje"]
				ciencia += informe["ciencia"] / informe["objetivo"]
				exitos += 1 if informe["exito"] else 0
			print("  %-7s puntaje %4d  ciencia %3d%%  éxito %3d%%  costo %3d/%d  %s" % [
				mision, roundi(puntajes / 200), roundi(ciencia / 200 * 100), roundi(exitos / 2.0),
				roundi(gs.medidores["costo"]["valor"]), roundi(gs.medidores["costo"]["limite"]), ", ".join(piezas.slice(5))])


func _armar(gs: Node, mision: String, piezas: Array, mostrar := true) -> void:
	gs.reiniciar()
	gs.elegir_mision(mision)
	for id in piezas:
		gs.elegir_pieza(id)
	if not mostrar:
		return
	var resumen := []
	for id in gs.medidores:
		var m: Dictionary = gs.medidores[id]
		resumen.append("%s %d/%d%s" % [id, roundi(m["valor"]), roundi(m["limite"]), "" if m["ok"] else "!"])
	print("  [%s] %s" % [mision, "  ".join(resumen)])


func _todo_verde(gs: Node, descripcion: String) -> void:
	for id in gs.medidores:
		_comprobar(gs.medidores[id]["ok"], "%s: medidor %s en verde" % [descripcion, id])


func _comprobar(condicion: bool, descripcion: String) -> void:
	if not condicion:
		_fallos += 1
		print("FALLA: ", descripcion)


func _cerca(valor: float, esperado: float, descripcion: String) -> void:
	_comprobar(absf(valor - esperado) < 0.5, "%s (dio %.2f, se esperaba %.2f)" % [descripcion, valor, esperado])
