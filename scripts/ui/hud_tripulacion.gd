class_name HudTripulacion
extends CanvasLayer
## Barras de hambre y cordura, raciones y viaje a la Luna. Lo usan todos los
## ambientes de la nave (cabina, habitáculo, esclusa, exterior) para que la
## tripulación se vea siempre: el reloj de GameState corre en cualquier zona.
##
## También maneja lo que pasa fuera de la cabina:
## - F come una ración (si permitir_comer).
## - Mientras se duerme, tapa la pantalla y cualquier tecla despierta.
## - Si hay un evento sin decidir, avisa que hay que volver a la cabina.
## - Si la misión termina fuera de la cabina, lleva a la cabina con el informe.
##
## Uso:
##   var hud := HudTripulacion.new()
##   hud.ubicacion = HudTripulacion.TIRA_ABAJO
##   add_child(hud)

const PANEL := "panel"  ## Arriba a la derecha, con títulos.
const TIRA_ARRIBA := "tira_arriba"  ## Tira compacta arriba al centro.
const TIRA_ABAJO := "tira_abajo"  ## Tira compacta abajo al centro.
## Debajo de este valor las barras se pintan de alerta.
const UMBRAL := 25.0
const ESPERA_INFORME := 4.0
const MENSAJES_DESPERTAR := {
	"descansado": "La tripulación se despertó descansada.",
	"hambre": "El hambre despertó a la tripulación. Comé algo.",
	"evento": "¡Alarma! Algo pasa en la nave: volvé a la cabina para decidir.",
}

## PANEL, TIRA_ARRIBA o TIRA_ABAJO. Se puede cambiar en cualquier momento.
var ubicacion := PANEL:
	set(valor):
		ubicacion = valor
		if is_inside_tree():
			_ubicar()
var permitir_comer := true
## En la cabina los eventos ya se ven en las consolas y el informe está a mano.
var en_cabina := false

var _panel: PanelContainer
var _caja: BoxContainer
var _titulo: Label
var _barras: Dictionary = {}  # hambre, cordura -> {texto, barra}
var _raciones: Label
var _grupo_viaje: VBoxContainer
var _titulo_viaje: Label
var _barra_viaje: ProgressBar
var _texto_viaje: Label
var _alerta: Label
var _aviso: Label
var _sueno: ColorRect
var _texto_sueno: Label
var _tween_aviso: Tween


func _ready() -> void:
	layer = 6
	_panel = Interfaz.panel(Color(Interfaz.PANEL, 0.85), 10)
	add_child(_panel)
	_caja = BoxContainer.new()
	_caja.add_theme_constant_override("separation", 6)
	_panel.add_child(_caja)
	_titulo = Interfaz.etiqueta("Tripulación", Interfaz.AQUA, 16)
	_caja.add_child(_titulo)
	for clave in ["hambre", "cordura"]:
		var grupo := Interfaz.vbox(2)
		grupo.custom_minimum_size.x = 120
		var texto := Interfaz.etiqueta("", Interfaz.BLANCO, 14)
		var barra := Interfaz.barra(Interfaz.LIMA)
		barra.custom_minimum_size.y = 10
		grupo.add_child(texto)
		grupo.add_child(barra)
		_caja.add_child(grupo)
		_barras[clave] = {"texto": texto, "barra": barra}
	_raciones = Interfaz.etiqueta("", Interfaz.CIAN, 14)
	_caja.add_child(_raciones)
	_grupo_viaje = Interfaz.vbox(2)
	_titulo_viaje = Interfaz.etiqueta("Viaje a la Luna", Interfaz.AQUA, 14)
	_grupo_viaje.add_child(_titulo_viaje)
	_barra_viaje = Interfaz.barra(Interfaz.CIAN)
	_barra_viaje.custom_minimum_size.y = 10
	_grupo_viaje.add_child(_barra_viaje)
	_texto_viaje = Interfaz.etiqueta("", Interfaz.BLANCO, 13)
	_grupo_viaje.add_child(_texto_viaje)
	_caja.add_child(_grupo_viaje)

	_alerta = Interfaz.etiqueta("", Interfaz.ALERTA, 18)
	_alerta.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_alerta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_alerta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_alerta)

	_aviso = Interfaz.parrafo("", Interfaz.LIMA, 18)
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_aviso.custom_minimum_size.x = 640
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_aviso)

	# Al dormir la pantalla se oscurece; las barras quedan encima para ver cómo suben.
	_sueno = ColorRect.new()
	_sueno.color = Color(0.0, 0.0, 0.02, 0.88)
	_sueno.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sueno.visible = false
	add_child(_sueno)
	move_child(_sueno, 0)
	_texto_sueno = Interfaz.parrafo("", Interfaz.CIAN, 22)
	_texto_sueno.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_texto_sueno.custom_minimum_size.x = 640
	_texto_sueno.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_texto_sueno.grow_vertical = Control.GROW_DIRECTION_BOTH
	_texto_sueno.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sueno.add_child(_texto_sueno)

	for control in find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	GameState.tripulacion_cambiada.connect(func(_h: float, _c: float) -> void: actualizar())
	GameState.viaje_avanzado.connect(func(_p: float) -> void: actualizar())
	GameState.turno_iniciado.connect(func(_t: int) -> void: actualizar())
	GameState.plan_cambiado.connect(actualizar)
	GameState.sueno_cambiado.connect(_on_sueno_cambiado)
	GameState.operaciones_terminadas.connect(_on_operaciones_terminadas)
	_ubicar()
	_on_sueno_cambiado(GameState.durmiendo(), "")


