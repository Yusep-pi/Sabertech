# Sabertech — Documentación del proyecto

Juego de misión espacial hecho para el hackathon (entrega: domingo 15 de noviembre de 2026). Este documento cuenta qué es el juego, cómo está construido y cómo llegó hasta acá, desde el primer commit hasta hoy. Para empezar a trabajar rápido alcanza con el [README](../README.md); el contexto original del equipo (reparto de roles, hitos, dirección de arte) está en [CONTEXTO.md](../CONTEXTO.md).

## Índice

1. [El desafío y el concepto](#1-el-desafío-y-el-concepto)
2. [Cómo se juega](#2-cómo-se-juega)
3. [Cronología](#3-cronología)
4. [Arquitectura](#4-arquitectura)
5. [Datos y reglas](#5-datos-y-reglas)
6. [Escenas](#6-escenas)
7. [3D y modelos de Blender](#7-3d-y-modelos-de-blender)
8. [Estilo visual](#8-estilo-visual)
9. [Texturas con Gemini](#9-texturas-con-gemini)
10. [Pruebas](#10-pruebas)
11. [Flujo de trabajo con Git](#11-flujo-de-trabajo-con-git)
12. [Decisiones y por qué](#12-decisiones-y-por-qué)
13. [Estado actual y pendientes](#13-estado-actual-y-pendientes)

---

## 1. El desafío y el concepto

El challenge pide un juego interactivo para diseñar, gestionar y simular una misión espacial completa, tomando decisiones de ingeniería con recursos limitados y viendo cómo cada decisión afecta el resultado. La idea es que los estudiantes vivan en carne propia los compromisos que en clase quedan abstractos: presupuesto contra masa, energía contra ciencia, combustible contra capacidad del cohete.

**Sabertech** responde con un simulador de director de misión en cinco fases. El jugador elige una misión, arma la nave con un presupuesto limitado, la lanza, la opera turno a turno y recibe un informe que **explica por qué le fue como le fue**. Ese informe es la parte que más responde al challenge: no da solo un puntaje, sino frases como *"Tu antena solo pudo transmitir el 40% de los datos que captaron los instrumentos"*.

El tono es optimista y educativo. La estética es low-poly estilo Nintendo 64, con luz y terminación modernas.

## 2. Cómo se juega

Abrir `project.godot` con Godot 4.6 o más nuevo y pulsar F5. En esta computadora Godot está en `/opt/Godot` (ver [Herramientas](#herramientas)).

El juego arranca en **primera persona, dentro de la cabina de la nave**, que está sobre la plataforma de lanzamiento.

| Control | Acción |
|---|---|
| WASD o flechas | Caminar |
| Mouse | Mirar |
| E o clic | Usar la consola que se está mirando |
| Esc | Cerrar una pantalla o soltar el mouse |
| Espacio (en la cinemática) | Saltar el lanzamiento |
| Enter (en operaciones) | Terminar el turno |
| F2 | Cambiar el modo gráfico (Retro, Retro fuerte, Moderno) |

### Las cinco fases

1. **Briefing.** En la computadora de misión se presenta la única misión: un **viaje tripulado a la Luna** (384.400 km, 400 M$ de presupuesto, 1500 m/s de delta-v para frenar al llegar, señal de radio al 33%). Las misiones a la órbita terrestre y a Marte se quitaron para concentrar el juego en la Luna.

2. **Diseño.** Se eligen piezas en seis categorías (cohete, energía, comunicación, propulsión, instrumentos y extras) mientras cinco medidores se actualizan en vivo: **presupuesto, masa, energía, datos y delta-v**. Una nave 3D gira en el centro y muestra las piezas elegidas. Se puede lanzar con medidores en rojo: las consecuencias llegan después.

3. **Lanzamiento.** Una cinemática en tercera persona con cinco planos. El resultado ya está decidido por las reglas: si la nave pesa más de lo que el cohete puede llevar, no despega; si falla la tirada de fiabilidad, el cohete explota; si llega sin suficiente delta-v, no queda en órbita.

4. **Operaciones.** De vuelta en la cabina, ya en órbita y con el destino visible por la ventana. Son 8 turnos: en cada uno se decide qué encender (calefacción, transmisión, cada instrumento) con la energía disponible. Los instrumentos llenan una memoria limitada y **la ciencia solo cuenta cuando se transmite**. Hay tramos con condiciones especiales (cinturones de Van Allen, rotación térmica) y tres eventos al azar con una decisión que tomar.

5. **Informe.** Nota, puntaje y frases que explican el resultado, con botones para rediseñar la nave o volver al briefing.

### Recorrer la nave a pie

Desde la cabina se camina por toda la nave. Las puertas se cruzan **manteniendo E** junto a ellas:

**Cabina** ⇄ puerta trasera ⇄ **Habitáculo** ⇄ puerta sur ⇄ **Esclusa** ⇄ escotilla ⇄ **Exterior**

- **Habitáculo** (`scenes/sala_dos/`, de Luis): cama, refrigerador, casilleros y una ventana sobre la cama.
- **Esclusa** (`scenes/esclusa/`): el traje colgado en el armario, un ventanal hacia el exterior y la escotilla. Ponerse el traje, despresurizar y salir. Solo se vuelve a la nave con la esclusa presurizada y sin el traje, y la escotilla se abre solo en órbita.
- **Caminata espacial** (`scenes/eva/`): supervivencia en gravedad cero con mochila propulsora, oxígeno y combustible limitados, reparaciones con puzzles y lluvias de micrometeoritos.

La misión sigue corriendo mientras se recorre la nave: el hambre y la cordura bajan y el viaje a la Luna avanza.

## 3. Cronología

Todo el trabajo se hizo el sábado 14 de noviembre de 2026.

### Planificación (antes del código)

En una conversación previa el equipo definió el concepto, las cinco fases, las piezas, los medidores, las fórmulas, la arquitectura (un solo archivo de datos, un único `GameState`, una escena por pantalla), el reparto en cuatro roles y la dirección de arte. Todo eso quedó en [CONTEXTO.md](../CONTEXTO.md).

### 07:28 — Base del proyecto (`59cf5f0`)

- Proyecto de Godot, archivo de datos con las tres misiones y 17 piezas con valores provisorios.
- Autoload `GameState` con las fórmulas y los cinco medidores.
- Pantalla de diseño mínima, sin arte, armada automáticamente desde los datos.
- Primera prueba automática de las fórmulas.

### 10:20 — Versión jugable completa en 3D (`bc23785`, PR #1)

Este commit junta varias etapas que se fueron probando a mano:

1. **Partida completa con gráficos provisorios.** Se decidió primero asegurar que el juego fuera divertido y dejar el arte para después. Se sumaron el briefing, el lanzamiento, las operaciones por turnos con eventos y el informe con frases. El balance se ajustó simulando 1600 partidas.
2. **Pasaje a 3D.** Se eligió que la misión fuera tripulada, con el jugador en primera persona dentro de la cabina (referencias de ambiente: Outer Wilds y No Man's Sky). Los modelos se generan con un script de Blender. El lanzamiento se volvió una cinemática en tercera persona con planos y cortes suaves.
3. **Correcciones tras jugar.** Se grabaron dos partidas reales y se corrigió lo que trababa: arrancar mirando la consola correcta con un marcador flotante, un botón "Terminar turno" destacado con la tecla Enter, el desvío al caminar en la cabina girada y el humo que tapaba el despegue.

### 12:24 — Esclusa y caminata espacial (`71524cb`, PR #2)

El equipo propuso convertir parte del juego en supervivencia: salir de la nave a reparar cosas. Se construyó como nivel aparte para poder probarlo sin tocar el resto:

- Caminata en gravedad cero con inercia, oxígeno, combustible y traje limitados, y lluvia de micrometeoritos.
- Las reparaciones pasaron de "mantener E" a **puzzles**: la cámara se acerca a un panel con perillas e indicadores, y hay que encontrar el punto intermedio donde todos quedan en verde.
- La esclusa, con ventanal, escotilla y armario con el traje.

### 14:37 — Estilo visual y texturas (`6899824`, PR #3)

- Prompts para Gemini y generación de las 13 imágenes directamente en la cuenta del equipo.
- Estilo "N64 con luz moderna" que se aplica solo a todas las escenas: luz, sombras, contornos, material propio con relieve y filtro retro.
- Tras la primera prueba, se corrigió que las texturas se vieran repetidas y "pegadas" (ver [Estilo visual](#8-estilo-visual)).

### Rama guardada sin subir: modo campaña (`878f5b0`)

Para llevar la partida a unos 30 minutos se hizo un modo campaña (Tierra → Luna → Marte con fondos que pasan de una misión a otra e investigación de piezas nuevas). Como otros miembros del equipo están puliendo las mismas pantallas, **no se subió**: está solo en la rama local `feature/campana`. Ver [Pendientes](#13-estado-actual-y-pendientes).

## 4. Arquitectura

```
project.godot
├── data/datos.json              Misiones, piezas, eventos, frases, caminata
├── scripts/
│   ├── autoload/game_state.gd   Estado de la partida y todas las cuentas
│   ├── autoload/estilo.gd       Estilo visual global
│   ├── ui/interfaz.gd           Colores y piezas de interfaz compartidas
│   ├── nave_3d.gd               Nave modular 3D
│   ├── espacio.gd               Entorno espacial, estrellas, planetas
│   └── *.gdshader               Material retro, contornos, filtro retro
├── scenes/<pantalla>/           Una carpeta por pantalla o nivel
├── assets/modelos/*.glb         Generados por blender/generar_modelos.py
├── assets/texturas/*.png        Texturas de Gemini y sus relieves
├── blender/                     Script y archivo .blend de los modelos
├── arte/                        Prompts de Gemini y generador de relieves
└── tests/                       Pruebas de lógica y recorridos con capturas
```

Tres principios guían todo:

1. **Los datos están separados del código.** Todo lo que se balancea (piezas, misiones, eventos, frases, parámetros de la caminata) vive en `data/datos.json`. Quien se ocupa del contenido lo edita sin tocar código.
2. **Una sola fuente de verdad.** El autoload `GameState` guarda la partida y hace todas las cuentas. Las pantallas solo leen de ahí, llaman a sus funciones y escuchan sus señales (`medidores_cambiados`, `turno_terminado`, etc.).
3. **Una escena por pantalla, un dueño por escena**, para evitar conflictos de Git en los archivos `.tscn`. Además, las pantallas se arman casi enteras por código, así los `.tscn` son mínimos.

### Navegación

`GameState.ir_a(pantalla)` decide cómo se cambia de fase. La cabina es la escena principal: las pantallas de interfaz (briefing, diseño, operaciones, informe) se abren **encima de ella**, como si se mirara la consola de cerca. El lanzamiento es una escena aparte que, al terminar, vuelve a la cabina ya en órbita.

### Autoloads

| Autoload | Qué hace |
|---|---|
| `GameState` | Misión, piezas elegidas, medidores, lanzamiento, operaciones e informe. Ver [Datos y reglas](#5-datos-y-reglas). |
| `Estilo` | Mejora cada escena al cargarse: entorno, luces, materiales, contornos y filtro retro. Ver [Estilo visual](#8-estilo-visual). |

## 5. Datos y reglas

### Piezas

17 piezas en seis categorías. Todas tienen costo, masa y fiabilidad, y cada categoría suma sus propios campos:

| Categoría | Opciones | Campos propios | Compromiso |
|---|---|---|---|
| Cohete | chico, mediano, pesado | capacidad de carga | capacidad contra costo y fiabilidad |
| Energía | panel chico, panel grande, RTG | potencia, tipo (solar o RTG) | los paneles rinden menos lejos del Sol y nada a la sombra |
| Comunicación | antena baja, media y alta | datos por turno | más datos, más masa y consumo |
| Propulsión | químico, eficiente, iónico | Isp, combustible | delta-v contra masa y electricidad |
| Instrumentos | cámara, espectrómetro, radar | datos, ciencia por dato | ciencia contra energía y datos |
| Extras | redundancia, blindaje | menos fallas, menos daño | menos riesgo contra masa y costo |

Toda nave lleva además una **estructura base** (`nave_base`) con computadora, batería y memoria.

### Fórmulas de los medidores

| Medidor | Cálculo | En verde si… |
|---|---|---|
| Presupuesto | suma de costos | no supera el presupuesto |
| Masa | masa seca + combustible | no supera la capacidad del cohete × factor de la misión |
| Energía | consumo de todo + calefacción | no supera la generación |
| Datos | datos de los instrumentos | no superan lo que la antena transmite / factor de la misión |
| Delta-v | `Isp × 9,81 × ln(masa total / masa seca)` (Tsiolkovsky) | alcanza lo que pide la misión |

- **Energía solar:** potencia / distancia al Sol² (la Luna está a 1 UA, así que rinde completo salvo a la sombra o en la rotación térmica). El RTG no depende de la distancia ni de la sombra.
- **Fiabilidad:** producto de las fiabilidades de las piezas; la redundancia reduce a la mitad la probabilidad de falla de la nave.

### Operaciones

- **Energía del turno:** generación + batería. Los sistemas básicos siempre consumen; lo demás se enciende y se apaga. Si el plan no entra, se apagan cosas automáticamente.
- **Datos:** los instrumentos llenan una memoria de 150 unidades; lo que no entra se pierde. Transmitir los envía a la Tierra y recién ahí se convierten en ciencia.
- **Daño:** sin calefacción, la electrónica sufre; si no alcanza ni para los sistemas básicos, hay un apagón. Con la salud en cero, se pierde el contacto.
- **Condiciones del viaje:** cinturones de Van Allen en el tramo 2 (los instrumentos captan mucho ruido) y rotación térmica en el tramo 5 (paneles a la mitad).
- **Eventos** (3 por partida, al azar): tormenta solar, falla de componente, cometa, desvío de órbita y micrometeorito. Cada uno pide una decisión, y varios usan lo que se eligió en el diseño: el delta-v de sobra, la redundancia o el blindaje.

### Informe

Puntaje: ciencia hasta 600 (900 si se supera el objetivo) + salud hasta 200 + presupuesto (ahorrar suma hasta 200; pasarse resta cuatro veces más). Nota: Misión legendaria, exitosa, éxito parcial, con problemas, contacto perdido o misión perdida. Las frases salen de `datos.json` y se eligen según lo que pasó.

## 6. Escenas

| Escena | Tipo | Qué es |
|---|---|---|
| `cabina` | 3D, primera persona | Escena principal. Plataforma antes del lanzamiento, órbita después. Consolas con datos en vivo y un marcador que indica qué usar. |
| `briefing` | Interfaz | Tarjeta de la misión a la Luna, para aceptarla. |
| `diseno` | Interfaz + 3D | Piezas, medidores y nave 3D girando. |
| `lanzamiento` | 3D, cinemática | Cinco planos: general con cuenta regresiva, motores, contrapicado del despegue, seguimiento con teleobjetivo y ascenso. Variantes de falla. |
| `operaciones` | Interfaz | Plan de energía, estado de la nave, bitácora y eventos. |
| `informe` | Interfaz | Nota, puntaje y frases. |
| `sala_dos` | 3D, primera persona | Habitáculo (de Luis): cama, refrigerador y casilleros; une la cabina con la esclusa. |
| `esclusa` | 3D, primera persona | Traje, despresurización y salida al exterior. |
| `eva` | 3D, gravedad cero | Caminata espacial con supervivencia y puzzles. |

Cada escena se puede abrir sola desde el editor (F6): si le faltan datos, arma una partida de prueba.

### La caminata espacial en detalle

- **Movimiento:** inercia conservada como en el espacio; frenar (X) también gasta combustible. Los choques por encima de 2,5 m/s dañan el traje.
- **Recursos:** 4 minutos de oxígeno y combustible limitado. En la escotilla se recargan.
- **Tareas:** cuatro reparaciones según las piezas que lleve la nave. Cada una abre un **panel con perillas (0 a 10), interruptores e indicadores**: cada perilla mueve varios indicadores a la vez, y la solución siempre está en valores intermedios. La dificultad crece de una tarea a otra (2 perillas y 1 indicador en el panel solar; 3 válvulas y 2 indicadores en el motor).
- **Lluvia de micrometeoritos:** cada 60 a 90 segundos, con 12 segundos de aviso y la dirección marcada. Hay que cubrirse detrás de la nave o entrar a la escotilla.
- Todos los valores están en el bloque `eva` de `datos.json`.

## 7. 3D y modelos de Blender

Los modelos no se dibujan a mano: los genera el script `blender/generar_modelos.py`, que arma cada pieza con figuras simples y exporta los `.glb`. Así cualquier cambio se rehace en segundos:

```bash
/media/menibon/Datos/Blender/blender-5.2.4-candidate+v52.4f5026e99892-linux.x86_64-release/blender --background --factory-startup --python blender/generar_modelos.py
```

| Modelo | Contenido |
|---|---|
| `nave.glb` | Nave modular: cada pieza es un nodo con el mismo nombre que su id en `datos.json` |
| `cohetes.glb` | Los tres cohetes, cada uno con un punto `<id>_carga` donde va la nave |
| `plataforma.glb` | Plataforma, torre de servicio, tanques y edificios |
| `cabina.glb` | Interior con ventanal, asiento y cuatro consolas |
| `esclusa.glb` | Ventanal, escotilla con panel y armario con el traje |

**Convenciones importantes** (si se rehacen los modelos a mano, hay que respetarlas):
- En Blender el frente mira a +Y; en Godot queda mirando a -Z.
- Las piezas de la nave se llaman igual que su id (`panel_grande`, `radar`…): el juego las prende y apaga por nombre.
- Las consolas se llaman `consola_<nombre>` y sus pantallas, `pantalla_<nombre>`.
- Un objeto cuyo nombre termina en `-col` recibe colisión al importarse.

## 8. Estilo visual

El objetivo: verse como un juego de Nintendo 64 bien terminado, con luz moderna. Todo lo maneja el autoload `Estilo`, que actúa sobre cada escena al cargarse.

| Capa | Archivo | Qué hace |
|---|---|---|
| Luz | `estilo.gd` | Tonemapping filmic, bloom, sombreado en rincones (SSAO), luz rebotada (SSIL), contraste y saturación |
| Sombras | `estilo.gd` | Todas las luces proyectan sombra; el sol tiene penumbra suave |
| Niebla | `estilo.gd` | Niebla volumétrica suave en la cabina y la esclusa, sin teñir el espacio de afuera |
| Modelos | `blender/generar_modelos.py` | Bisel en los cantos, normales ponderadas y el doble de lados en cilindros y esferas |
| Material | `material_retro.gdshader` | Filtrado suave con mipmaps (como la N64), proyección triplanar, relieve, brillo y metal por material, manchas de tono y desgaste |
| Profundidad | `estilo.gd` | Desenfoque de lo lejano por escena y reflejos en pisos y metales (SSR) |
| Carteles | `carteles_nitidos.gd` | Los carteles que flotan sobre todo se dibujan en 2D, siempre nítidos |
| Contornos | `contornos.gdshader` | Línea fina azul noche en aristas y siluetas |
| Filtro | `retro.gdshader` | Tramado de color tipo N64, aberración cromática leve, viñeta y grano, sin agrandar los píxeles (salvo en "Retro fuerte"); la interfaz queda nítida |

### Cómo se dejó de ver "tipo Minecraft"

La versión anterior se veía como bloques por tres motivos, y se resolvieron así:

1. **Cajas con aristas filosas** → bisel y normales ponderadas en Blender: los cantos atrapan la luz y las caras grandes quedan planas.
2. **Texturas con el píxel duro** (como Minecraft o PlayStation 1) → filtrado bilineal con mipmaps, que es lo que hacía la N64, y texturas de 256 px.
3. **Pantalla pixelada al doble** → el toque retro pasó al color (bandas y tramado), los contornos y la paleta; los píxeles grandes quedaron como opción en "Retro fuerte".

A eso se sumaron efectos de profundidad modernos: desenfoque de lo lejano, reflejos y una aberración cromática leve.

### Cómo se evita que las texturas se vean repetidas

La primera versión con texturas se veía "pegada a las apuradas": el mismo patrón idéntico en todas las superficies. Se corrigió así:

1. **Manchas de variación:** el material mezcla ruido 3D que nunca se repite para cambiar el tono de una zona a otra y agregar desgaste.
2. **Segunda escala:** en superficies grandes (pasto y concreto) se mezcla la textura a otra escala, por manchas.
3. **Relieve:** cada textura tiene un mapa normal generado a partir de su brillo, así las juntas y remaches tienen volumen.
4. **Tamaño por material:** cada uno tiene su propia escala de repetición.

Los valores de cada material están en la constante `MATERIALES` de `estilo.gd`.

## 9. Texturas con Gemini

Las 13 imágenes salieron de una sola conversación de Gemini para que combinen entre sí. El proceso:

1. Un **bloque de estilo** al principio (paleta estricta, look N64, sin texto ni sombras) y después un prompt por imagen. Todos están en [arte/PROMPTS_GEMINI.md](../arte/PROMPTS_GEMINI.md).
2. Las imágenes se bajaron con el botón "Copiar imagen" de Gemini y un script que lee el portapapeles: las descargas directas no funcionaban con la configuración del navegador.
3. Se revisaron repitiéndolas 2×2 para ver costuras.
4. Se redujeron (256 px las texturas, 1024×512 los planetas y el fondo) y se generaron los relieves:

```bash
python3 arte/generar_relieves.py
```

Cada imagen en `assets/texturas/` con el nombre de un material **se aplica sola**. Los originales de 1024 px quedaron fuera del repositorio, en `HackathonSpaceChallenge/texturas_gemini/`.

## 10. Pruebas

| Prueba | Qué cubre | Cómo correrla |
|---|---|---|
| `tests/test_game_state.gd` | Fórmulas, medidores, lanzamiento, operaciones, informe y una simulación de balance | `godot --headless --path . -s res://tests/test_game_state.gd` |
| `tests/recorrido.tscn` | Una partida completa con capturas de cada pantalla y cada plano de la cinemática; comprueba la mirada y el caminar en la cabina | `godot --path . res://tests/recorrido.tscn` |
| `tests/recorrido_esclusa.tscn` | Traje, despresurización, salida a la caminata y vuelta | `godot --path . res://tests/recorrido_esclusa.tscn` |
| `tests/recorrido_niveles.tscn` | Recorrer la nave a pie, ida y vuelta: puertas, reglas de la esclusa y ubicación al entrar a cada ambiente | `godot --path . res://tests/recorrido_niveles.tscn` |
| `tests/recorrido_eva.tscn` | Propulsor, freno, mouse, los cuatro puzzles (y 200 paneles al azar por tipo), lluvia, victoria y falta de oxígeno | `godot --path . res://tests/recorrido_eva.tscn` |

Las capturas quedan en la carpeta `capturas/` del proyecto, que Git ignora. Con `-- --sin-filtro` al final se capturan sin el filtro retro.

### Herramientas

- **Godot:** en esta computadora está en `/opt/Godot` (4.6.1). Para usar `godot` como en los comandos de arriba: `mkdir -p ~/.local/bin && ln -s /opt/Godot ~/.local/bin/godot`. No instalar `godot3`: es Godot 3 y no abre este proyecto.
- **Blender:** 5.2.4, en `/media/menibon/Datos/Blender/`.
- **Python 3 con Pillow:** para los relieves y el procesamiento de texturas.

## 11. Flujo de trabajo con Git

- Repositorio privado: [github.com/Yusep-pi/Sabertech](https://github.com/Yusep-pi/Sabertech). Hay que invitar a cada miembro del equipo en *Settings → Collaborators*.
- `main` siempre tiene una versión que funciona. Cada trabajo nuevo va en su rama (`feature/…`) y entra por pull request.
- Antes de cada commit se corren las pruebas.

| PR | Rama | Contenido |
|---|---|---|
| [#1](https://github.com/Yusep-pi/Sabertech/pull/1) | `feature/version-3d` | Partida completa en 3D |
| [#2](https://github.com/Yusep-pi/Sabertech/pull/2) | `feature/esclusa-y-exterior` | Esclusa y caminata espacial |
| [#3](https://github.com/Yusep-pi/Sabertech/pull/3) | `feature/estilo-visual` | Estilo visual y texturas |

## 12. Decisiones y por qué

| Decisión | Por qué |
|---|---|
| Primero jugabilidad, después arte | Asegurar que el juego fuera divertido antes de invertir en gráficos |
| Misión tripulada, en primera persona | Hace que operar la nave se sienta físico; inspirado en Outer Wilds |
| Lanzamiento como cinemática | Es el momento más espectacular y no necesita interacción |
| Se puede lanzar con medidores en rojo | Aprender del fallo: el informe explica qué salió mal |
| Modelos generados por script | Se rehacen en segundos y se pueden ajustar sin saber Blender |
| Pantallas armadas por código | Archivos `.tscn` mínimos, menos conflictos de Git |
| Estilo como autoload | Mejora todas las escenas sin tocar los archivos que pule el equipo |
| Caminata y esclusa como niveles aparte | Probar la idea de supervivencia sin arriesgar el juego principal |
| Puzzles con solución intermedia | Más interesantes que "mantener E" sin complicar de más al jugador |
| Campaña sin subir | Otros miembros están puliendo las mismas pantallas |

## 13. Estado actual y pendientes

### Funciona hoy (en `main`)

- Partida completa de punta a punta en 3D, con las cinco fases.
- La nave se recorre a pie: cabina, habitáculo, esclusa y exterior, ida y vuelta.
- Estilo visual con texturas, relieve, contornos, sombras y filtro retro.
- Pruebas automáticas de todo lo anterior.

### Pendientes

1. **Darle un motivo a la caminata:** que algún evento de las operaciones obligue a salir a reparar (por ejemplo, una falla de panel solar que se arregla afuera), y que el resultado de la caminata vuelva a la misión.
2. **Decidir qué hacer con la campaña** (rama local `feature/campana`): tres misiones encadenadas, fondos que pasan de una a otra, investigación de cinco piezas nuevas, reintentos y título final. Lleva la partida a 25-35 minutos. Habría que adaptarla a lo que el equipo cambió en las pantallas antes de subirla.
3. **Más profundidad en los turnos:** objetivos científicos concretos ("mapear el polo durante la noche lunar"), ventanas de comunicación y un minijuego de inserción orbital.
4. **Balance:** la Luna con radar sigue siendo muy fuerte; conviene que el rol de contenido lo revise jugando.
5. **Sonido:** el juego todavía no tiene audio.
6. **Íconos y paneles de interfaz** con el estilo Frutiger Aero: los prompts están en [CONTEXTO.md](../CONTEXTO.md).
