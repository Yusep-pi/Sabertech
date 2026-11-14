// Material de los modelos con textura: N64 con terminación moderna.
// - Proyección triplanar (los modelos no tienen coordenadas de mapeado), con
//   píxel nítido. La textura crece con el objeto: la nave agrandada de la caminata
//   tiene píxeles más grandes, como en N64.
// - Relieve con el mapa _normal generado por arte/generar_relieves.py.
// - Variación suave de tono y desgaste que no repite: rompe el patrón de mosaico.
// Lo aplica el autoload Estilo a cada material que tenga textura.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D textura : source_color, filter_nearest, repeat_enable;
uniform sampler2D relieve : hint_normal, filter_nearest, repeat_enable;
uniform bool con_relieve = false;
uniform float repeticiones = 0.5;  // repeticiones por metro
uniform float fuerza_relieve = 1.0;
uniform float rugosidad = 0.75;
uniform float metalico = 0.0;
uniform float variacion = 0.14;  // cuánto cambia el tono de una zona a otra
uniform float tamano_variacion = 3.0;  // metros que ocupa cada mancha
uniform float desgaste = 0.12;  // oscurecimiento irregular, como suciedad o uso
uniform float otra_escala = 0.0;  // en superficies grandes: cuánto se mezcla una segunda lectura a otra escala

varying vec3 posicion;
varying vec3 normal_objeto;

void vertex() {
	posicion = VERTEX;
	normal_objeto = NORMAL;
}

float azar(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Ruido de valor 3D: manchas suaves sin patrón.
float ruido(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(azar(i), azar(i + vec3(1, 0, 0)), f.x), mix(azar(i + vec3(0, 1, 0)), azar(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(azar(i + vec3(0, 0, 1)), azar(i + vec3(1, 0, 1)), f.x), mix(azar(i + vec3(0, 1, 1)), azar(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	vec3 n = normalize(normal_objeto);
	vec3 pesos = pow(abs(n), vec3(4.0));
	pesos /= pesos.x + pesos.y + pesos.z;
	vec3 lado = sign(n);
	vec3 p = posicion * repeticiones;

	// Cada eje proyecta la textura sobre las caras que lo miran (sin espejarla en las caras opuestas).
	vec2 uv_x = vec2(p.z * lado.x, p.y);
	vec2 uv_y = vec2(p.x * lado.y, p.z);
	vec2 uv_z = vec2(-p.x * lado.z, p.y);
	vec3 color = texture(textura, uv_x).rgb * pesos.x + texture(textura, uv_y).rgb * pesos.y + texture(textura, uv_z).rgb * pesos.z;
	if (otra_escala > 0.0) {
		// Una segunda lectura más grande y corrida, mezclada por manchas: el mosaico deja de notarse.
		vec3 q = posicion * repeticiones * 0.31 + vec3(0.37, 0.0, 0.71);
		vec3 grande = texture(textura, vec2(q.z * lado.x, q.y)).rgb * pesos.x
			+ texture(textura, vec2(q.x * lado.y, q.z)).rgb * pesos.y
			+ texture(textura, vec2(-q.x * lado.z, q.y)).rgb * pesos.z;
		float zona = smoothstep(0.3, 0.7, ruido(posicion / (tamano_variacion * 0.7) + 5.0));
		color = mix(color, grande, zona * otra_escala);
	}

	// Variación de tono en manchas grandes y desgaste en manchas más chicas.
	float mancha = ruido(posicion / tamano_variacion);
	float uso = ruido(posicion / (tamano_variacion * 0.35) + 17.0);
	color *= 1.0 + (mancha - 0.5) * 2.0 * variacion;
	color *= 1.0 - smoothstep(0.55, 0.95, uso) * desgaste;
	ALBEDO = color;
	ROUGHNESS = clamp(rugosidad + (uso - 0.5) * 0.2, 0.0, 1.0);
	METALLIC = metalico;

	if (con_relieve) {
		// Relieve triplanar con la mezcla "whiteout" (Ben Golus).
		vec3 rx = texture(relieve, uv_x).rgb * 2.0 - 1.0;
		vec3 ry = texture(relieve, uv_y).rgb * 2.0 - 1.0;
		vec3 rz = texture(relieve, uv_z).rgb * 2.0 - 1.0;
		rx.xy *= fuerza_relieve; ry.xy *= fuerza_relieve; rz.xy *= fuerza_relieve;
		rx.x *= lado.x; ry.x *= lado.y; rz.x *= -lado.z;
		rx = vec3(rx.xy + n.zy, abs(rx.z) * n.x);
		ry = vec3(ry.xy + n.xz, abs(ry.z) * n.y);
		rz = vec3(rz.xy + n.xy, abs(rz.z) * n.z);
		vec3 normal_final = normalize(rx.zyx * pesos.x + ry.xzy * pesos.y + rz.xyz * pesos.z);
		NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(normal_final, 0.0)).xyz);
	}
}
