// MWM Reef Bite: sea floor (DESIGN 10). Poly Haven coast_sand_01 (CC0)
// albedo + normal, gentle dunes, caustics (<= 1.6x), darker toward depth.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://shaders/rb_caustics.gdshaderinc"

uniform sampler2D sand_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.32;
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.55;
uniform vec4 tint : source_color = vec4(0.86, 0.84, 0.74, 1.0);
uniform vec4 deep_tint : source_color = vec4(0.06, 0.33, 0.42, 1.0);
uniform float dune_height = 0.18;

varying vec3 wp;

float h2(vec2 p) {
	return sin(p.x * 0.45 + sin(p.y * 0.21) * 1.7) * 0.6 + sin(p.y * 0.33 + p.x * 0.12) * 0.4;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float lane = smoothstep(0.0, 6.0, abs(w.x));
	VERTEX.y += h2(w.xz) * dune_height * (0.4 + lane) * smoothstep(-1.0, -6.0, w.z);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wp.xz * uv_scale;
	vec3 a = texture(sand_albedo, uv).rgb * tint.rgb;
	float ca = rb_caustic(wp.xz, TIME);
	a *= 1.0 + ca * caustic_strength * 1.1;
	float far = smoothstep(4.0, 26.0, -wp.z);
	a = mix(a, a * deep_tint.rgb * 2.2, far * 0.5);
	ALBEDO = a;
	NORMAL_MAP = texture(sand_normal, uv).rgb;
	NORMAL_MAP_DEPTH = 0.6;
	ROUGHNESS = 0.95;
}
