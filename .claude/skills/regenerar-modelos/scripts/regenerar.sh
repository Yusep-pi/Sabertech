#!/usr/bin/env bash
# Regenera los modelos de Blender y los reimporta en Godot.
#
#   .claude/skills/regenerar-modelos/scripts/regenerar.sh [--forzar]
#
# Sin --forzar se detiene si blender/sabertech.blend tiene cambios sin
# commitear, porque el generador lo sobrescribe y se perderían retoques a mano.
set -uo pipefail

RAIZ="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
cd "$RAIZ" || exit 1

FORZAR=0
[ "${1:-}" = "--forzar" ] && FORZAR=1

# 1. Encontrar Blender: $BLENDER, el del PATH o la ruta que usa el equipo en la documentación.
BLENDER_BIN="${BLENDER:-}"
if [ -z "$BLENDER_BIN" ] && command -v blender >/dev/null 2>&1; then
	BLENDER_BIN="$(command -v blender)"
fi
if [ -z "$BLENDER_BIN" ]; then
	for candidato in /media/menibon/Datos/Blender/blender-*/blender; do
		[ -x "$candidato" ] && BLENDER_BIN="$candidato"
	done
fi
if [ -z "$BLENDER_BIN" ]; then
	echo "ERROR: no encontré Blender. Instálalo o exporta BLENDER=/ruta/a/blender." >&2
	exit 2
fi
command -v godot >/dev/null 2>&1 || { echo "ERROR: no encontré godot en el PATH." >&2; exit 2; }

# 2. Proteger retoques a mano del .blend.
if [ "$FORZAR" -eq 0 ] && ! git diff --quiet HEAD -- blender/sabertech.blend 2>/dev/null; then
	echo "ALTO: blender/sabertech.blend tiene cambios sin commitear (¿retoques a mano?)." >&2
	echo "El generador lo sobrescribe. Commitea o respáldalo, o vuelve a correr con --forzar." >&2
	exit 3
fi

echo "== Blender: $("$BLENDER_BIN" --version 2>/dev/null | head -1)"
SALIDA_BLENDER="$(mktemp)"
"$BLENDER_BIN" --background --factory-startup --python blender/generar_modelos.py >"$SALIDA_BLENDER" 2>&1
CODIGO=$?
if [ $CODIGO -ne 0 ] || ! grep -q "Modelos exportados en" "$SALIDA_BLENDER"; then
	echo "ERROR: falló generar_modelos.py (código $CODIGO). Últimas líneas:" >&2
	grep -E "Error|Traceback|File \"" "$SALIDA_BLENDER" | tail -20 >&2
	tail -15 "$SALIDA_BLENDER" >&2
	exit 4
fi
echo "== Modelos exportados:"
ls -l --time-style=+%H:%M:%S assets/modelos/*.glb | awk '{print "   " $6 "  " $5 " bytes  " $7}'
echo "== Previews:"
ls blender/previews/*.png | sed 's/^/   /'

# 3. Reimportar en Godot (actualiza .godot/imported y los .glb.import).
echo "== Reimportando en Godot..."
SALIDA_GODOT="$(mktemp)"
godot --headless --path . --import >"$SALIDA_GODOT" 2>&1
CODIGO=$?
if [ $CODIGO -ne 0 ] || grep -qE "^(ERROR|SCRIPT ERROR)" "$SALIDA_GODOT"; then
	echo "AVISO: la importación de Godot reportó problemas (código $CODIGO):" >&2
	grep -E "ERROR|WARNING" "$SALIDA_GODOT" | head -20 >&2
	exit 5
fi
echo "   Importación sin errores."

echo "== Cambios en git:"
git status --short -- assets/modelos blender | sed 's/^/   /'
