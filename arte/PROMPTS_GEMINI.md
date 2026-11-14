# Prompts para Gemini: texturas y mapas

Cada imagen de esta lista ya tiene un lugar en el juego. Si el archivo se guarda con el **nombre exacto** de la tabla en `assets/texturas/`, el juego lo aplica solo. No hace falta tocar código ni modelos.

## Cómo trabajar

1. Abrir **una sola conversación** en Gemini y pegar primero el bloque de estilo. Todas las imágenes salen de esa misma conversación, para que combinen.
2. Pedir las imágenes de a una, con su prompt.
3. Si una sale bien, usarla de referencia para las siguientes: "Mantené el mismo estilo que la imagen anterior".
4. Descargar en el tamaño más grande que dé Gemini y guardarla con el nombre de la tabla. **No hace falta achicarlas:** las reduzco yo a 128 o 256 px y reviso que repitan bien.
5. Pasarme la carpeta con todo.

### Qué revisar antes de descargar

- **Sin texto, letras, números, logos ni marcas de agua.** Todo lo que se lee lo pone el juego.
- **Las texturas repetibles no tienen que mostrar costuras:** el borde izquierdo continúa en el derecho y el de arriba en el de abajo.
- **Vista de frente y luz pareja:** sin sombras marcadas ni perspectiva.

## Bloque de estilo (pegar siempre primero)

```
STYLE GUIDE — apply to every image in this conversation:
Art direction: late-90s Nintendo 64 era game textures, clean and optimistic
retro-futurism (not gritty, not horror, not dirty). Hand-painted look with
simple shapes, soft color banding and slightly chunky pixels, as if a
128x128 texture had been upscaled. Readable from far away.
Palette (strict): deep space navy #0B1030, aqua #2EC4E6, sky cyan #8FE3FF,
lime green #8EDB4F, clean white #F2F7FA, warning orange #FF8A2B used
sparingly, plus neutral greys.
Lighting: flat, even, diffuse. No baked shadows, no strong highlights, no
perspective, no vignette, no lens effects.
Never include text, letters, numbers, logos, watermarks or UI labels.
```

## Texturas repetibles (materiales de los modelos)

Formato: **cuadrada 1:1, repetible por los cuatro lados**, vista de frente. Cada una reemplaza a un color plano de los modelos.

| Archivo | Dónde se ve |
|---|---|
| `casco.png` | Casco blanco de la nave, los cohetes y el traje |
| `casco_gris.png` | Marcos, brazos y estructuras gris claro |
| `oscuro.png` | Consolas, torre de lanzamiento, motores, marcos oscuros |
| `celda.png` | Paneles solares |
| `dorado.png` | Lámina térmica dorada (blindaje) |
| `pared.png` | Paredes y techo de la cabina y la esclusa |
| `piso.png` | Piso de la cabina y la esclusa |
| `concreto.png` | Plataforma de lanzamiento |
| `suelo.png` | Terreno alrededor de la plataforma |

Prompt base (cambiar solo el `Subject`):

```
Generate a seamless tileable texture, square 1:1, front-facing orthographic
view, filling the entire frame edge to edge with no border. Edges must match
perfectly when repeated horizontally and vertically. Follow the style guide.
Subject: [ver abajo]
```

Subject de cada una:

- **casco.png:** `clean white spacecraft hull plating, large rectangular panels with thin light-grey seams, a few small rivets and one tiny aqua stripe accent, very light and bright overall`
- **casco_gris.png:** `light grey brushed metal plating with simple horizontal seams and small bolts, neutral and subtle`
- **oscuro.png:** `dark navy painted metal panel with a fine grid of bolts and a few small vent slits, low contrast so it stays dark`
- **celda.png:** `solar panel cells, a regular grid of deep blue square photovoltaic cells with thin silver lines between them, slight cyan sheen, 4 by 4 cells`
- **dorado.png:** `crinkled gold thermal insulation foil (multi-layer insulation) as used on spacecraft, soft folds, warm gold and amber tones`
- **pared.png:** `interior wall of a friendly spaceship module, off-white rounded padded panels with thin grey seams and a small aqua indicator light, clean and calm`
- **piso.png:** `spaceship interior floor, dark navy anti-slip rubber tiles with a subtle diamond tread pattern and thin cyan seams`
- **concreto.png:** `launch pad concrete slab, light grey concrete squares with expansion joints, very faint scorch marks, clean not dirty`
- **suelo.png:** `flat dry grassland seen from above, muted grey-green grass with a few lighter patches, no objects, very low detail`

## Mapas de planetas

Formato: **2:1 equirectangular**, para envolver una esfera. Los bordes izquierdo y derecho tienen que coincidir.

| Archivo | Dónde se ve |
|---|---|
| `planeta_tierra.png` | La Tierra, desde la cabina en órbita, la esclusa y la caminata |
| `planeta_luna.png` | La Luna, en la misión lunar |
| `planeta_marte.png` | Marte, en la misión a Marte |

```
Generate an equirectangular (2:1) surface map of [SUBJECT], for wrapping
around a sphere. No stars, no atmosphere glow, no shadows, surface only,
left and right edges must match. Follow the style guide.
```

- **planeta_tierra.png:** `planet Earth: deep blue oceans, simplified green and sandy continents with soft edges, white polar caps and a few soft white cloud bands`
- **planeta_luna.png:** `the Moon: light grey surface with darker grey maria and a few simple round craters`
- **planeta_marte.png:** `planet Mars: rusty orange-red surface with darker brown regions, a few canyons and small white polar caps`

## Fondo del espacio

| Archivo | Dónde se ve |
|---|---|
| `fondo_espacio.png` | Todo lo que pasa en el espacio: órbita, esclusa y caminata |

```
Generate a seamless equirectangular 2:1 space panorama: deep navy background
#0B1030, sparse small stars, one soft aqua-violet nebula on one side and a
faint band of distant stars. Low detail, low contrast, so foreground objects
stay readable. Left and right edges must match. Follow the style guide.
```

## Más adelante (no urgente)

Estos no se aplican solos todavía; los integro cuando lleguen.

- **Íconos de la interfaz** (`iconos.png`): hoja de 8 íconos en 4x2 sobre fondo magenta #FF00FF, estilo Frutiger Aero: batería, masa, presupuesto, antena, combustible, instrumento, cohete y órbita. Prompt completo en [CONTEXTO.md](../CONTEXTO.md).
- **Panel de interfaz** (`panel_ui.png`): marco de vidrio aqua con centro azul noche, sobre magenta, pensado para cortarse en 9 partes. También en [CONTEXTO.md](../CONTEXTO.md).
