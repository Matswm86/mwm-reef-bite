// MWM Reef Bite: granite boulders (own work): grey with soft mottling, kelp
// holdfast tint at the base, caustics on top faces.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

#include "res://shaders/rb_caustics.gdshaderinc"

uniform vec4 rock_a : source_color = vec4(0.42, 0.43, 0.42, 1.0);
uniform vec4 rock_b : source_color = vec4(0.27, 0.29, 0.29, 1.0);
uniform vec4 moss : source_color = vec4(0.30, 0.27, 0.12, 1.0);

varying vec3 wp;
varying float wup;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wup = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	float n = vnoise(wp * 3.0) * 0.6 + vnoise(wp * 9.0) * 0.4;
	vec3 c = mix(rock_b.rgb, rock_a.rgb, n);
	c = mix(c, moss.rgb, smoothstep(0.3, 0.9, wup) * 0.45 * vnoise(wp * 1.7));
	float ca = rb_caustic(wp.xz, TIME);
	c *= 1.0 + ca * 0.5 * clamp(wup, 0.0, 1.0);
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
}
