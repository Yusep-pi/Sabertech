# Alcance actual — Sabertech: Misión Espacial

> Documento de estado al **14 de noviembre de 2026**.
> Resume qué es el juego hoy, qué está implementado, cómo se juega y qué queda fuera del alcance.

## 1. Resumen ejecutivo

**Sabertech: Misión Espacial** es un simulador de director de misión espacial en 3D, en primera persona, hecho en **Godot 4.6 + GDScript** para un hackathon. El jugador elige una misión, diseña una nave con presupuesto limitado, la lanza y la opera durante 8 turnos tomando decisiones con recursos escasos. Al final recibe un **informe explicativo** que justifica el resultado.

- **Estado:** partida completa jugable de punta a punta, con gráficos provisorios (low-poly sin texturas).
- **Duración objetivo:** 10–15 minutos por partida.
- **Bucle:** Briefing → Diseño → Lanzamiento → Operaciones → Informe.
- **Público:** educativo/divulgación; tono optimista, no sombrío.
- **Originalidad:** las decisiones de ingeniería (masa, energía, datos, delta-v, presupuesto) tienen consecuencias visibles y el informe final explica el porqué.

## 2. Ficha técnica

| Ítem | Valor |
|---|---|
| Motor | Godot 4.6 (`config/features=PackedStringArray("4.6")`) |
| Lenguaje | GDScript |
| Escena principal | `res://scenes/cabina/cabina.tscn` |
| Resolución base | 1280×720, stretch `canvas_items`, aspecto `expand` |
| Autoloads | `GameState` (lógica) y `GodotAIBridgeRuntime` (automatización IA) |
| Datos | `data/datos.json` (misiones, piezas, eventos y frases) |
| Modelos 3D | 4 GLB low-poly generados con Blender: `cabina`, `nave`, `cohetes`, `plataforma` |
| Logging | Activado a archivo (`debug/file_logging/enable_logging=true`) |
| Herramientas | Plugin `godot_ai_bridge` con WebSocket local en el puerto `6550` |

## 3. El bucle de juego

| # | Fase | Escena | Qué hace el jugador |
|---|---|---|---|
| 1 | **Briefing** | `scenes/briefing/` | Elige 1 de 3 misiones (funcionan como dificultad). |
| 2 | **Diseño** | `scenes/diseno/` | Elige cohete, energía, comunicación, propulsión, instrumentos y extras. Ve 5 medidores en vivo y la nave 3D girando. |
| 3 | **Lanzamiento** | `scenes/lanzamiento/` | Mira una cinemática en tercera persona con 5 planos y cámara en mano. Puede saltearla con Espacio/Enter/Esc. |
| 4 | **Operaciones** | `scenes/operaciones/` | 8 turnos repartiendo energía entre calefacción, transmisión e instrumentos; resuelve eventos. |
| 5 | **Informe** | `scenes/informe/` | Ve puntaje, nota, números y 3–5 frases que explican el resultado. |

La navegación la decide `GameState.ir_a()`. Las pantallas de interfaz se abren **encima de la cabina**, como si el jugador mirara la consola de cerca. El lanzamiento es la única fase que cambia de escena 3D.

## 4. Contenido implementado

### 4.1 Misiones (3)

| Misión | Dificultad | Presupuesto | Delta-v | Distancia | Capacidad | Señal (factor datos) | Ciencia objetivo |
|---|---|---|---|---|---|---|---|
| Satélite de observación terrestre | Fácil | 250 M$ | 500 m/s | 1.00 UA | 100% | ×1.0 | 450 |
| Orbitador lunar | Media | 400 M$ | 1500 m/s | 1.00 UA | 35% | ×3.0 | 320 |
| Orbitador a Marte | Difícil | 550 M$ | 2600 m/s | 1.52 UA | 15% | ×8.0 | 480 |

Cada misión define además calefacción (20/60/80 W), daño por frío (5/15/15) y **condiciones por turno**:

| Misión | Condición | Turnos | Efecto |
|---|---|---|---|
| Tierra | Sombra de la Tierra | 3 y 6 | Paneles solares al 50% |
| Luna | Noche lunar | 4 y 5 | Paneles solares al 0% |
| Marte | Tormenta de polvo | 5 y 6 | Paneles al 60%; cámara ×0.2 y espectrómetro ×0.4 |

### 4.2 Piezas (17 + nave base)

