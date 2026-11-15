---
name: regenerar-modelos
description: Regenera los modelos 3D del juego (nave, cohetes, plataforma, cabina, esclusa) corriendo blender/generar_modelos.py, revisa los renders de blender/previews y reimporta los .glb en Godot. Úsala siempre que se cambie generar_modelos.py, cuando pidan "regenerar", "rehacer", "exportar" o "actualizar" los modelos o los .glb, cuando un cambio de geometría, color o nombre de pieza no se vea en el juego, o después de editar construir_nave/construir_cabina/construir_esclusa u otra función de construcción, aunque no nombren la skill.
---

# Regenerar modelos

Los modelos de `assets/modelos/*.glb` no se editan a mano: los genera
`blender/generar_modelos.py`. Esta skill cierra el ciclo completo: generar,
mirar los renders y reimportar en Godot, para que un cambio en el script
llegue al juego y se compruebe que quedó bien.

## 1. Antes de correr

- **Retoques a mano.** El generador sobrescribe `blender/sabertech.blend` y todos los
  `.glb`. Si alguien retocó el `.blend` o un `.glb` a mano y no está commiteado, se
  pierde. El script se detiene solo si el `.blend` tiene cambios; si se detiene,
  pregunta al usuario antes de usar `--forzar`.
- **Nombres de piezas.** Las piezas de la nave son empties con el mismo nombre que su
  id en `data/datos.json`, y el juego las prende y apaga por nombre. Si el cambio
  renombra o quita una pieza, revisa `datos.json` y busca el nombre en `scripts/` y
  `scenes/` antes de regenerar.

## 2. Correr el script

```bash
.claude/skills/regenerar-modelos/scripts/regenerar.sh
```

Hace todo lo mecánico: encuentra Blender (`$BLENDER`, el del PATH o la ruta del
equipo en `/media/menibon/...`), corre el generador, verifica que exportó y
reimporta con `godot --headless --import`. Códigos de salida: 2 falta Blender o
Godot, 3 el `.blend` tiene cambios, 4 falló el generador (muestra el traceback),
5 Godot reportó errores al importar.

Si falla el generador, corrige `generar_modelos.py` y vuelve a correr; no edites
los `.glb` para esquivar el error.

## 3. Revisar los previews

Abre con Read cada PNG de `blender/previews/` (`nave`, `cohetes`, `cabina`,
`esclusa`, `plataforma`). Son renders Workbench de 960×540, sin texturas, así que
juzga forma, proporción, colores planos y posición, no materiales.

Concéntrate en el modelo que cambió y confirma que el cambio pedido se ve. Echa un
vistazo rápido a los demás por si algo compartido (colores, `caja()`,
`cilindro()`) los rompió. Si algo se ve mal, ajusta el script y repite desde el
paso 2. Si un preview no deja ver el cambio por el ángulo de cámara, dilo en vez de
darlo por bueno.

## 4. Comprobar en el juego (si el cambio afecta lo que el jugador ve o toca)

Los recorridos de `tests/` sacan capturas en `capturas/` y necesitan ventana, no
`--headless`:

| Modelo cambiado | Recorrido |
|---|---|
| esclusa | `godot --path . res://tests/recorrido_esclusa.tscn` |
| cabina, nave, pasillos | `godot --path . res://tests/recorrido_niveles.tscn` |
| cohetes, plataforma, lanzamiento | `godot --path . res://tests/recorrido.tscn` |

Las colisiones salen de objetos cuyo nombre termina en `-col`; si cambiaste paredes,
pisos o puertas, el recorrido es la forma de saber que el jugador no las atraviesa.

## 5. Informar

Resume en pocas líneas: qué modelos cambiaron, qué se ve en los previews (lo que
miraste de verdad), si la importación y los recorridos pasaron, y qué quedó en
`git status`. Los `.glb`, `.glb.import` y `sabertech.blend` regenerados van en el
mismo commit que el cambio de `generar_modelos.py`, para que el repo no quede con
modelos desfasados del script. No commitees si el usuario no lo pidió.
