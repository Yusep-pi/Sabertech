extends Node
## Atajos para probar el juego (autoload "AtajosPrueba"). Solo existen al correr
## desde Godot (build de debug): en el juego exportado no hacen nada.
##   K (mantener): baja la cordura rápido para ver las alucinaciones (se frena en 1).
##   P: termina el viaje y la nave aluniza; lleva a la esclusa, lista para salir
##      a la Luna. Solo con la nave ya lanzada y el viaje en curso.

const CORDURA_POR_SEGUNDO := 15.0


func _process(delta: float) -> void:
	if not OS.is_debug_build() or not Input.is_physical_key_pressed(KEY_K):
		return
	if not GameState.reloj_corriendo() or GameState.ops["cordura"] <= 1.0:
		return
	GameState.cambiar_tripulacion(0.0, -minf(CORDURA_POR_SEGUNDO * delta, GameState.ops["cordura"] - 1.0))


func _unhandled_input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if not OS.is_debug_build() or not tecla or not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode == KEY_P:
		_alunizar()


## Salta al final: la nave llega a la Luna y el jugador aparece en la esclusa.
func _alunizar() -> void:
	if not GameState.reloj_corriendo() or not GameState.tiene_viaje():
		return
	var ops: Dictionary = GameState.ops
	var viaje: Dictionary = ops["viaje"]
	viaje["horas"] = viaje["horas_totales"]
	viaje["recorrido_km"] = viaje["distancia_km"]
	ops["evento_actual"] = {}
	GameState.despertar("fin")
	ops["terminada"] = true
	ops["motivo_fin"] = "llegada"
	GameState.viaje_avanzado.emit(1.0)
	GameState.operaciones_terminadas.emit("llegada")
	GameState.ir_a("esclusa")