| Categoría | Opciones | Trade-off principal |
|---|---|---|
| Cohete | chico / mediano / pesado | Capacidad vs. costo vs. fiabilidad |
| Energía | panel chico / panel grande / RTG | Potencia vs. masa/costo; los solares rinden menos lejos del Sol |
| Comunicación | antena baja / media / alta | Datos por turno vs. masa y consumo |
| Propulsión | químico / eficiente / iónico | Delta-v vs. masa vs. consumo eléctrico |
| Instrumentos (varios) | cámara / espectrómetro / radar | Ciencia vs. masa, energía y datos |
| Extras (varios) | redundancia / blindaje | Menos riesgo vs. más masa y costo |

La **nave base** (estructura, computadora, batería y memoria) es obligatoria y aporta 40 M$, 250 kg, 50 W de consumo, 400 W de batería y 150 unidades de almacenamiento. La categoría cohete no suma masa a la nave; su masa es la del vehículo lanzador.

### 4.3 Eventos (5 definidos, 3 por partida)

Se programan al azar en 3 de los turnos 2 a 7:

| Evento | Decisión típica | Efectos posibles |
|---|---|---|
| Tormenta solar | Apagar instrumentos o seguir trabajando | Pérdida de ciencia, daño, rotura, blindaje |
| Falla de componente | Reiniciar o seguir sin él | Rotura/reparación; la redundancia lo evita |
| Oportunidad científica (cometa) | Maniobrar gastando 100 m/s o dejar pasar | Multiplicador ×3 de datos ese turno |
| La órbita se desvía | Corregir gastando 150 m/s o aceptar la deriva | Multiplicador ×0.7 en el resto de la misión |
| Impacto de micrometeorito | Gastar batería para reparar o ignorar | Daño a la salud y consumo de batería |

Tipos de efecto soportados: `salud`, `sin_ciencia_turnos`, `multiplicador_datos`, `multiplicador_datos_resto`, `delta_v`, `bateria`, `romper`, `reparar`, `probabilidad`, `blindable`, más `requisitos.delta_v`.

### 4.4 Frases del informe

Hay textos para fallo por masa, fallo de cohete, falta de delta-v, nave perdida, ciencia entregada, transmisión baja/óptima, datos perdidos, apagones, frío, respaldo salvador, presupuesto excedido/sobrante y salud baja. Incluyen variantes `_uno` para cantidades de 1.

## 5. Reglas y fórmulas

Los **5 medidores** del diseño se recalculan en vivo:

1. **Presupuesto:** costo total (cohete + base + piezas) ≤ presupuesto de la misión.
2. **Masa:** masa seca + combustible ≤ capacidad del cohete × `factor_capacidad`.
3. **Energía:** consumo de todo + calefacción ≤ generación.
4. **Datos:** datos de los instrumentos ≤ tasa de antena / `factor_datos`.
5. **Delta-v:** `Isp × 9.81 × ln(masa_total / masa_seca)` ≥ delta-v requerido.

Otras fórmulas y reglas activas:

- **Energía solar:** `potencia / distancia_UA²`. El RTG no depende de la distancia.
- **Fiabilidad de la nave:** producto de fiabilidades, mejorado por redundancia: `1 − (1 − fiabilidad) × reduccion_fallo`.
- **Lanzamiento:** se resuelve en orden **masa → tirada de fiabilidad del cohete → delta-v**. Se puede lanzar con medidores en rojo; las consecuencias llegan después.
- **Operaciones:** cada turno hay `generación + batería` disponible. Los sistemas básicos (50 W) siempre consumen. Si el plan no entra, se apagan primero los instrumentos que más consumen, después la transmisión y al final la calefacción.
- **Apagón:** si la energía no alcanza ni para los sistemas básicos, se pierde toda la batería y la nave sufre 15 puntos de daño.
- **Frío:** cada turno sin calefacción resta `dano_frio` a la salud.
- **Datos:** los instrumentos llenan la memoria (150). Lo que no entra se pierde. La ciencia solo cuenta al **transmitir**; una antena rota transmite al 10%.
- **Eventos:** algunos dependen de un componente instalado y pueden ser evitados por la redundancia o mitigados por el blindaje.
- **Fin de partida:** tras 8 turnos o cuando la salud llega a 0 ("contacto perdido").

## 6. Puntaje e informe

| Componente | Fórmula / tope |
|---|---|
| Ciencia | `min(ciencia / objetivo, 1.5) × 600` → hasta **900** puntos |
| Salud | `salud × 2` → hasta **200** puntos |
| Presupuesto | Ahorrar suma hasta **+200**; pasarse resta hasta **−600** |
| Puntaje total | Suma de los tres, nunca negativo |

