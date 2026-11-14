# Sabertech — Misión Espacial

Juego para el hackathon: diseñar, lanzar y operar una misión espacial. El contexto completo (concepto, fases, reparto, arte) está en [CONTEXTO.md](CONTEXTO.md).

Godot 4.6 o más nuevo. Abrir `project.godot`; la escena principal por ahora es la pantalla de diseño.

## Estructura

| Ruta | Qué es | Dueño |
|---|---|---|
| `data/datos.json` | Misiones, categorías y piezas. Se balancea acá, sin tocar código. | Contenido |
| `scripts/autoload/game_state.gd` | Autoload `GameState`: estado de la partida y todas las cuentas. | Lógica |
| `scenes/diseno/` | Pantalla de diseño (versión mínima, sin arte). | Interfaz |
| `scenes/<pantalla>/` | Una carpeta por pantalla: briefing, lanzamiento, operaciones, informe. | Interfaz |
| `tests/test_game_state.gd` | Prueba de fórmulas y medidores. | Lógica |

Probar `GameState` sin abrir el editor:

```bash
godot --headless --path . -s res://tests/test_game_state.gd
```

## Usar GameState desde una pantalla

```gdscript
GameState.elegir_mision("marte")
GameState.alternar_pieza("radar")      # elige o quita; en categorías únicas reemplaza
GameState.medidores["energia"]         # {nombre, valor, limite, unidad, mayor_es_mejor, ok}
GameState.detalle                      # masa_seca, combustible, generacion, fiabilidades, proteccion
GameState.puede_lanzar()               # misión elegida y categorías obligatorias completas
GameState.medidores_cambiados.connect(_on_medidores)
```

Señales: `mision_cambiada`, `seleccion_cambiada`, `medidores_cambiados`. Las pantallas no calculan nada: leen de `GameState` y reaccionan a las señales.

## Campos de datos.json

Todas las piezas: `id`, `categoria`, `nombre`, `descripcion`, `costo` (M$), `masa` (kg), `fiabilidad` (0-1). Opcionales: `potencia` (W que genera) y `consumo` (W que gasta).

| Categoría | Campos propios |
|---|---|
| `cohete` | `capacidad`: kg a órbita baja. Se multiplica por `factor_capacidad` de la misión. Su masa no cuenta para la nave. |
| `energia` | `potencia`, `tipo`: `solar` (rinde potencia / distancia²) o `rtg` |
| `comunicacion` | `tasa`: datos por turno. Se divide por `factor_datos` de la misión. |
| `propulsion` | `isp` (s), `combustible` (kg) |
| `instrumento` | `datos` por turno, `ciencia` por dato transmitido |
| `extra` | `reduccion_fallo` (multiplica la probabilidad de falla de la nave), `proteccion` (para eventos) |

Misiones: `presupuesto`, `delta_v` (m/s que debe aportar la nave), `distancia_ua`, `factor_capacidad`, `factor_datos`, `calefaccion` (W fijos de consumo), `objetivo_ciencia`.

`nave_base` es la estructura que lleva toda nave: suma costo, masa y consumo siempre.

## Cómo se calculan los medidores

- **Presupuesto:** suma de costos (cohete + base + piezas) ≤ `presupuesto`.
- **Masa:** masa seca + combustible ≤ `capacidad` del cohete × `factor_capacidad`.
- **Energía:** consumo de todo + `calefaccion` ≤ generación.
- **Datos:** suma de `datos` de los instrumentos ≤ `tasa` / `factor_datos`.
- **Delta-v:** `isp × 9.81 × ln(masa_total / masa_seca)` ≥ `delta_v`.
