// MWM Reef Bite water surface seen from below (DESIGN 10), adapted 2026-10-10
// from the studio's stylized_water.gdshader: cull_front (the plane is seen
// from underneath), depth foam stays off; realistic values come from the
// material (sparkles and ripples off).
// Original header:
// Stylized toon water for Godot 4.6 (Mobile / Compatibility renderer).
//
// Ported from "stylized-components" by Christian Ortiz (Cortiz), MIT licence,
// https://github.com/cortiz2894/stylized-components (commit 1cece0a):
// waterFloor (Voronoi F1 - SmoothF1 cel water, ripple rings, distance fade),
// WaterDepthIntersection (line + glow where geometry cuts the surface) and
// WaterSparkles (star glints, here procedural instead of point particles).
// Full licence text: LICENSE-stylized-components.txt next to this file.
// What changed vs the source and why: README.md next to this file.
//
// Depth foam: uncomment the define under shader_type to read the depth texture. On the
// Mobile renderer that forces a depth copy every frame (bandwidth on tile GPUs,
// too much for 32-bit tablets), so it is OFF by default. With it off, foam rings
// come from the cheap `floaters` uniform array (circles fed by script).
// A uniform bool cannot switch this: the cost comes from the texture being in
// the shader at all, so it is a compile-time switch.

shader_type spatial;
// #define WATER_DEPTH_FOAM
render_mode unshaded, blend_mix, cull_front, shadows_disabled, specular_disabled;

#define MAX_RIPPLES 8
#define MAX_RINGS 4
#define MAX_FLOATERS 8

// ---- Voronoi cel pattern (source defaults from waterFloor/utils/controls.ts)
group_uniforms pattern;
uniform float pattern_scale : hint_range(0.01, 1.5) = 0.23;
uniform float cell_smoothness : hint_range(0.01, 2.0) = 0.46;
uniform float edge_threshold : hint_range(0.0, 0.3) = 0.09;
uniform float edge_softness : hint_range(0.0, 0.1) = 0.1;
uniform vec2 flow = vec2(0.07, -0.23);
uniform float cell_speed : hint_range(0.0, 3.0) = 0.55;
uniform float noise_scale : hint_range(0.1, 10.0) = 0.87;
uniform float noise_flow_speed : hint_range(0.0, 2.0) = 0.11;
uniform float distort_amount : hint_range(0.0, 3.0) = 0.26;

