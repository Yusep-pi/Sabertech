# Sabertech — Misión Espacial

Juego para el hackathon: diseñar, lanzar y operar una misión espacial. El contexto completo (concepto, fases, reparto, arte) está en [CONTEXTO.md](CONTEXTO.md). La documentación completa del proyecto, de principio a fin (cómo se juega, arquitectura, reglas, 3D, estilo visual, pruebas, historia y pendientes), está en [docs/DOCUMENTACION.md](docs/DOCUMENTACION.md).

Godot 4.6 o más nuevo. Abrir `project.godot` y ejecutar (F5): arranca en la cabina de la nave, en primera persona.

**Controles:** WASD o flechas para caminar, mouse para mirar, E o clic para usar la consola que se mira, Esc para cerrar una pantalla o soltar el mouse. En la cinemática, Espacio la salta.

## Recorrer la nave a pie

Desde la cabina se puede caminar por toda la nave. Las puertas se cruzan **manteniendo E** junto a ellas, con una barra de progreso y un fundido a negro (`scripts/compuerta.gd`):

**Cabina** ⇄ puerta trasera ⇄ **Habitáculo** ⇄ puerta sur (Módulo 03) ⇄ **Esclusa** ⇄ escotilla ⇄ **Exterior**

- **Habitáculo** (`scenes/sala_dos/`, hecho por Luis): cama, refrigerador, casilleros y una ventana sobre la cama.
- **Reglas de la esclusa:** a la nave solo se vuelve con la esclusa presurizada y sin el traje puesto, y la escotilla se abre solo en órbita (en la plataforma, por el ventanal se ve el cielo).
- Cada ambiente ubica al jugador frente a la puerta por la que entró. La misión sigue corriendo mientras se recorre la nave: el hambre y la cordura bajan y el viaje a la Luna avanza.
- `tests/recorrido_niveles.tscn` recorre toda la cadena, ida y vuelta.

## Esclusa

`scenes/esclusa/` es la sala desde donde se sale a la caminata espacial. Tiene un ventanal grande con vista al exterior (la Tierra, las estrellas y la nave), la escotilla con su panel y un armario con el traje colgado. Se llega desde el habitáculo, y también se prueba sola con `scenes/esclusa/esclusa.tscn` y F6, o:

```bash
godot --path . res://scenes/esclusa/esclusa.tscn
```

- **Ida:** ponerse el traje en el armario, despresurizar y abrir desde el panel (luces rojas, baliza, vapor por la ventilación, barra de presión) y cruzar la escotilla, que lleva a la caminata.
- **Vuelta:** al terminar la caminata se vuelve a entrar con la escotilla abierta; desde el panel se cierra y se presuriza, y en el armario se saca el traje.
- **Puerta interior:** vuelve al habitáculo, con la esclusa presurizada y sin el traje.

El modelo es `esclusa.glb`, generado por `construir_esclusa()` en `blender/generar_modelos.py`. `tests/recorrido_esclusa.tscn` lo prueba solo.

## Caminata espacial

`scenes/eva/` es un nivel de supervivencia que todavía no está conectado al juego. Se prueba solo: abrir `scenes/eva/eva.tscn` y pulsar F6, o:

```bash
godot --path . res://scenes/eva/eva.tscn
```

El astronauta sale por la escotilla con oxígeno, combustible y traje limitados. Tiene que arreglar 4 problemas en el exterior de la nave y volver a la escotilla, donde además recarga oxígeno y combustible. Se mueve en gravedad cero con una mochila propulsora: la inercia se conserva, frenar gasta combustible y los choques fuertes dañan el traje. Cada tanto llega una lluvia de micrometeoritos desde un costado, y hay que cubrirse detrás de la nave.

**Controles:** WASD para propulsar, Espacio y Ctrl para subir y bajar, Shift para el turbo, X para frenar, Z y C para rotar, mantener E para reparar.