| Nota | Umbral |
|---|---|
| Misión legendaria | ≥ 850 |
| Misión exitosa | ≥ 650 |
| Éxito parcial | ≥ 400 |
| Misión con problemas | < 400 |
| Contacto perdido | Llegó, pero la salud llegó a 0 |
| Misión perdida | No superó el lanzamiento |

El informe muestra además ciencia, presupuesto usado, salud final, datos captados/enviados/perdidos, delta-v de reserva y la lista de piezas a bordo.

## 7. Experiencia 3D y navegación

- **Cabina en primera persona** (`scenes/cabina/`): lugar principal. Antes del lanzamiento la nave está sobre la plataforma y por la ventana se ve la torre. Después del lanzamiento está en órbita y se ve el planeta de destino.
- **Cuatro consolas** con pantallas 3D que muestran datos en vivo: computadora de misión, energía, comunicaciones y ciencia. Se apunta con la mirada y se interactúa con **E** o clic.
- **HUD:** mira central, indicación contextual de consola, objetivo actual, mensajes y barra de progreso para mantener E.
- **Sala 2 / Habitáculo** (`scenes/sala_dos/`): sala cuadrada con cama, refrigerador, lockers, ventana panorámica y compuerta. La **ventana** está sobre la cama, en la pared este, y en la pared sur hay una **tercera puerta decorativa** ("Módulo 03"), sellada y sin interacción, que anticipa una sala futura. Es **decorativa**, sin interacción; se entra y sale manteniendo **E** en la puerta norte. No afecta la lógica de la misión.
- **Lanzamiento cinematográfico:** 5 planos (general con cuenta regresiva, motores, despegue, seguimiento con teleobjetivo y ascenso), bandas negras de cine, humo, llama, temblor y cámara en mano. Si falla por masa, el cohete tiembla y no sube; si falla por fiabilidad, explota en el seguimiento.
- **Nave modular:** las piezas elegidas se prenden y apagan por nombre en `nave.glb`; algunas van plegadas durante el lanzamiento.

## 8. Controles

| Acción | Tecla |
|---|---|
| Caminar | WASD o flechas |
| Mirar | Mouse |
| Usar consola / interactuar | E o clic izquierdo |
| Mantener para cambiar de sala | E (1,1 s) |
| Cerrar pantalla / soltar mouse | Esc |
| Saltar cinemática | Espacio, Enter o Esc |
| Terminar turno | Enter |

No hay mapa de acciones configurado en `project.godot`: se leen teclas físicas directamente.

## 9. Arquitectura y estructura

- **Fuente única de verdad:** `GameState` (`scripts/autoload/game_state.gd`) guarda misión, selección, medidores, lanzamiento, operaciones, plan e informe, y hace **todas** las cuentas.
- **Señales:** `mision_cambiada`, `seleccion_cambiada`, `medidores_cambiados`, `plan_cambiado`, `turno_iniciado`, `turno_terminado`. Las pantallas solo leen y reaccionan.
- **Contenido data-driven:** agregar o balancear piezas, misiones, eventos o frases solo requiere editar `data/datos.json`.

| Ruta | Rol |
|---|---|
| `data/datos.json` | Misiones, piezas, eventos, frases y parámetros de partida |
| `scripts/autoload/game_state.gd` | Estado global, fórmulas, turnos, eventos, puntaje y navegación |
| `scripts/ui/interfaz.gd` | Colores y widgets compartidos (tema provisorio) |
| `scripts/nave_3d.gd` | Nave modular: muestra u oculta piezas por id |
| `scenes/cabina/` | Cabina, jugador en primera persona y HUD |
| `scenes/briefing/`, `diseno/`, `operaciones/`, `informe/` | Las 4 pantallas de interfaz |
| `scenes/lanzamiento/` | Cinemática 3D |
| `scenes/sala_dos/` | Habitáculo decorativo |
| `blender/generar_modelos.py` | Genera los 4 GLB y `sabertech.blend` |
| `tests/` | Pruebas headless y recorrido automático con capturas |
| `addons/godot_ai_bridge/` | Puente WebSocket para inspección/automatización en vivo |

Cada escena `.tscn` es intencionalmente mínima: casi toda la construcción es por código, para evitar conflictos de Git.

## 10. Estado del arte

