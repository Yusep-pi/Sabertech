// La bandera del Paraguay: tres franjas horizontales (roja, blanca y azul) y el
// escudo en el centro (anillo rojo, corona verde y la estrella amarilla).
// La tela tiene las arrugas de las banderas de las Apollo, que colgaban de un
// travesaño, y se mece cuando se la clava: en la Luna no hay viento, solo el
// impulso, que se va apagando. La anima scenes/superficie/superficie.gd.
shader_type spatial;
render_mode cull_disabled;

uniform float ancho = 1.3;
uniform float alto = 0.72;
uniform float vaiven = 0.0;  // metros que se mece la punta
uniform float fase = 0.0;
uniform vec3 rojo : source_color = vec3(0.835, 0.169, 0.118);
uniform vec3 blanco : source_color = vec3(0.96, 0.96, 0.94);
uniform vec3 azul : source_color = vec3(0.0, 0.22, 0.659);
uniform vec3 verde : source_color = vec3(0.12, 0.5, 0.24);
uniform vec3 amarillo : source_color = vec3(0.98, 0.82, 0.1);

// Cuánto se sale la tela del plano a lo largo (u: 0 en el mástil, 1 en la punta).
float desplazamiento(float u) {
	float arrugas = sin(u * 13.0 + 0.6) * 0.018 + sin(u * 5.0) * 0.012;
	float mece = sin(u * 4.0 - fase) * vaiven;
	return (arrugas + mece) * u;
}

void vertex() {
	float u = UV.x;
	VERTEX.z += desplazamiento(u);
	float pendiente = (desplazamiento(u + 0.01) - desplazamiento(u)) / (0.01 * ancho);
	NORMAL = normalize(vec3(-pendiente, 0.0, 1.0));
}

void fragment() {
	// Franjas de arriba abajo.
	vec3 color = UV.y < 1.0 / 3.0 ? rojo : (UV.y < 2.0 / 3.0 ? blanco : azul);
	// El escudo, en metros desde el centro de la tela.
	vec2 p = (UV - 0.5) * vec2(ancho, -alto);
	float r = length(p);
	if (r < 0.1) {
		color = blanco;
		if (r > 0.086) {
			color = rojo;
		} else if (r > 0.058 && r < 0.074) {
			color = verde;
		}
		// Estrella de cinco puntas, con una punta hacia arriba.
		float angulo = atan(p.x, p.y);
		float radio_estrella = mix(0.014, 0.036, pow(abs(cos(2.5 * angulo)), 3.0));
		if (r < radio_estrella) {
			color = amarillo;
		}
	}
	ALBEDO = color;
	ROUGHNESS = 0.85;
}