La nave es la elegida en el diseño o, si no hay ninguna, `nave_por_defecto`. Los valores se ajustan en el bloque `eva` de `datos.json`. `tests/recorrido_eva.tscn` lo prueba solo y guarda capturas.

## Estilo visual: N64 con luz moderna

Lo maneja el autoload `Estilo` (`scripts/autoload/estilo.gd`) y se aplica solo a todas las escenas:

- **Luz:** tonemapping filmic, bloom en pantallas y luces, sombreado ambiental en rincones y uniones (SSAO), luz rebotada entre superficies (SSIL), más contraste y saturación, y en la cabina y la esclusa una niebla volumétrica suave que marca la luz que entra por las ventanas.
- **Modelos con terminación:** cada caja y cilindro del script de Blender lleva un bisel chico en los cantos y normales ponderadas, y los cilindros y esferas el doble de lados. Las caras grandes quedan planas y los cantos atrapan la luz: deja de verse como bloques.
- **Profundidad:** lo lejano se desenfoca suavemente (profundidad de campo por escena, en `PROFUNDIDAD` de `estilo.gd`), los pisos y metales reflejan (SSR) y los carteles que flotan sobre todo se dibujan en 2D para verse siempre nítidos (`scripts/carteles_nitidos.gd`).
- **Filtro retro** (`scripts/retro.gdshader`): menos niveles de color con tramado ordenado como el de la N64, una aberración cromática leve hacia los bordes, viñeta y un grano sutil, sin agrandar los píxeles. La interfaz queda nítida. **F2** alterna entre Retro, Retro fuerte (con píxeles grandes) y Moderno (sin filtro).
- **Texturas:** cada imagen que se guarde en `assets/texturas/` con el nombre de un material (`casco.png`, `pared.png`...) se aplica sola con el material retro (`scripts/material_retro.gdshader`): filtrado suave con mipmaps, como hacía la N64, proyección triplanar (los modelos no tienen coordenadas de mapeado), relieve con `<nombre>_normal.png`, brillo y metal según el material, y manchas de tono y desgaste que no repiten, para que no se note el mosaico. En superficies grandes (pasto, concreto) se mezcla además una segunda lectura a otra escala. Los relieves se regeneran con `python3 arte/generar_relieves.py` cada vez que cambie una textura. Los valores de cada material están en `MATERIALES`, en `estilo.gd`.
- **Contornos y sombras:** una línea fina azul noche en aristas y siluetas (`scripts/contornos.gdshader`); todas las luces proyectan sombra y el sol tiene penumbra suave. Lo mismo para `planeta_<destino>.png` y `fondo_espacio.png`. La lista completa y los prompts para generarlas con Gemini están en [arte/PROMPTS_GEMINI.md](arte/PROMPTS_GEMINI.md). Las 13 actuales salieron de esos prompts y están reducidas a 256 px (texturas) y 1024×512 (planetas y fondo). Los originales de 1024 px quedaron fuera del repositorio, en `HackathonSpaceChallenge/texturas_gemini/`.

## Cómo está armado el 3D

- **Cabina (primera persona)** — `scenes/cabina/`. Es el lugar principal. Antes del lanzamiento la nave está sobre la plataforma (por la ventana se ve la torre) y la *computadora de misión* (al frente) abre el briefing y el diseño. Después del lanzamiento la nave está en órbita (por la ventana se ve el destino) y cualquier consola abre las operaciones; al terminar, el informe. Las pantallas de cada consola muestran datos en vivo.
- **Lanzamiento (tercera persona)** — `scenes/lanzamiento/`. Cinemática con cinco planos: general con cuenta regresiva, primer plano de los motores, contrapicado del despegue, seguimiento con teleobjetivo y ascenso. Si el lanzamiento falla, cambia: por masa el cohete tiembla y no sube; por fiabilidad explota en el seguimiento.
- **Pantallas de interfaz** (briefing, diseño, operaciones, informe) se abren encima de la cabina, como si se mirara la consola de cerca. `GameState.ir_a()` decide si abrir una pantalla en la cabina o cambiar de escena.

### Modelos de Blender

