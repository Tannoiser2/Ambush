shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
// Acqua del fiume: la forma viene dalla maschera ricavata dal disegno (canale rosso). Increspature procedurali che scorrono
// (normali da rumore a più ottave), colore che passa dal bordo basso e torbido al centro profondo, riflesso del cielo con
// effetto Fresnel, schiuma leggera lungo le sponde e scintillii contenuti. Dove c'è il velo (pedine, segni) l'acqua si fa da parte.
uniform sampler2D maschere : filter_linear, repeat_disable;
uniform sampler2D velo : filter_linear, repeat_disable;
uniform sampler2D luce_mask : filter_linear, repeat_disable;
// 1 = ruscello ghiacciato (Missione 11): ghiaccio opaco, senza onde.
uniform float ghiaccio = 0.0;
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
float onde(vec2 p, float t) {
	float v = 0.0;
	float a = 0.5;
	vec2 flusso = vec2(0.35, 0.12) * t;
	for (int i = 0; i < 4; i++) {
		v += a * rumore(p + flusso * (1.0 + float(i) * 0.6));
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// un respiro leggerissimo della superficie
	VERTEX.y += (1.0 - ghiaccio) * 0.006 * sin(mondo.x * 3.0 + TIME * 1.3) * sin(mondo.z * 2.6 - TIME);
}

void fragment() {
	float raw = texture(maschere, UV).r;
	float a = smoothstep(0.25, 0.6, raw);
	vec2 p = mondo.xz * 6.0;
	float t = TIME;
	// normali dalle derivate del rumore
	float e = 0.08;
	float h0 = onde(p, t);
	float hx = onde(p + vec2(e, 0.0), t);
	float hz = onde(p + vec2(0.0, e), t);
	vec3 n_mondo = normalize(vec3((h0 - hx) * 4.5, 1.0, (h0 - hz) * 4.5));
	vec3 n_vista = normalize((VIEW_MATRIX * vec4(n_mondo, 0.0)).xyz);
	NORMAL = mix(n_vista, NORMAL, ghiaccio);
	// profondità apparente: il centro del corso d'acqua è più scuro e verde-blu, le sponde più chiare e torbide
	float prof = smoothstep(0.45, 0.95, raw);
	vec3 basso = vec3(0.30, 0.42, 0.40);
	vec3 fondo = vec3(0.06, 0.20, 0.27);
	vec3 col = mix(basso, fondo, prof);
	// riflesso del cielo con Fresnel
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 4.0);
	vec3 cielo = mix(vec3(0.55, 0.62, 0.66), vec3(0.10, 0.13, 0.20), notte);
	col = mix(col, cielo, fres * 0.55);
	// increspature visibili: creste più chiare, avvallamenti più scuri, filamenti che seguono la corrente
	col *= 0.86 + (h0 - 0.5) * 0.55;
	float filo = smoothstep(0.62, 0.7, onde(p * vec2(0.6, 2.4) + vec2(t * 0.6, 0.0), t));
	col = mix(col, cielo * 1.1, filo * 0.18 * (1.0 - ghiaccio));
	// schiuma lungo le sponde, spezzata dal rumore
	float bordo = smoothstep(0.25, 0.4, raw) * (1.0 - smoothstep(0.4, 0.55, raw));
	float sch = bordo * smoothstep(0.55, 0.8, onde(p * 1.7 + 4.0, t * 1.4));
	col = mix(col, vec3(0.74, 0.77, 0.74), sch * 0.3 * (1.0 - ghiaccio));
	// notte e nebbia
	float vis = texture(luce_mask, UV).r;
	col *= mix(1.0, mix(0.35, 0.85, vis), notte);
	col = mix(col, mix(vec3(0.60, 0.62, 0.60), vec3(0.14, 0.17, 0.24), notte), nebbia * 0.35);
	vec3 gelo = mix(vec3(0.72, 0.80, 0.84), vec3(0.80, 0.86, 0.88), 0.5 + 0.5 * sin(mondo.x * 23.0 + mondo.z * 17.0));
	ALBEDO = mix(col, gelo, ghiaccio);
	ROUGHNESS = mix(0.06, 0.45, ghiaccio);
	METALLIC = 0.0;
	SPECULAR = mix(0.55, 0.35, ghiaccio);
	// bengala riflessi
	EMISSION = vec3(1.0, 0.8, 0.5) * texture(luce_mask, UV).g * 0.12 * notte;
	ALPHA = a * mix(mix(0.78, 0.9, prof), 0.92, ghiaccio) * (1.0 - texture(velo, UV).a);
}
