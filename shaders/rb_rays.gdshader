// MWM Reef Bite: god rays (DESIGN 10): <= 4 additive cards in one mesh,
// shafts made in the shader (no texture), top-to-bottom fade, slow sway
// +-2 degrees over 8 s. "Mindre bevegelse": static. Own work.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 ray_color : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform float strength = 0.16;
uniform float motion = 1.0;
uniform float fade_in = 1.0;

varying float seed;

float h1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	seed = COLOR.r;
	float sway = sin(TIME * 0.785 + seed * 6.0) * 0.035 * motion;
	VERTEX.x += sway * (UV.y) * 6.0;
}

void fragment() {
	float x = UV.x;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float c = 0.12 + 0.19 * fi + (h1(seed * 7.0 + fi) - 0.5) * 0.08;
		float w = 0.018 + 0.035 * h1(seed * 3.0 + fi * 1.3);
		float flick = 0.75 + 0.25 * sin(TIME * (0.25 + 0.1 * fi) * motion + fi * 2.0 + seed * 9.0);
		s += smoothstep(w, 0.0, abs(x - c)) * (0.5 + 0.5 * h1(seed + fi * 0.7)) * flick;
	}
	float fade = smoothstep(1.0, 0.05, UV.y) * smoothstep(0.0, 0.08, UV.y);
	float edge = smoothstep(0.0, 0.1, x) * smoothstep(1.0, 0.9, x);
	ALBEDO = ray_color.rgb * s * fade * edge * strength * fade_in;
}