Los modelos son low-poly con colores planos, provisorios hasta pasar al estilo N64 con texturas. Se generan con un script, así que se pueden rehacer en segundos:

```bash
/media/menibon/Datos/Blender/blender-5.2.4-candidate+v52.4f5026e99892-linux.x86_64-release/blender --background --factory-startup --python blender/generar_modelos.py
```

Escribe `assets/modelos/{cabina,nave,cohetes,plataforma}.glb`, guarda `blender/sabertech.blend` para mirarlo o retocarlo a mano y deja renders de revisión en `blender/previews/`. Convenciones:

- En Blender el frente mira a +Y; en Godot queda mirando a -Z.
- Cada pieza de la nave es un empty con el mismo nombre que su id en `datos.json` (`panel_grande`, `radar`...): el juego las prende y apaga por nombre (`scripts/nave_3d.gd`). Si arte rehace la nave, tiene que mantener esos nombres.
- Las consolas de la cabina se llaman `consola_principal`, `consola_energia`, `consola_comunicaciones` y `consola_ciencia`; las pantallas, `pantalla_<nombre>`.
- Un objeto cuyo nombre termina en `-col` recibe colisión al importarse en Godot.
- Cada cohete tiene un empty `<id>_carga` donde se apoya la nave.

## Estructura

| Ruta | Qué es |
|---|---|
| `data/datos.json` | Misiones, piezas, eventos y frases del informe. Se balancea acá, sin tocar código. |
| `scripts/autoload/game_state.gd` | Autoload `GameState`: estado de la partida, todas las cuentas y la navegación. |
| `scripts/ui/interfaz.gd` | Colores y piezas de UI compartidas (`Interfaz.etiqueta`, `Interfaz.panel`...). El tema de arte se aplica acá. |
| `scripts/nave_3d.gd` | La nave modular 3D, con las piezas elegidas a la vista. |
| `scenes/cabina/` | Cabina en primera persona (`cabina.gd`) y el jugador (`jugador.gd`). Escena principal. |
| `scenes/briefing/` | Fase 1: presentar la misión a la Luna. |
| `scenes/diseno/` | Fase 2: armar la nave con los 5 medidores y la nave 3D girando. |
| `scenes/lanzamiento/` | Fase 3: cinemática del lanzamiento. |
| `scenes/operaciones/` | Fase 4: 8 turnos repartiendo energía, con eventos. |
| `scenes/informe/` | Fase 5: puntaje y frases que explican el resultado. |
| `blender/generar_modelos.py` | Genera los modelos 3D. |
| `tests/test_game_state.gd` | Pruebas de la lógica y simulación de balance. |
| `tests/recorrido.tscn` | Juega una partida sola y guarda capturas de cada pantalla y de cada plano de la cinemática. |

Cada escena se puede abrir sola desde el editor (F6) para probarla: arma datos de prueba si hace falta.

```bash
godot --headless --path . -s res://tests/test_game_state.gd
```

```bash
godot --path . res://tests/recorrido.tscn
```

Las capturas de los recorridos quedan en la carpeta `capturas/` del proyecto, que Git ignora.

## Cómo se juega cada fase

1. **Briefing:** la misión (viaje tripulado a la Luna) trae distancia, presupuesto, delta-v para frenar, luz solar, señal de radio, capacidad del cohete y ciencia objetivo. Es la única misión: Tierra y Marte se quitaron.
2. **Diseño:** se eligen piezas y los medidores se actualizan en vivo. Se puede lanzar con medidores en rojo.
3. **Lanzamiento:** falla si la masa supera la capacidad, si sale mal la tirada de fiabilidad del cohete o si al llegar falta delta-v.
4. **Operaciones:** cada turno hay `generación + batería` de energía. Los sistemas básicos siempre consumen; calefacción, transmisión e instrumentos se prenden y apagan. Los instrumentos llenan la memoria y la ciencia solo cuenta al transmitir. Lo que no entra en la memoria se pierde. Sin calefacción la nave se daña. Algunos tramos tienen condiciones (cinturones de Van Allen, rotación térmica) y 3 turnos al azar traen un evento con decisión.
5. **Informe:** ciencia hasta 600 puntos (900 si se supera el objetivo), salud hasta 200, presupuesto: ahorrar suma hasta 200 y pasarse resta 4 veces más.

