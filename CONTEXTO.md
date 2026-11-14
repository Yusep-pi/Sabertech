# Juego de misión espacial — Hackathon

Contexto del proyecto para retomar el desarrollo en una sesión nueva. Todo lo de abajo ya está decidido salvo donde dice "por confirmar".

## Situación

- Equipo de 4 personas. Entrega: domingo 15 de noviembre de 2026 (hora por confirmar).
- Motor: Godot (versión por confirmar, se asume 4.x). Lenguaje: GDScript.
- Meta de hoy (sábado 14): partida completa jugable de punta a punta. Mañana solo errores, pulido y demo.

## El challenge (texto original)

> Designing a space mission requires careful consideration of competing demands, including mission objectives, spacecraft design, scientific instruments, launch vehicles, budgets, power, mass, communications, and orbital constraints. For students who rarely get to experiment with an entire mission from concept to operation, these trade-offs often remain abstract. Your challenge is to create an interactive game that allows participants to design, manage, and simulate a complete space mission while making engineering decisions, managing limited resources, and evaluating how each choice shapes the success of their mission.

## Concepto

Simulador de director de misión en 5 fases, 10-15 minutos por partida. El jugador elige una misión, arma la nave con presupuesto limitado, la lanza, la opera por turnos y recibe un informe que explica por qué le fue como le fue. El informe final es la parte que más responde al challenge.

## Fases

1. **Briefing.** Elegir 1 de 3 misiones (funcionan como dificultad). Cada una define presupuesto, objetivo científico, delta-v requerido y distancia.
   - Satélite de observación en órbita terrestre (fácil: cerca, mucho sol).
   - Orbitador lunar (medio).
   - Orbitador a Marte (difícil: poco sol, comunicación débil, mucho combustible).
2. **Diseño (corazón del juego).** Elegir piezas por categoría mientras 5 medidores se actualizan en vivo. Nave 3D low-poly girando en el centro; las piezas aparecen al elegirlas. Se puede lanzar con medidores en rojo; las consecuencias llegan después.
3. **Lanzamiento.** Animación corta y tirada según la fiabilidad del cohete. Si la masa excede la capacidad o falta delta-v, la misión falla acá, con explicación.
4. **Operaciones.** 8 turnos. En cada uno se reparte la energía entre instrumentos, transmisión y calefacción. La ciencia solo cuenta si se transmite. En 2-3 turnos cae un evento con decisión (tormenta solar, falla de componente, oportunidad científica).
5. **Informe final.** Puntaje por ciencia entregada, presupuesto sobrante y estado de la nave, más 3-4 frases generadas según lo ocurrido (ej.: "Tu antena solo pudo transmitir el 40% de lo que captó el radar").

## Piezas

| Categoría | Opciones (3 c/u) | Trade-off |
|---|---|---|
| Cohete | chico / mediano / pesado | capacidad de carga vs costo vs fiabilidad |
| Energía | panel chico / panel grande / RTG | potencia vs masa vs costo (paneles rinden menos lejos del sol) |
| Comunicación | antena de baja / media / alta ganancia | datos por turno vs masa y consumo |
| Propulsión | químico / eficiente / iónico | delta-v vs masa vs consumo eléctrico |
| Instrumentos | cámara, espectrómetro, radar (se pueden llevar varios) | ciencia vs masa, energía y datos |
| Extras | redundancia, blindaje | menos riesgo vs más masa y costo |

Los valores numéricos de cada pieza aún no están cargados (los define el rol de contenido, basados en valores reales simplificados).

## Los 5 medidores

1. Costo / presupuesto
2. Masa / capacidad del cohete
3. Energía generada / consumida
4. Datos generados / transmitibles
5. Delta-v disponible / requerido

## Fórmulas

- **Delta-v:** `dv = Isp * 9.81 * ln(masa_inicial / masa_final)`
- **Energía solar:** potencia del panel / (distancia al sol en UA)^2. En Marte rinde ~43%. El RTG no depende de la distancia.
- **Datos:** tasa de la antena / factor fijo por misión.
- **Fiabilidad:** producto de las fiabilidades de las piezas; la redundancia la sube.

## Arquitectura acordada

- Todas las piezas y misiones en un solo archivo de datos (JSON o Resources), para balancear sin tocar código. Campos de pieza: `id`, `categoria`, `nombre`, `costo`, `masa`, `potencia`, `fiabilidad` y los específicos de cada categoría.
- Un único autoload `GameState`: guarda misión elegida, piezas y resultados; calcula los medidores y emite señales. La UI solo lee de ahí; nadie más calcula.
- Una escena por pantalla y un dueño por escena, para evitar conflictos de Git en los `.tscn`.

## Reparto del equipo