group_uniforms colors;
uniform vec4 deep_color : source_color = vec4(0.153, 0.639, 0.847, 1.0);  // #27a3d8
uniform vec4 mid_color : source_color = vec4(0.349, 0.753, 0.910, 1.0);   // #59c0e8
uniform float mid_pos : hint_range(0.001, 0.999) = 0.31;
uniform vec4 highlight_color : source_color = vec4(1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
// alpha of the cell interiors; 1.0 = solid water (no seabed needed)
uniform float deep_opacity : hint_range(0.0, 1.0) = 0.37;

group_uniforms distance_fade;
uniform float fade_distance : hint_range(10.0, 400.0) = 275.0;
uniform float fade_strength : hint_range(0.1, 5.0) = 1.3;
// 1 = fade alpha to 0 far away (source); 0 = keep alpha, use horizon_mix
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec4 horizon_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float horizon_mix : hint_range(0.0, 1.0) = 0.0;

group_uniforms waves;
// optional vertex swell (not in the source; 0 = flat plane like the source)
uniform float wave_height : hint_range(0.0, 0.5) = 0.0;
uniform float wave_speed : hint_range(0.0, 4.0) = 1.0;

group_uniforms ripples;
// Each vec4: x, z (world), start time (in ripple_now's clock), strength (0-1).
// Script owns the clock: set ripple_now every frame, append rings with z = now.
uniform vec4 ripples[8];
uniform int ripple_count : hint_range(0, 8) = 0;
uniform float ripple_now = 0.0;
uniform float ripple_speed : hint_range(0.1, 10.0) = 1.5;
uniform float ripple_width : hint_range(0.01, 1.0) = 0.12;
uniform float ripple_strength : hint_range(0.0, 10.0) = 5.5;
uniform float ripple_decay : hint_range(0.1, 10.0) = 1.6;
uniform int ripple_rings : hint_range(1, 4) = 2;
uniform float ripple_spacing : hint_range(0.05, 3.0) = 1.0;

group_uniforms intersection_foam;
// source WaterDepthIntersection defaults
uniform float foam_line_width : hint_range(0.01, 3.0) = 0.25;
uniform float foam_glow_width : hint_range(0.1, 10.0) = 1.2;
uniform vec4 foam_line_color : source_color = vec4(1.0);
uniform float foam_line_opacity : hint_range(0.0, 1.0) = 1.0;
uniform vec4 foam_glow_color : source_color = vec4(0.533, 0.8, 1.0, 1.0);  // #88ccff
uniform float foam_glow_opacity : hint_range(0.0, 1.0) = 0.25;
// Fallback when WATER_DEPTH_FOAM is off: circles around floating objects.
// Each vec4: x, z (world), radius at the waterline, strength (0 = unused).
uniform vec4 floaters[8];
uniform int floater_count : hint_range(0, 8) = 0;

group_uniforms sparkles;
// source WaterSparkles look, made procedural: one possible glint per grid cell
uniform float sparkle_cell : hint_range(0.5, 20.0) = 3.0;  // world units per cell
uniform float sparkle_density : hint_range(0.0, 1.0) = 0.35;
uniform float sparkle_size : hint_range(0.01, 0.25) = 0.2;  // star half-size, fraction of a cell
uniform float sparkle_period : hint_range(0.2, 10.0) = 2.4;  // seconds per cycle
uniform vec4 sparkle_color : source_color = vec4(0.898, 0.824, 0.824, 1.0);  // #e5d2d2
uniform float sparkle_intensity : hint_range(0.0, 15.0) = 1.8;
uniform float sparkle_arm_sharpness : hint_range(1.0, 40.0) = 27.0;
uniform float sparkle_arm_falloff : hint_range(0.1, 8.0) = 4.8;
uniform float sparkle_glow_radius : hint_range(0.5, 12.0) = 12.0;
group_uniforms;

#ifdef WATER_DEPTH_FOAM
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
#endif

varying vec2 world_xz;

// sin-free hash (Dave Hoskins): stable at large world coordinates on mobile
// GPUs, where sin(big) loses precision and the pattern breaks into blocks.
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float smin(float a, float b, float k) {
	float h = max(k - abs(a - b), 0.0) / k;
	return min(a, b) - h * h * h * k / 6.0;
}

// F1 - SmoothF1 in one 3x3 pass (the source runs two passes over the same cells)
float voronoi_edge(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float md = 8.0;
	float sd = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 n = vec2(float(x), float(y));
			vec2 pt = 0.5 + 0.5 * sin(TIME * cell_speed + 6.2831 * hash22(i + n));
			float d = length(n + pt - f);
			md = min(md, d);
			sd = smin(sd, d, cell_smoothness);
		}
	}
	return md - sd;
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x),
		f.y);
}

float fbm2(vec2 p) {
	return 0.5 * vnoise(p) + 0.25 * vnoise(p * 2.0);
}

// line + glow from a distance to the intersection (source WaterDepthIntersection)
vec2 foam_terms(float diff) {
	float line = 1.0 - smoothstep(0.0, foam_line_width, diff);
	float glow = exp(-diff / max(foam_glow_width, 0.001));
	return vec2(line, glow);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_xz = wp.xz;
	if (wave_height > 0.0) {
		float t = TIME * wave_speed;
		VERTEX.y += wave_height * (sin(wp.x * 0.35 + t * 1.1) + 0.7 * sin(wp.z * 0.45 + t * 0.8));
	}
}

