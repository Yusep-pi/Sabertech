// Distorsión de pantalla de las alucinaciones: ondulación, visión doble, un tinte
// que late y bordes que respiran. intensidad va de 0 (nada) a 1 (cordura en cero).
// Lo aplica el autoload Alucinaciones por debajo de la interfaz.
shader_type canvas_item;

uniform sampler2D pantalla : hint_screen_texture, filter_linear;
uniform float intensidad : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float t = TIME;
	vec2 uv = SCREEN_UV;
	// Ondas lentas, cada vez más fuertes.
	vec2 onda = vec2(sin(uv.y * 11.0 + t * 1.9), cos(uv.x * 9.0 + t * 1.5)) * 0.007 * intensidad;
	uv += onda;
	vec3 color = texture(pantalla, uv).rgb;
	// Visión doble que va y viene.
	vec2 doble = vec2(sin(t * 0.8), cos(t * 0.6)) * 0.014 * intensidad * intensidad;
	color = mix(color, texture(pantalla, uv + doble).rgb, 0.35 * intensidad);
	// Tinte violeta y cian que late.
	float latido = 0.5 + 0.5 * sin(t * 2.3);
	vec3 tinte = mix(vec3(0.55, 0.3, 0.9), vec3(0.2, 0.85, 0.95), latido);
	color = mix(color, color * tinte * 1.5, 0.22 * intensidad);
	// Los bordes se oscurecen y respiran.
	vec2 desde_centro = SCREEN_UV - 0.5;
	float borde = smoothstep(0.25, 0.75, length(desde_centro) * (1.2 + 0.15 * sin(t * 1.3)));
	color *= 1.0 - borde * 0.65 * intensidad;
	COLOR = vec4(color, 1.0);
}
