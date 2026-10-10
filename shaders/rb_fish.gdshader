// MWM Reef Bite: proxy fish material (own work). Vertex colour = species
// albedo and pattern. Vertex shader: lateral swim bend rising toward the
// tail, jaw opening (cue 4.3) from the mouth mask in UV.x, fin flare from
// UV.y. Fragment: wet spec, sun rim, caustics on the back (<= 1.3x).
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

#include "res://shaders/rb_caustics.gdshaderinc"

uniform float metallic_k : hint_range(0.0, 1.0) = 0.35;
uniform float roughness_k : hint_range(0.0, 1.0) = 0.34;
instance uniform float rim : hint_range(0.0, 1.0) = 0.3;
uniform float rim_tint_k : hint_range(0.0, 1.0) = 0.6;
uniform float caustic_on_fish : hint_range(0.0, 0.5) = 0.28;

instance uniform float mouth : hint_range(0.0, 1.0) = 0.0;
instance uniform float flare : hint_range(0.0, 1.0) = 0.0;
instance uniform float phase = 0.0;
instance uniform float swim_hz = 2.5;
instance uniform float swim_amp = 1.0;
instance uniform float flash : hint_range(0.0, 1.0) = 0.0;
instance uniform float tint_dim : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;
varying float world_up;
varying vec3 lp;
varying vec2 kind;

const vec3 BAR_INK = vec3(0.133, 0.114, 0.063);

float fh(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float fnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(fh(i), fh(i + vec2(1.0, 0.0)), f.x), mix(fh(i + vec2(0.0, 1.0)), fh(i + vec2(1.0, 1.0)), f.x), f.y);
}

float spots(vec2 p, float cell, float r) {
	vec2 g = floor(p / cell);
	vec2 o = vec2(fh(g), fh(g + 7.3)) * 0.6 + 0.2;
	return smoothstep(r, r * 0.6, length(p / cell - g - o));
}

void vertex() {
	// Local space: nose at +0.5, tail at -0.5 (length 1), back at +y.
	float x = VERTEX.x;
	float tail_w = smoothstep(0.25, -0.55, x);
	float wave = sin(TIME * swim_hz * 6.2831 + phase - x * 5.0);
	VERTEX.z += wave * 0.07 * tail_w * tail_w * swim_amp;
	// Jaw: the lower lip (mouth mask) drops, hinged behind the snout.
	float m = UV.x;
	VERTEX.y -= mouth * m * 0.11 * smoothstep(0.30, 0.5, x);
	VERTEX.x -= mouth * m * 0.015;
	// Fin flare: fin vertices (UV.y) spread outward from the body.
	VERTEX.y += flare * UV.y * 0.04 * sign(VERTEX.y);
	lp = VERTEX;
	kind = UV2;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float pat = kind.x;
	if (kind.y < 0.5) {
		if (pat > 0.5 && pat < 1.5) {
			// Player: five narrow vertical bars (DESIGN 4), only the player has them.
			float bars = 0.0;
			for (int i = 0; i < 5; i++) {
				float cx = 0.31 - float(i) * 0.125;
				bars = max(bars, smoothstep(0.024, 0.017, abs(lp.x - cx)));
			}
			c = mix(c, BAR_INK, bars * 0.9);
		} else if (pat > 1.5 && pat < 2.5) {
			c *= 0.72 + 0.4 * fnoise(lp.xy * vec2(18.0, 22.0));
		} else if (pat > 2.5 && pat < 3.5) {
			c = mix(c, vec3(0.88, 0.9, 0.86), smoothstep(0.007, 0.002, abs(lp.y - 0.01 - 0.02 * sin(lp.x * 4.0))) * 0.6);
		} else if (pat > 3.5 && pat < 4.5) {
			c *= 1.0 - 0.35 * spots(lp.xy, 0.05, 0.32);
		} else if (pat > 4.5 && pat < 5.5) {
			c *= 0.75 + 0.35 * fnoise(lp.xy * vec2(26.0, 30.0));
			c = mix(c, vec3(0.9, 0.88, 0.8), smoothstep(0.006, 0.002, abs(lp.y - 0.015 - 0.015 * sin(lp.x * 5.0))) * 0.7);
		} else if (pat > 5.5) {
			c *= 1.0 - 0.6 * spots(lp.xy, 0.04, 0.22) * step(0.0, lp.y);
		}
	}
	float up = clamp(world_up, 0.0, 1.0);
	float ca = rb_caustic(world_pos.xz * 1.6 + vec2(world_pos.y * 0.3, 0.0), TIME);
	c *= 1.0 + ca * caustic_on_fish * up;
	c *= 1.0 - tint_dim * 0.6;
	ALBEDO = c;
	METALLIC = metallic_k * COLOR.a;
	ROUGHNESS = roughness_k;
	SPECULAR = 0.6;
	RIM = rim;
	RIM_TINT = rim_tint_k;
	EMISSION = c * flash * 0.55;
}
