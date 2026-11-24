shader_type spatial;
// Terreno 3D: la mappa disegnata stesa sul rilievo, con sopra il velo delle pedine e dei segni.
// Di notte gli esagoni che la squadra vede restano leggibili e il resto scivola nel buio; i bengala scaldano il terreno;
// con la nebbia il disegno sbiadisce in chiazze che scorrono.
uniform sampler2D mappa : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D velo : source_color, filter_linear, repeat_disable;
uniform sampler2D luce_mask : filter_linear, repeat_disable;
uniform float notte = 0.0;
uniform float nebbia = 0.0;

varying vec3 mondo;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float rumore(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * rumore(p);
		p = p * 2.07 + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 m = texture(mappa, UV).rgb * vec3(0.74, 0.74, 0.70);
	vec4 o = texture(velo, UV);
	vec4 lm = texture(luce_mask, UV);
	// notte: fuori vista il disegno si spegne e si fa bluastro; in vista resta chiaro
	float vis = lm.r;
	vec3 buio = m * vec3(0.30, 0.34, 0.45);
	vec3 col = mix(m, mix(buio, m * vec3(0.92, 0.95, 1.05), vis), notte);
	// nebbia: chiazze lattiginose che scorrono, più rade dove si vede
	float veli = 0.0;
	if (nebbia > 0.001) {
		float n = fbm(mondo.xz * 0.45 + vec2(TIME * 0.02, TIME * 0.008));
		veli = nebbia * smoothstep(0.2, 0.75, n) * mix(0.85, 0.4, vis);
	}
	vec3 colore_nebbia = mix(vec3(0.56, 0.58, 0.58), vec3(0.14, 0.17, 0.24), notte);
	col = mix(col, colore_nebbia, veli);
	// il velo è disegnato su fondo trasparente: colori già moltiplicati per l'alfa
	ALBEDO = col * (1.0 - o.a) + o.rgb;
	// bengala: luce calda sugli esagoni illuminati; in vista di notte un filo di luce propria per leggere la mappa
	vec3 bengala = m * vec3(1.0, 0.82, 0.55) * lm.g * 0.22 * max(notte, 0.35);
	EMISSION = o.rgb * (0.18 + 0.45 * notte) + bengala + m * vis * notte * 0.10;
	ROUGHNESS = 0.93;
	SPECULAR = 0.2;
}
