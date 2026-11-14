// Contornos en aristas y siluetas, como en los juegos retro bien terminados.
// Compara la profundidad y la orientación de cada píxel con sus vecinos: donde
// cambian de golpe hay un borde, y se pinta una línea fina azul noche.
// El autoload Estilo lo pone delante de cada cámara, en un cuadro que cubre la pantalla.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
uniform sampler2D profundidad : hint_depth_texture, filter_nearest;
uniform sampler2D normales : hint_normal_roughness_texture, filter_nearest;
uniform vec3 color_linea : source_color = vec3(0.02, 0.03, 0.09);
uniform float intensidad = 0.95;
uniform float umbral_profundidad = 0.06;  // salto relativo de distancia que cuenta como silueta
uniform float umbral_normal = 0.5;  // cambio de orientación que cuenta como arista
uniform float distancia_desvanecer = 220.0;  // más lejos que esto, las líneas se apagan
uniform float grosor = 2.0;  // en píxeles: con el filtro retro, menos de 2 se pierde

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float distancia(vec2 uv, mat4 proyeccion_inversa) {
	float d = texture(profundidad, uv).r;
	vec4 punto = proyeccion_inversa * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -punto.z / punto.w;
}

vec3 normal_en(vec2 uv) {
	return normalize(texture(normales, uv).xyz * 2.0 - 1.0);
}

void fragment() {
	vec2 paso = grosor / VIEWPORT_SIZE;
	float centro = distancia(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 normal = normal_en(SCREEN_UV);
	float borde = 0.0;
	vec2 vecinos[4] = vec2[](vec2(paso.x, 0.0), vec2(-paso.x, 0.0), vec2(0.0, paso.y), vec2(0.0, -paso.y));
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + vecinos[i];
		float otra = distancia(uv, INV_PROJECTION_MATRIX);
		// Solo el lado más cercano dibuja la silueta: la línea queda sobre el objeto, no sobre el fondo.
		if (otra - centro > centro * umbral_profundidad) {
			borde = 1.0;
		}
		if (1.0 - dot(normal, normal_en(uv)) > umbral_normal) {
			borde = max(borde, 0.7);
		}
	}
	borde *= 1.0 - smoothstep(distancia_desvanecer * 0.5, distancia_desvanecer, centro);
	vec3 color = texture(pantalla, SCREEN_UV).rgb;
	ALBEDO = mix(color, color_linea, borde * intensidad);
}
