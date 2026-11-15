// Filtro retro de pantalla completa: color con menos niveles y tramado ordenado
// (como el de la N64), una aberración cromática leve hacia los bordes, como un
// lente, viñeta y un grano sutil. Con tamano_pixel mayor a 1 además agranda los
// píxeles (modo "Retro fuerte").
// Lo aplica el autoload Estilo por debajo de la interfaz, que queda nítida.
shader_type canvas_item;

uniform sampler2D pantalla : hint_screen_texture, filter_linear;
uniform float tamano_pixel = 1.0;
uniform float niveles = 40.0;
uniform float tramado = 0.6;
uniform float vineta = 0.22;
uniform float grano = 0.025;
uniform float aberracion = 0.0015;  // separación de los canales de color en el borde de la pantalla

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
	vec2 desde_centro = SCREEN_UV - 0.5;
	// El rojo y el azul se corren un poco hacia afuera, más cuanto más lejos del centro.
	vec2 corrimiento = desde_centro * dot(desde_centro, desde_centro) * aberracion * 8.0;
	vec3 color = vec3(
		texture(pantalla, centro + corrimiento).r,
		texture(pantalla, centro).g,
		texture(pantalla, centro - corrimiento).b);

	float umbral = (bayer(celda) - 0.5) * tramado;
	color = floor(color * niveles + 0.5 + umbral) / niveles;

	color *= 1.0 - dot(desde_centro, desde_centro) * vineta * 2.0;
	float ruido = fract(sin(dot(celda + floor(TIME * 24.0), vec2(12.9898, 78.233))) * 43758.5453);
	color += (ruido - 0.5) * grano;

	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
