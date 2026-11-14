extends SceneTree
## Prueba de GameState sin abrir el editor. Correr desde la carpeta del proyecto:
##   godot --headless --path . -s res://tests/test_game_state.gd
## Termina con código 0 si todo pasa.

var _fallos := 0


func _initialize() -> void:
	var gs: Node = load("res://scripts/autoload/game_state.gd").new()
	gs.cargar_datos()

	_comprobar(gs.get_misiones().size() == 3, "hay 3 misiones")
	for pieza in gs.get_piezas():
		_comprobar(not gs.get_categoria(pieza["categoria"]).is_empty(), "categoría válida para " + pieza["id"])

	# Fórmulas
	_cerca(gs.calcular_delta_v(300, 2000, 1000), 300 * 9.81 * log(2.0), "delta-v de Tsiolkovsky")
	_cerca(gs.calcular_generacion({"potencia": 1000, "tipo": "solar"}, 1.52), 432.8, "panel solar en Marte")
	_cerca(gs.calcular_generacion({"potencia": 350, "tipo": "rtg"}, 1.52), 350, "RTG no depende de la distancia")

	# Elección única reemplaza; múltiple suma y alterna
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

	# Tierra con una nave sensata: todo en verde
	_armar(gs, "tierra", ["cohete_chico", "panel_chico", "antena_media", "motor_quimico", "camara", "espectrometro"])
	_comprobar(gs.puede_lanzar(), "tierra: se puede lanzar")
	for id in gs.medidores:
		_comprobar(gs.medidores[id]["ok"], "tierra: medidor %s en verde" % id)
	_cerca(gs.medidores["costo"]["valor"], 225, "tierra: costo total")
	_cerca(gs.medidores["masa"]["valor"], 1035, "tierra: masa con combustible")

	# Agregar el radar se pasa del presupuesto
	gs.elegir_pieza("radar")
	_comprobar(not gs.medidores["costo"]["ok"], "tierra + radar: se pasa del presupuesto")

	# Luna con cohete chico: no alcanza la capacidad
	_armar(gs, "luna", ["cohete_chico", "panel_grande", "antena_alta", "motor_quimico", "camara", "espectrometro"])
	_comprobar(not gs.medidores["masa"]["ok"], "luna + cohete chico: excede la capacidad")
	gs.elegir_pieza("cohete_mediano")
	for id in gs.medidores:
		_comprobar(gs.medidores[id]["ok"], "luna + cohete mediano: medidor %s en verde" % id)

	# Luna con motor iónico entra en el cohete chico
	_armar(gs, "luna", ["cohete_chico", "panel_grande", "antena_alta", "motor_ionico", "camara", "espectrometro"])
	for id in gs.medidores:
		_comprobar(gs.medidores[id]["ok"], "luna iónica en cohete chico: medidor %s en verde" % id)

	# Marte: el radar no da con paneles; el químico no llega al delta-v
	_armar(gs, "marte", ["cohete_pesado", "panel_grande", "antena_alta", "motor_eficiente", "espectrometro", "radar"])
	_comprobar(not gs.medidores["energia"]["ok"], "marte + radar: falta energía")
	gs.elegir_pieza("motor_quimico")
	_comprobar(not gs.medidores["delta_v"]["ok"], "marte + químico: falta delta-v")

	# La redundancia sube la fiabilidad de la nave
	var antes: float = gs.detalle["fiabilidad_nave"]
	gs.elegir_pieza("redundancia")
	_comprobar(gs.detalle["fiabilidad_nave"] > antes, "la redundancia sube la fiabilidad")

	gs.free()
	print("\n%s" % ("TODO OK" if _fallos == 0 else "%d FALLOS" % _fallos))
	quit(_fallos)


func _armar(gs: Node, mision: String, piezas: Array) -> void:
	gs.reiniciar()
	gs.elegir_mision(mision)
	for id in piezas:
		gs.elegir_pieza(id)
	var resumen := []
	for id in gs.medidores:
		var m: Dictionary = gs.medidores[id]
		resumen.append("%s %d/%d%s" % [id, roundi(m["valor"]), roundi(m["limite"]), "" if m["ok"] else "!"])
	print("  [%s] %s" % [mision, "  ".join(resumen)])


func _comprobar(condicion: bool, descripcion: String) -> void:
	if not condicion:
		_fallos += 1
		print("FALLA: ", descripcion)


func _cerca(valor: float, esperado: float, descripcion: String) -> void:
	_comprobar(absf(valor - esperado) < 0.5, "%s (dio %.2f, se esperaba %.2f)" % [descripcion, valor, esperado])
