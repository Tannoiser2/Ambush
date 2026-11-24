shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Nebbia procedurale a strati: rumore frattale che scorre piano, più rada dove la squadra vede e vicino alla camera.
uniform float densita = 0.0;
uniform float strato = 0.0;
uniform vec4 colore : source_color = vec4(0.62, 0.64, 0.62, 1.0);
uniform sampler2D luce_mask : filter_linear, repeat_disable;
uniform vec2 dim = vec2(42.0, 38.4);

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
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = mondo.xz * 0.16 + vec2(strato * 3.7, strato * 1.3);
	vec2 vento = vec2(TIME * 0.018 * (1.0 + strato * 0.4), TIME * 0.007);
	float n = fbm(p + vento + rumore(p * 0.5 - vento) * 0.9);
	n = smoothstep(0.32, 0.85, n);
	// la maschera di luce: dove la squadra vede la nebbia si apre un poco
	vec2 uv = mondo.xz / dim;
	float vis = texture(luce_mask, clamp(uv, vec2(0.0), vec2(1.0))).r;
	float vicino = smoothstep(0.8, 5.0, -VERTEX.z);
	float a = densita * n * (0.55 - strato * 0.08) * mix(1.0, 0.5, vis) * vicino;
	ALBEDO = colore.rgb * (0.9 + 0.2 * n);
	ALPHA = clamp(a, 0.0, 0.6);
}