- **3D:** low-poly con colores planos, generado por script. Sin texturas, sin estilo N64 final.
- **UI:** tema provisorio basado en la paleta acordada (azul noche `#0B1030`, aqua `#2EC4E6`, cian `#8FE3FF`, lima `#8EDB4F`, blanco `#F2F7FA`, naranja de alerta `#FF8A2B`), con paneles planos y barras. Aún no hay arte glossy / Frutiger Aero ni íconos.
- **Audio:** no implementado (sin música ni efectos).
- **Cinemática:** funcional con humo, llama, explosión y cámara, pero con geometría y materiales provisorios.

## 11. Pruebas y verificación

| Herramienta | Qué cubre |
|---|---|
| `tests/test_game_state.gd` | Datos, fórmulas (Tsiolkovsky, solar/RTG), selección, medidores, lanzamiento, operaciones, eventos, informe y una simulación de balance de 200 partidas por nave |
| `tests/recorrido.tscn` | Juega una partida completa, valida la mirada inicial y el caminar derecho, y guarda capturas de cada pantalla y de cada plano de la cinemática |

```bash
# Pruebas de lógica
godot --headless --path . -s res://tests/test_game_state.gd

# Recorrido completo con capturas
godot --path . res://tests/recorrido.tscn
```

Las capturas quedan en `user://capturas` (en Windows, dentro de `%APPDATA%\Godot\app_userdata\Sabertech - Misión Espacial\capturas`).

## 12. Qué está dentro del alcance (hoy)

- Partida completa de 5 fases con reinicio, rediseño y elección de otra misión.
- 3 misiones balanceadas, 17 piezas, 5 eventos y 8 turnos de operaciones.
- 5 medidores en vivo, lanzamiento con 3 causas de fallo y operaciones con energía, datos, memoria, ciencia, salud y delta-v.
- Informe con puntaje, nota y frases explicativas.
- Cabina 3D en primera persona con 4 consolas interactivas y pantallas con datos en vivo.
- Cinemática de lanzamiento con finales distintos según el fallo.
- Habitáculo decorativo conectado por compuerta, con puerta sellada al futuro Módulo 03.
- Automatización y pruebas: headless, recorrido con capturas y bridge WebSocket.

## 13. Fuera del alcance / no implementado

- **Arte final:** texturas N64, íconos, paneles Frutiger Aero, planetas texturizados y fondos definitivos.
- **Audio:** música, ambiente, voces y efectos de sonido.
- **Persistencia:** guardado/carga de partida, récords o progresión.
- **Menú principal, ajustes, pausa y opciones gráficas.**
- **Localización** (solo español) y soporte de **gamepad**.
- **Accesibilidad:** remapeo de teclas, subtítulos configurables, opciones de daltonismo.
- **Tutorial guiado:** solo hay ayudas contextuales en pantalla.
- **Vuelo/operación en tiempo real:** el lanzamiento es una cinemática y las operaciones son por turnos.
- **Multijugador o modo cooperativo.**
- **Uso jugable del Habitáculo:** cama, refrigerador, lockers y la puerta del Módulo 03 son decorativos.
- **Exportación a web/móvil/consolas** y pipeline de build.
- **Balance definitivo:** los valores están calibrados con simulación, pero falta validarlos jugando en equipo.

## 14. Limitaciones conocidas y próximos pasos

Limitaciones actuales:

- El arte es provisorio y los modelos no tienen texturas.
- No hay sonido, lo que resta impacto a la cinemática.
- La curva de dificultad y los textos pueden necesitar ajustes tras varias partidas reales.
- El Habitáculo no aporta jugabilidad; hoy es una demostración de ambiente.
- No hay guardado: cerrar el juego pierde la partida.

Próximos pasos sugeridos (en orden):

1. Jugar varias partidas en equipo y anotar qué aburre, confunde o se siente injusto.
2. Ajustar números y reglas en `data/datos.json` sin tocar código.
3. Aplicar texturas N64 generadas con IA sobre los modelos actuales, manteniendo los nombres de nodos.
4. Integrar el tema de UI definitivo y los íconos.
5. Sumar audio y una pantalla de menú/ajustes si el tiempo lo permite.
6. Repetir el recorrido automático y las pruebas headless tras cada cambio.

## 15. Cómo ejecutar

1. Abrir `project.godot` con Godot 4.6 o superior.
2. Ejecutar con **F5**: arranca en la cabina, en primera persona.
3. En la computadora de misión: elegir misión → diseñar → lanzar.
4. Tras el lanzamiento, usar cualquier consola para operar los 8 turnos.
5. Al terminar, leer el informe.

Cada escena también se puede abrir sola desde el editor con **F6**; las pantallas arman datos de prueba si hace falta.
