class_name TableroPuntos
extends Node3D
## Tablero de la pared del habitáculo. En la pared, grande para que se lea con
## el filtro retro: el puntaje de la partida por rubro. Con E (el nodo se llama
## "consola_tablero", así el jugador lo puede usar) se abre crear_guia(): la
## explicación completa de cómo se suma y qué conviene hacer ahora.
## Armado con cajas y Label3D (sin modelo de Blender). El frente mira a +Z;
## mide ANCHO x ALTO y el centro está en el origen.
##
## Uso: var tablero := TableroPuntos.new(); tablero.position = ...; add_child(tablero)

const ANCHO := 2.0
const ALTO := 1.3
const REFRESCO := 0.5
const TAM_TEXTO := 0.0016  # metros por píxel de fuente

var _en_vivo: Label3D
var _reloj := 0.0


func _ready() -> void:
	var marco := StandardMaterial3D.new()
	marco.resource_name = "oscuro"  # Estilo le pone la textura retro
	marco.albedo_color = Color("#2C3A66")
	marco.metallic = 0.6
	marco.roughness = 0.3
	_caja(Vector3(0, 0, -0.03), Vector3(ANCHO + 0.1, ALTO + 0.1, 0.04), marco)

	var pantalla := StandardMaterial3D.new()
	pantalla.albedo_color = Color("#070B18")
	pantalla.emission_enabled = true
	pantalla.emission = Color("#0B1030")
	_caja(Vector3.ZERO, Vector3(ANCHO, ALTO, 0.02), pantalla)
	# Colisión: la mirada del jugador lo detecta para usarlo con E.
	var cuerpo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	forma.shape = BoxShape3D.new()
	forma.shape.size = Vector3(ANCHO + 0.1, ALTO + 0.1, 0.06)
	cuerpo.add_child(forma)
	add_child(cuerpo)

	# Franja de luz arriba, como las otras pantallas de la nave.
	var luz := StandardMaterial3D.new()
	luz.albedo_color = Interfaz.AQUA
	luz.emission_enabled = true
	luz.emission = Color(Interfaz.AQUA) * 0.8
	_caja(Vector3(0, ALTO / 2.0 + 0.07, -0.01), Vector3(ANCHO + 0.1, 0.03, 0.05), luz)

	var titulo := _texto("PUNTAJE", Interfaz.AQUA, 80)
	titulo.position = Vector3(0, ALTO / 2.0 - 0.13, 0.02)
	add_child(titulo)

	_en_vivo = _texto("", Interfaz.BLANCO, 56)
	_en_vivo.position = Vector3(0, -0.02, 0.02)
	_en_vivo.line_spacing = 4
	add_child(_en_vivo)

	var pie := _texto("[E] Cómo sumar más", Interfaz.LIMA, 52)
	pie.position = Vector3(0, -ALTO / 2.0 + 0.11, 0.02)
	add_child(pie)
	_actualizar()


func _process(delta: float) -> void:
	_reloj -= delta
	if _reloj <= 0.0:
		_reloj = REFRESCO
		_actualizar()


static func _lineas_guia() -> Array:
	var mision := GameState.get_mision("luna") if GameState.mision.is_empty() else GameState.mision
	var objetivo: float = mision.get("objetivo_ciencia", 450.0)
	var llegada: float = mision.get("viaje", {}).get("puntos_llegada", 0.0)
	var ciencia_max := GameState.PUNTOS_CIENCIA * GameState.TOPE_CIENCIA
	return [
		"◆ Ciencia: hasta %d. Cumplir el objetivo (%d) da %d; pasarlo sigue sumando hasta el %d%% (%d de ciencia)." % [
			roundi(ciencia_max), roundi(objetivo), roundi(GameState.PUNTOS_CIENCIA), roundi(GameState.TOPE_CIENCIA * 100), roundi(objetivo * GameState.TOPE_CIENCIA)],
		"   La ciencia solo cuenta cuando se TRANSMITE: no dejes la antena apagada. Más instrumentos dan más datos, si alcanza la energía.",
		"◆ Llegar a la Luna y frenar: +%d. Guardá delta-v para el final." % roundi(llegada),
		"◆ Salud de la nave: x%d (hasta %d). Calefacción prendida y blindaje." % [roundi(GameState.PUNTOS_POR_SALUD), roundi(GameState.PUNTOS_POR_SALUD * 100)],
		"◆ Presupuesto: cada 1%% ahorrado suma 1; cada 1%% de más RESTA %d." % roundi(GameState.MULTA_EXCESO / 100.0),
		"◆ Si el hambre o la cordura llegan a 0, la misión se pierde.",
		"◆ Dormir en la cama acelera el viaje, pero da hambre: llevá raciones suficientes.",
		"Notas: " + "  ·  ".join(GameState.NOTAS.slice(0, 3).map(func(n): return "%s %d+" % [_mayuscula(n[1].trim_prefix("Misión ")), n[0]])),
	]


