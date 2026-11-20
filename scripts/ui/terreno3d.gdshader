shader_type spatial;
// Terreno 3D: la mappa disegnata stesa sul rilievo, con sopra il velo delle pedine e dei segni.
uniform sampler2D mappa : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D velo : source_color, filter_linear, repeat_disable;

void fragment() {
	vec3 m = texture(mappa, UV).rgb;
	vec4 o = texture(velo, UV);
	// il velo è disegnato su fondo trasparente: colori già moltiplicati per l'alfa
	ALBEDO = m * vec3(0.74, 0.74, 0.70) * (1.0 - o.a) + o.rgb;
	EMISSION = o.rgb * 0.18;
	ROUGHNESS = 0.93;
	SPECULAR = 0.2;
}
