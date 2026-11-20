shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
// Acqua del fiume: la forma viene dalla maschera ricavata dal disegno (canale rosso),
// con increspature leggere; dove c'è il velo (pedine, segni) l'acqua si fa da parte.
uniform sampler2D maschere : filter_linear, repeat_disable;
uniform sampler2D velo : filter_linear, repeat_disable;

void fragment() {
	float a = smoothstep(0.25, 0.6, texture(maschere, UV).r);
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float onda = sin(p.x * 9.0 + TIME * 1.6) * 0.5 + sin(p.y * 11.0 - TIME * 1.2) * 0.5;
	ALBEDO = mix(vec3(0.15, 0.40, 0.53), vec3(0.30, 0.60, 0.70), 0.5 + 0.25 * onda);
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	ALPHA = a * 0.8 * (1.0 - texture(velo, UV).a);
}