func _actualizar() -> void:
	_en_vivo.text = "\n".join(lineas_en_vivo(true))


## Lo que lleva la partida, renglón por renglón. corto: para la pared.
static func lineas_en_vivo(corto: bool) -> Array:
	if GameState.mision.is_empty() or GameState.medidores.is_empty():
		return ["Todavía no hay nave.", "Diseñala en la cabina."]
	var puntos := GameState.desglose_puntaje()
	var presupuesto := "%+d" % roundi(puntos["presupuesto"])
	if not GameState.en_orbita():
		return ["En la plataforma", "Presupuesto %s" % presupuesto, "Despegá para sumar ciencia."]
	var ops := GameState.ops
	var objetivo: float = GameState.mision.get("objetivo_ciencia", 1.0)
	var por_llegar: float = GameState.mision.get("viaje", {}).get("puntos_llegada", 0.0)
	var llegada := "%d" % roundi(puntos["llegada"]) if ops["terminada"] else "0 (+%d al llegar)" % roundi(por_llegar)
	var lineas := [
		"Ciencia %d" % roundi(puntos["ciencia"]) + ("" if corto else "   (%d de %d)" % [roundi(ops["ciencia"]), roundi(objetivo)]),
		"Llegada " + llegada,
		"Salud %d · Presupuesto %s" % [roundi(puntos["salud"]), presupuesto],
		"TOTAL %d" % puntos["total"],
	]
	if not corto:
		lineas.append("")
		lineas.append("Ahora: " + _consejo(objetivo).replace("\n", " "))
	return lineas


## La guía completa para leer en pantalla (la abre el habitáculo con E).
static func crear_guia() -> Control:
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fondo := Interfaz.panel(Interfaz.PANEL, 24)
	fondo.custom_minimum_size.x = 980
	centro.add_child(fondo)
	var caja := Interfaz.vbox(12)
	fondo.add_child(caja)
	caja.add_child(Interfaz.etiqueta("Cómo sumar puntos", Interfaz.AQUA, 30))
	var columnas := Interfaz.hbox(28)
	caja.add_child(columnas)
	var guia := Interfaz.vbox(8)
	guia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guia.size_flags_stretch_ratio = 1.6
	columnas.add_child(guia)
	for linea in _lineas_guia():
		guia.add_child(Interfaz.parrafo(linea, Interfaz.BLANCO, 17))
	var vivo := Interfaz.vbox(8)
	vivo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columnas.add_child(vivo)
	vivo.add_child(Interfaz.etiqueta("Tu partida", Interfaz.LIMA, 22))
	for linea in lineas_en_vivo(false):
		vivo.add_child(Interfaz.parrafo(linea, Interfaz.CIAN if not linea.begins_with("TOTAL") else Interfaz.LIMA, 18 if not linea.begins_with("TOTAL") else 26))
	caja.add_child(Interfaz.etiqueta("E o Esc: volver", Interfaz.CIAN, 14))
	return centro


static func _mayuscula(texto: String) -> String:
	return texto.left(1).to_upper() + texto.substr(1)


## Lo que más puntos daría ahora.
static func _consejo(objetivo: float) -> String:
	var ops := GameState.ops
	if ops["terminada"]:
		return "El informe está en la cabina."
	if not GameState.plan.get("transmitir", false):
		return "¡Prendé la transmisión!"
	if ops["dv_restante"] < 0.0:
		return "¡Sin delta-v para frenar!"
	if ops["ciencia"] < objetivo * GameState.TOPE_CIENCIA:
		return "Faltan %d de ciencia\npara el máximo." % roundi(objetivo * GameState.TOPE_CIENCIA - ops["ciencia"])
	return "Ciencia al máximo:\ncuidá la salud y llegá."


func _texto(texto: String, color: Color, tamano: int) -> Label3D:
	var etiqueta := Label3D.new()
	etiqueta.text = texto
	etiqueta.font_size = tamano
	etiqueta.pixel_size = TAM_TEXTO
	etiqueta.modulate = color
	etiqueta.outline_size = 0
	etiqueta.shaded = false
	return etiqueta


func _caja(posicion: Vector3, tamano: Vector3, material: Material) -> void:
	var malla := BoxMesh.new()
	malla.size = tamano
	malla.material = material  # en la malla, no override: así Estilo ve el nombre
	var instancia := MeshInstance3D.new()
	instancia.mesh = malla
	instancia.position = posicion
	add_child(instancia)