func _input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if not tecla or not tecla.pressed or tecla.echo:
		return
	if GameState.durmiendo():
		# Cualquier tecla despierta (Esc también, para no soltar el mouse sin querer).
		GameState.despertar("jugador")
		get_viewport().set_input_as_handled()
	elif tecla.physical_keycode == KEY_F and permitir_comer and GameState.reloj_corriendo():
		comer()
		get_viewport().set_input_as_handled()


func comer() -> void:
	if GameState.comer_racion():
		avisar("Comiste una ración (quedan %d)." % GameState.ops["raciones"])
	elif GameState.ops["raciones"] <= 0:
		avisar("No quedan raciones en la despensa.")
	else:
		avisar("La tripulación no tiene hambre todavía.")


## Mensaje corto abajo al centro, que se desvanece solo.
func avisar(texto: String) -> void:
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	if _tween_aviso:
		_tween_aviso.kill()
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(4.0)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, 1.0)


func actualizar() -> void:
	# Al terminar la misión las barras se ocultan: los valores finales están en el informe.
	var visible_ahora: bool = GameState.en_orbita() and not GameState.ops["terminada"]
	_panel.visible = visible_ahora
	if not visible_ahora:
		_alerta.text = ""
		return
	var ops := GameState.ops
	for clave in _barras:
		var valor: float = ops[clave]
		_barras[clave]["texto"].text = "%s: %d%%" % [clave.capitalize(), roundi(valor)]
		_barras[clave]["barra"].value = valor / 100.0
		Interfaz.color_barra(_barras[clave]["barra"], Interfaz.ALERTA if valor < UMBRAL else Interfaz.LIMA)
	_raciones.text = "Raciones: %d" % ops["raciones"] + ("  ·  [F] comer" if permitir_comer else "")
	_grupo_viaje.visible = GameState.tiene_viaje()
	if _grupo_viaje.visible:
		var viaje: Dictionary = ops["viaje"]
		_barra_viaje.value = GameState.progreso_viaje()
		var minutos := GameState.minutos_para_llegar()
		var llegada := "%d:%02d" % [floori(minutos), floori(fmod(minutos * 60.0, 60.0))]
		if ubicacion != PANEL:
			_texto_viaje.text = "Luna %d%% · llegada en %s" % [floori(GameState.progreso_viaje() * 100), llegada]
		else:
			_texto_viaje.text = "%s / %s km · %s m/s\nLlegada en %s" % [
				GameState._miles(viaje["recorrido_km"]), GameState._miles(viaje["distancia_km"]), GameState._miles(viaje["velocidad"]), llegada]
	var evento: Dictionary = ops["evento_actual"]
	if not en_cabina and not evento.is_empty():
		_alerta.text = "⚠ %s · volvé a la cabina para decidir%s" % [evento["titulo"], " (el viaje espera)" if GameState.tiene_viaje() else ""]
	else:
		_alerta.text = ""
	if GameState.durmiendo():
		var aceleracion: float = GameState.get_tripulacion().get("dormir", {}).get("aceleracion", 1.0)
		var veces := str(roundi(aceleracion)) if is_equal_approx(aceleracion, roundf(aceleracion)) else str(aceleracion)
		_texto_sueno.text = "Zzz… la tripulación duerme.\nEl viaje avanza ×%s · la cordura se recupera y el hambre aprieta.\n\nCualquier tecla: despertar" % veces


func _ubicar() -> void:
	var compacto := ubicacion != PANEL
	_caja.vertical = not compacto
	_titulo.visible = not compacto
	_titulo_viaje.visible = not compacto
	_grupo_viaje.custom_minimum_size.x = 150.0 if compacto else 200.0
	_panel.custom_minimum_size.x = 0.0 if compacto else 240.0
	if GameState.en_orbita():
		actualizar()
	_panel.reset_size()
	match ubicacion:
		TIRA_ARRIBA:
			_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
			_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
			_panel.position.y = 6
		TIRA_ABAJO:
			_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
			_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
			_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
			_panel.position.y -= 56
		_:
			_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
			_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			_panel.position += Vector2(-16, 12)
	# La alerta y los avisos van por encima de la tira de abajo (o del borde, si no hay tira).
	var base := -120.0 if ubicacion == TIRA_ABAJO else -64.0
	_alerta.offset_top = base - 24.0
	_alerta.offset_bottom = base
	_aviso.offset_bottom = base - 30.0


func _on_sueno_cambiado(dormido: bool, motivo: String) -> void:
	_sueno.visible = dormido
	if dormido:
		_aviso.text = ""
	actualizar()
	if not dormido and MENSAJES_DESPERTAR.has(motivo):
		avisar(MENSAJES_DESPERTAR[motivo])


func _on_operaciones_terminadas(_motivo: String) -> void:
	actualizar()
	if en_cabina:
		return
	# Fuera de la cabina no hay consola para el informe: se vuelve a la cabina sola.
	avisar("La misión terminó. Volviendo a la cabina para el informe…")
	await get_tree().create_timer(ESPERA_INFORME).timeout
	if is_inside_tree():
		GameState.pantalla_pendiente = "informe"
		get_tree().change_scene_to_file(GameState.ESCENA_CABINA)
