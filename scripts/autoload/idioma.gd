extends Node
## Idioma del juego (autoload "Idioma"). El español es el idioma fuente: los textos
## se escriben en español en el código y en data/datos.json, y el inglés sale de
## idiomas/en.po (msgid = texto en español). Si falta una traducción, se ve el español.
## Se elige con las banderas del menú de inicio y se guarda en user://ajustes.cfg.

signal idioma_cambiado(codigo: String)

const IDIOMAS := ["es", "en"]
const NOMBRES := {"es": "Español", "en": "English"}
const RUTA_AJUSTES := "user://ajustes.cfg"

var actual := "es"


func _ready() -> void:
	var ajustes := ConfigFile.new()
	var codigo := "es"
	if ajustes.load(RUTA_AJUSTES) == OK:
		codigo = str(ajustes.get_value("juego", "idioma", "es"))
	# Siempre explícito: si no, Godot elegiría el idioma del sistema operativo.
	usar(codigo)


## Cambia el idioma y lo guarda para la próxima vez.
func cambiar(codigo: String) -> void:
	usar(codigo)
	var ajustes := ConfigFile.new()
	ajustes.load(RUTA_AJUSTES)
	ajustes.set_value("juego", "idioma", actual)
	ajustes.save(RUTA_AJUSTES)


## Cambia el idioma sin guardarlo (lo usan los tests).
func usar(codigo: String) -> void:
	actual = codigo if codigo in IDIOMAS else "es"
	TranslationServer.set_locale(actual)
	# Los textos de datos.json se traducen al cargarlos: hay que recargarlos.
	if GameState.datos.size() > 0:
		GameState.cargar_datos()
		GameState.recalcular()
	idioma_cambiado.emit(actual)


func es_ingles() -> bool:
	return actual == "en"