void fragment() {
	// noise-distorted, flowing Voronoi
	vec2 distort = vec2(fbm2(world_xz * noise_scale + vec2(TIME * noise_flow_speed, 0.0)) - 0.5) * distort_amount;
	vec2 uv = world_xz * pattern_scale + flow * TIME + distort;
	float edge = voronoi_edge(uv);
	float t = smoothstep(edge_threshold - edge_softness, edge_threshold + edge_softness, edge);

	// 3-stop ramp deep -> mid -> highlight
	float mp = max(mid_pos, 1e-4);
	float seg0 = clamp(t / mp, 0.0, 1.0);
	float seg1 = clamp((t - mp) / max(1.0 - mp, 1e-4), 0.0, 1.0);
	vec3 color = mix(mix(deep_color.rgb, mid_color.rgb, seg0), mix(mid_color.rgb, highlight_color.rgb, seg1), step(mp, t));

	// ripple rings: dynamic loops, dead ripples skipped early
	float acc = 0.0;
	float life = float(ripple_rings - 1) * ripple_spacing + 4.6 / ripple_decay;
	for (int i = 0; i < MAX_RIPPLES; i++) {
		if (i >= ripple_count) {
			break;
		}
		vec4 r = ripples[i];
		float elapsed = ripple_now - r.z;
		if (elapsed < 0.0 || elapsed > life || r.w <= 0.0) {
			continue;
		}
		float d = length(world_xz - r.xy);
		for (int k = 0; k < MAX_RINGS; k++) {
			float re = elapsed - float(k) * ripple_spacing;
			if (k >= ripple_rings || re < 0.0) {
				break;
			}
			float ring = 1.0 - smoothstep(0.0, ripple_width, abs(d - re * ripple_speed));
			acc += ring * exp(-re * ripple_decay) * r.w;
		}
	}
	float ripple = clamp(acc * ripple_strength, 0.0, 1.0);
	color = mix(color, highlight_color.rgb, ripple);

	float alpha = mix(deep_opacity, 1.0, max(t, ripple));

	// intersection foam
	vec2 foam = vec2(0.0);
#ifdef WATER_DEPTH_FOAM
	float raw = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, raw) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float scene_d = -view.z / view.w;
	foam = foam_terms(abs(scene_d - (-VERTEX.z)));
#else
	for (int i = 0; i < MAX_FLOATERS; i++) {
		if (i >= floater_count) {
			break;
		}
		vec4 fl = floaters[i];
		if (fl.w <= 0.0) {
			continue;
		}
		float diff = max(length(world_xz - fl.xy) - fl.z, 0.0);
		foam = max(foam, foam_terms(diff) * fl.w);
	}
#endif
	float line_a = foam.x * foam_line_opacity;
	float glow_a = foam.y * foam_glow_opacity;
	color = mix(color, foam_glow_color.rgb, glow_a);
	color = mix(color, foam_line_color.rgb, line_a);
	alpha = max(alpha, max(line_a, glow_a));

	// distance fade
	float far = pow(clamp(length(world_xz - CAMERA_POSITION_WORLD.xz) / fade_distance, 0.0, 1.0), fade_strength);

	// sparkles: one candidate glint per cell, re-rolled every cycle
	if (sparkle_density > 0.0 && sparkle_intensity > 0.0) {
		vec2 sp = world_xz / sparkle_cell;
		vec2 cell = floor(sp);
		float ph = hash12(cell + 71.3);
		float cyc = TIME / sparkle_period + ph;
		float id = floor(cyc);
		if (hash12(cell + id * 13.7) < sparkle_density) {
			vec2 c = 0.25 + 0.5 * hash22(cell + id * 7.1);
			vec2 q = (fract(sp) - c) / sparkle_size;
			float h_arm = exp(-abs(q.y) * sparkle_arm_sharpness) * exp(-abs(q.x) * sparkle_arm_falloff);
			float v_arm = exp(-abs(q.x) * sparkle_arm_sharpness) * exp(-abs(q.y) * sparkle_arm_falloff);
			float star = max(max(h_arm, v_arm), exp(-length(q) * sparkle_glow_radius));
			float fade_in_out = sin(fract(cyc) * PI);
			float s = star * fade_in_out * (1.0 - far);
			color += sparkle_color.rgb * sparkle_intensity * s;
			alpha = max(alpha, clamp(s, 0.0, 1.0));
		}
	}

	color = mix(color, horizon_color.rgb, far * horizon_mix);
	ALBEDO = color;
	ALPHA = clamp(alpha * opacity * (1.0 - far * fade_alpha), 0.0, 1.0);
}
