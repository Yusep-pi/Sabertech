// Filtro retro de pantalla completa: píxeles más grandes, menos niveles de
// color con tramado ordenado (como el de la N64), viñeta y un grano sutil.
// Lo aplica el autoload Estilo por debajo de la interfaz, que queda nítida.
shader_type canvas_item;

uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
uniform float tamano_pixel = 2.0;
uniform float niveles = 40.0;
uniform float tramado = 0.6;
uniform float vineta = 0.22;
uniform float grano = 0.025;

// Matriz de Bayer 4x4: el umbral del tramado para cada píxel.
float bayer(vec2 celda) {
	int x = int(mod(celda.x, 4.0));
	int y = int(mod(celda.y, 4.0));
	int indice = x + y * 4;
	int matriz[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(matriz[indice]) / 16.0;
}

void fragment() {
	vec2 celda = floor(FRAGCOORD.xy / tamano_pixel);
	vec2 centro = (celda + 0.5) * tamano_pixel * SCREEN_PIXEL_SIZE;
	vec3 color = texture(pantalla, centro).rgb;

	float umbral = (bayer(celda) - 0.5) * tramado;
	color = floor(color * niveles + 0.5 + umbral) / niveles;

	vec2 desde_centro = SCREEN_UV - 0.5;
	color *= 1.0 - dot(desde_centro, desde_centro) * vineta * 2.0;
	float ruido = fract(sin(dot(celda + floor(TIME * 24.0), vec2(12.9898, 78.233))) * 43758.5453);
	color += (ruido - 0.5) * grano;

	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
