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
	_simular_balance(gs)

	gs.free()
	print("\n%s" % ("TODO OK" if _fallos == 0 else "%d FALLOS" % _fallos))
	quit(_fallos)


func _probar_datos(gs: Node) -> void:
	_comprobar(gs.get_misiones().size() == 3, "hay 3 misiones")
	for pieza in gs.get_piezas():
		_comprobar(not gs.get_categoria(pieza["categoria"]).is_empty(), "categoría válida para " + pieza["id"])
	for clave in ["fallo_masa", "fallo_cohete", "fallo_delta_v", "ciencia", "transmision_baja"]:
		_comprobar(gs.datos["frases"].has(clave), "existe la frase " + clave)


func _probar_formulas(gs: Node) -> void:
	_cerca(gs.calcular_delta_v(300, 2000, 1000), 300 * 9.81 * log(2.0), "delta-v de Tsiolkovsky")
	_cerca(gs.calcular_generacion({"potencia": 1000, "tipo": "solar"}, 1.52), 432.8, "panel solar en Marte")
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
	_armar(gs, "tierra", ["cohete_chico", "panel_chico", "antena_media", "motor_quimico", "camara", "espectrometro"])
	_comprobar(gs.puede_lanzar(), "tierra: se puede lanzar")
	_todo_verde(gs, "tierra")
	_cerca(gs.medidores["costo"]["valor"], 225, "tierra: costo total")
	_cerca(gs.medidores["masa"]["valor"], 1035, "tierra: masa con combustible")
	gs.elegir_pieza("radar")
	_comprobar(not gs.medidores["costo"]["ok"], "tierra + radar: se pasa del presupuesto")

	_armar(gs, "luna", ["cohete_chico", "panel_grande", "antena_alta", "motor_quimico", "camara", "espectrometro"])
	_comprobar(not gs.medidores["masa"]["ok"], "luna + cohete chico: excede la capacidad")
	gs.elegir_pieza("cohete_mediano")
	_todo_verde(gs, "luna + cohete mediano")

	_armar(gs, "luna", ["cohete_chico", "panel_grande", "antena_alta", "motor_ionico", "camara", "espectrometro"])
	_todo_verde(gs, "luna iónica en cohete chico")

	_armar(gs, "marte", ["cohete_pesado", "panel_grande", "antena_alta", "motor_eficiente", "espectrometro", "radar"])
	_comprobar(not gs.medidores["energia"]["ok"], "marte + radar: falta energía")
	gs.elegir_pieza("motor_quimico")
	_comprobar(not gs.medidores["delta_v"]["ok"], "marte + químico: falta delta-v")

	var antes: float = gs.detalle["fiabilidad_nave"]
	gs.elegir_pieza("redundancia")
	_comprobar(gs.detalle["fiabilidad_nave"] > antes, "la redundancia sube la fiabilidad")


func _probar_lanzamiento(gs: Node) -> void:
	_armar(gs, "luna", ["cohete_chico", "panel_grande", "antena_alta", "motor_quimico", "camara"])
	_comprobar(gs.lanzar()["motivo"] == "masa", "lanzamiento falla por masa")
	_comprobar(gs.texto_fallo_lanzamiento().contains("kg"), "el fallo por masa se explica con números")
	_comprobar(gs.calcular_informe()["puntaje"] == 0, "sin lanzamiento no hay puntaje")

	_armar(gs, "marte", ["cohete_pesado", "panel_grande", "antena_alta", "motor_quimico", "espectrometro"])
	var motivo: String = gs.lanzar()["motivo"]
	_comprobar(motivo == "delta_v" or motivo == "cohete", "marte con químico no llega a órbita")


func _probar_operaciones(gs: Node) -> void:
	_armar(gs, "luna", ["cohete_mediano", "panel_grande", "antena_alta", "motor_quimico", "camara", "espectrometro"])
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


## Juega muchas partidas con naves razonables y una estrategia simple
## (todo encendido, primera opción posible en cada evento) para ver el balance.
func _simular_balance(gs: Node) -> void:
	var naves := {
		"tierra": [
			["cohete_chico", "panel_chico", "antena_media", "motor_quimico", "camara", "espectrometro"],
			["cohete_chico", "panel_grande", "antena_media", "motor_quimico", "camara", "espectrometro", "blindaje"],
		],
		"luna": [
			["cohete_mediano", "panel_grande", "antena_alta", "motor_quimico", "camara", "espectrometro"],
			["cohete_chico", "panel_grande", "antena_alta", "motor_ionico", "camara", "espectrometro"],
			["cohete_mediano", "rtg", "antena_alta", "motor_quimico", "espectrometro", "radar"],
		],
		"marte": [
			["cohete_pesado", "panel_grande", "antena_alta", "motor_eficiente", "espectrometro", "radar"],
			["cohete_pesado", "rtg", "antena_alta", "motor_eficiente", "espectrometro", "redundancia"],
			["cohete_pesado", "panel_grande", "antena_alta", "motor_eficiente", "camara", "espectrometro", "blindaje"],
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
				roundi(gs.medidores["costo"]["valor"]), roundi(gs.medidores["costo"]["limite"]), ", ".join(piezas.slice(4))])


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
