class_name Nave3D
extends Node3D
## La nave modular de assets/modelos/nave.glb.
##
## Cada pieza del modelo es un nodo con el mismo nombre que su id en
## data/datos.json; mostrar() prende las elegidas y apaga el resto.

const MODELO := preload("res://assets/modelos/nave.glb")
## Piezas que van plegadas dentro del cohete durante el lanzamiento.
const PLEGABLES := ["panel_chico", "panel_grande", "antena_media", "antena_alta", "radar"]

var _piezas: Dictionary = {}  # id -> Node3D


func _init() -> void:
	var modelo := MODELO.instantiate()
	add_child(modelo)
	for pieza in GameState.get_piezas():
		var nodo := modelo.find_child(pieza["id"], true, false)
		if nodo:
			_piezas[pieza["id"]] = nodo


func mostrar(ids: Array, plegada := false) -> void:
	for id in _piezas:
		_piezas[id].visible = ids.has(id) and not (plegada and PLEGABLES.has(id))