## Usar GameState desde una pantalla

```gdscript
GameState.elegir_mision("luna")       # la única misión
GameState.alternar_pieza("radar")      # elige o quita; en categorías únicas reemplaza
GameState.medidores["energia"]         # {nombre, valor, limite, unidad, mayor_es_mejor, ok}
GameState.lanzar()                     # {exito, motivo}
GameState.iniciar_operaciones()
GameState.cambiar_plan("radar", true)  # false si no alcanza la energía
GameState.resolver_evento(0)
GameState.terminar_turno()             # resumen del turno
GameState.calcular_informe()           # {puntaje, nota, frases, ...}
GameState.ir_a("informe")              # cambia de pantalla
```

Señales: `mision_cambiada`, `seleccion_cambiada`, `medidores_cambiados`, `plan_cambiado`, `turno_iniciado`, `turno_terminado`. Las pantallas no calculan nada: leen de `GameState` y reaccionan a las señales.

## Campos de datos.json

Todas las piezas: `id`, `categoria`, `nombre`, `descripcion`, `costo` (M$), `masa` (kg), `fiabilidad` (0-1). Opcionales: `potencia` (W que genera) y `consumo` (W que gasta).

| Categoría | Campos propios |
|---|---|
| `cohete` | `capacidad`: kg a órbita baja. Se multiplica por `factor_capacidad` de la misión. Su masa no cuenta para la nave. |
| `energia` | `potencia`, `tipo`: `solar` (rinde potencia / distancia² y le afecta `factor_solar`) o `rtg` |
| `comunicacion` | `tasa`: datos por turno. Se divide por `factor_datos` de la misión. |
| `propulsion` | `isp` (s), `combustible` (kg) |
| `instrumento` | `datos` por turno, `ciencia` por dato transmitido |
| `extra` | `reduccion_fallo` (redundancia: además evita las fallas de componente), `proteccion` (blindaje: reduce daño y roturas) |

`nave_base`: estructura que lleva toda nave (suma costo, masa y consumo siempre), con `bateria` y `almacenamiento` (memoria de datos).

Misiones: `presupuesto`, `delta_v` (m/s que debe aportar la nave), `distancia_ua`, `factor_capacidad`, `factor_datos`, `calefaccion` (W), `dano_frio` (salud por turno sin calefacción), `objetivo_ciencia` y `condiciones` por número de turno (`factor_solar`, `multiplicador_instrumentos`).

Eventos: `titulo`, `texto`, `opciones` con `texto`, `efectos`, `resultado` y opcionalmente `requisitos` (`delta_v`). Efectos posibles: `salud`, `sin_ciencia_turnos`, `multiplicador_datos`, `multiplicador_datos_resto`, `delta_v`, `bateria`, `romper` (`instrumento` u `objetivo`), `reparar` (`objetivo`), `probabilidad`, `blindable`. Un evento con `"objetivo": "componente"` elige un componente instalado al azar y lo rompe, salvo que la nave tenga la pieza de `evitable_con`.

Frases: textos del informe con marcadores como `{pct}`. Una clave terminada en `_uno` se usa cuando la cantidad es 1.

## Cómo se calculan los medidores

- **Presupuesto:** suma de costos (cohete + base + piezas) ≤ `presupuesto`.
- **Masa:** masa seca + combustible ≤ `capacidad` del cohete × `factor_capacidad`.
- **Energía:** consumo de todo + `calefaccion` ≤ generación.
- **Datos:** suma de `datos` de los instrumentos ≤ `tasa` / `factor_datos`.
- **Delta-v:** `isp × 9.81 × ln(masa_total / masa_seca)` ≥ `delta_v`.