| Rol | Hace | Entrega primero |
|---|---|---|
| 1. Lógica | Datos, fórmulas, medidores, turnos, eventos, puntaje | `GameState` con medidores calculando bien |
| 2. Interfaz | Las 5 pantallas y el flujo, empezando por diseño | Pantalla de diseño conectada a datos de prueba |
| 3. Arte | Texturas en Gemini, nave modular low-poly, planetas, fondo, tema de UI, animación de lanzamiento | Nave con piezas separadas que se prenden/apagan + tema de UI |
| 4. Contenido y pitch | Números de piezas, textos de misiones, eventos, frases del informe, balance, presentación | Tabla de piezas completa en la primera hora |

## Hitos de hoy

1. Mediodía: medidores funcionando en la pantalla de diseño con UI fea.
2. Media tarde: partida completa jugable sin arte.
3. Noche: arte integrado, eventos y frases cargados, 3 misiones balanceadas.

## Orden de recortes si falta tiempo

Extras (redundancia y blindaje) → tercera misión → animación de lanzamiento → eventos (dejar 2). No se cortan la pantalla de diseño con medidores ni el informe final.

## Dirección de arte

Low-poly estilo N64 limpio para el 3D; Frutiger Aero contenido solo para la interfaz. Tono optimista y educativo, no sombrío.

- Sin temblor de vértices, sin dithering fuerte, sin paleta sucia tipo PSX.
- Texturas de 128-256 px, filtro Nearest, sin mipmaps.
- UI: paneles glossy aqua/verde/blanco sobre azul noche, con datos planos y de alto contraste. Sin reflejos ni burbujas sobre los números.
- Texto y números siempre desde Godot, nunca dentro de imágenes generadas.
- Paleta: azul noche `#0B1030`, aqua `#2EC4E6`, cian `#8FE3FF`, verde lima `#8EDB4F`, blanco `#F2F7FA`, naranja de alerta `#FF8A2B` (solo alertas).

### Prompts para Gemini

Bloque de estilo (siempre al inicio de la conversación):

```
STYLE GUIDE — apply to every image in this conversation:
Art direction: late-90s Nintendo 64 era low-poly game asset style, clean and
optimistic retro-futurism (not gritty, not horror). Hand-painted low-resolution
texture look, soft color banding, simple shapes, slightly chunky pixels, as if
a 128x128 texture was upscaled.
Palette (strict): deep space navy #0B1030, aqua #2EC4E6, sky cyan #8FE3FF,
lime green #8EDB4F, clean white #F2F7FA, warning orange #FF8A2B used sparingly.
Lighting: flat, even, diffuse. No baked shadows, no strong highlights, no
perspective, no vignette.
Never include text, letters, numbers, logos, watermarks or UI labels.
```

Texturas tileables:

```
Generate a seamless tileable texture, square 1:1, front-facing orthographic
view, filling the entire frame edge to edge with no border.
Subject: [spacecraft hull metal panels with rivets / gold thermal foil /
blue solar panel cells / lunar regolith / launch pad concrete].
Edges must match perfectly when repeated horizontally and vertically.
Follow the style guide.
```

Planetas y lunas:

```
Generate an equirectangular (2:1) surface map of [a rocky red planet / an icy
moon / a gas giant with bands], for wrapping around a sphere. No stars, no
atmosphere glow, no shadows, surface only, left and right edges must match.
Follow the style guide.
```

Fondo espacial:

```
Generate a seamless equirectangular 2:1 space panorama: deep navy background,
sparse small stars, one soft aqua-violet nebula. Low detail, low contrast,
so foreground objects stay readable. Follow the style guide.
```

Íconos de UI:

```
Generate a sprite sheet of [8] game icons in a 4x2 grid, evenly spaced, on a
solid flat magenta #FF00FF background. Style: Frutiger Aero, glossy glass
buttons with soft top highlight, rounded shapes, aqua and lime gradients,
white simple pictogram in the center of each.
Icons: [battery/power, mass/weight, budget/coin, antenna/communications,
fuel, science instrument, rocket launch, orbit].
Thick clean silhouettes readable at 32x32 pixels. No text.
```

Paneles de UI:

```
Generate a glossy Frutiger Aero UI panel frame, rounded rectangle, translucent
aqua glass with a soft white highlight on top and a thin bright border, empty
flat dark-navy center area for data. Solid magenta #FF00FF background,
front view, no text. Designed to be sliced as a 9-patch.
```

Notas: generar en grande y reducir a 128/256 px; probar cada textura repetida 2x2; quitar el magenta con color key; generar todo en la misma conversación y usar los assets buenos como referencia.

## Siguiente paso

Construir la base que destraba al resto del equipo, en este orden:

1. Archivo de datos con piezas y misiones (valores provisorios razonables hasta que contenido entregue la tabla).
2. Autoload `GameState` con las fórmulas, los 5 medidores y señales de cambio.
3. Pantalla de diseño mínima (UI sin arte) para probar los medidores.
