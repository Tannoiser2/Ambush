shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
// Acqua del fiume: la forma viene dalla maschera ricavata dal disegno (canale rosso),
// con increspature leggere; dove c'è il velo (pedine, segni) l'acqua si fa da parte.
uniform sampler2D maschere : filter_linear, repeat_disable;
uniform sampler2D velo : filter_linear, repeat_disable;
// 1 = ruscello ghiacciato (Missione 11): ghiaccio opaco, senza onde.
uniform float ghiaccio = 0.0;

void fragment() {
	float a = smoothstep(0.25, 0.6, texture(maschere, UV).r);
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float onda = sin(p.x * 9.0 + TIME * 1.6) * 0.5 + sin(p.y * 11.0 - TIME * 1.2) * 0.5;
	ALBEDO = mix(vec3(0.15, 0.40, 0.53), vec3(0.30, 0.60, 0.70), 0.5 + 0.25 * onda);
	vec3 gelo = mix(vec3(0.72, 0.80, 0.84), vec3(0.80, 0.86, 0.88), 0.5 + 0.5 * sin(p.x * 23.0 + p.y * 17.0));
	ALBEDO = mix(ALBEDO, gelo, ghiaccio);
	ROUGHNESS = mix(0.12, 0.45, ghiaccio);
	SPECULAR = mix(0.7, 0.35, ghiaccio);
	ALPHA = a * mix(0.8, 0.92, ghiaccio) * (1.0 - texture(velo, UV).a);
}
