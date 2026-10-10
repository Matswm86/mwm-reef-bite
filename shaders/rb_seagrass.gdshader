// MWM Reef Bite seagrass: the studio stylized_grass.gdshader unchanged; the
// realistic seagrass palette comes from the material (DESIGN 10).
// Stylized grass blades for MultiMeshInstance3D, Godot 4.6 (Mobile renderer).
//
// Ported from "stylized-components" by Christian Ortiz (Cortiz), MIT licence,
// https://github.com/cortiz2894/stylized-components (commit 1cece0a):
// grassField blade shader (wind with a squared height mask, base-to-tip colour
// gradient, lush/dry patch noise, flattened +Y lighting normal, back-lit
// translucency). Full licence text: LICENSE-stylized-components.txt next to
// this file. What changed vs the source and why: README.md next to this file.
//
// Mesh contract (same as the source): one blade in local space, base at y = 0,
// tip at y = 1, flat in XY, about 1 unit wide at the base. The MultiMesh
// instance transform scales it to a real blade (e.g. 0.06 x 0.25 x 1) and gives
// it a random Y rotation. Wind is applied in world space, so blades with random
// rotations still lean together.

shader_type spatial;
render_mode cull_disabled, specular_disabled, world_vertex_coords;

group_uniforms wind;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.1;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.3;
uniform float wind_freq : hint_range(0.01, 3.0) = 0.4;
uniform float wind_turbulence : hint_range(0.0, 1.0) = 0.3;
uniform float wind_lean : hint_range(0.0, 1.0) = 0.5;
uniform vec2 wind_dir = vec2(1.0, 0.0);

group_uniforms colors;
uniform vec4 color_bottom : source_color = vec4(0.310, 0.486, 0.075, 1.0);  // #4f7c13
uniform vec4 color_top : source_color = vec4(0.475, 0.627, 0.110, 1.0);     // #79a01c
uniform float brightness : hint_range(0.0, 2.0) = 0.8;
uniform float grad_start : hint_range(0.0, 1.0) = 0.15;
uniform float grad_end : hint_range(0.0, 1.0) = 1.0;
uniform float grad_power : hint_range(0.1, 4.0) = 1.6;
// ground blending: the blade root takes the ground colour so it melts into the
// terrain mesh instead of showing a hard line where it meets it
uniform vec4 ground_color : source_color = vec4(0.310, 0.486, 0.075, 1.0);
uniform float ground_blend : hint_range(0.0, 1.0) = 0.0;
uniform float ground_blend_height : hint_range(0.01, 1.0) = 0.25;

group_uniforms patches;
uniform vec4 patch_lush : source_color = vec4(0.435, 0.604, 0.165, 1.0);  // #6f9a2a
uniform vec4 patch_dry : source_color = vec4(0.722, 0.663, 0.306, 1.0);   // #b8a94e
uniform float patch_strength : hint_range(0.0, 1.0) = 0.35;
uniform float patch_scale : hint_range(0.01, 2.0) = 0.15;
uniform float patch_bias : hint_range(0.1, 4.0) = 1.6;

group_uniforms translucency;
uniform vec4 trans_color : source_color = vec4(0.757, 0.898, 0.302, 1.0);  // #c1e54d
uniform float trans_strength : hint_range(0.0, 5.0) = 2.5;
uniform float trans_power : hint_range(0.5, 10.0) = 3.0;
uniform float trans_tip : hint_range(0.0, 1.0) = 0.6;
uniform float trans_shadow : hint_range(0.0, 1.0) = 1.0;

group_uniforms lighting;
uniform bool receive_shadow = true;
group_uniforms;

varying float blade_h;     // 0 base .. 1 tip
varying float blade_patch; // lush/dry noise at the blade base, one value per blade
varying vec3 blade_n;      // the blade's real facing, view space (for translucency)

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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

void vertex() {
	// with world_vertex_coords, VERTEX/NORMAL arrive in world space here (the
	// MultiMesh instance transform is part of MODEL_MATRIX). Local height =
	// projection on the instance's scaled Y axis: no per-vertex matrix inverse.
	vec3 base = MODEL_MATRIX[3].xyz;
	vec3 up_axis = MODEL_MATRIX[1].xyz;
	float h = clamp(dot(VERTEX - base, up_axis) / max(dot(up_axis, up_axis), 1e-6), 0.0, 1.0);
	blade_h = h;
	blade_patch = 0.65 * vnoise(base.xz * patch_scale) + 0.35 * vnoise(base.xz * patch_scale * 2.0);

	float mask = h * h;
	vec2 wd = normalize(wind_dir + vec2(1e-5, 0.0));
	vec2 perp = vec2(-wd.y, wd.x);
	float ph = dot(VERTEX.xz, wd) * wind_freq;
	float primary = sin(ph + TIME * wind_speed);
	float second = sin(ph * 2.6 + TIME * wind_speed * 1.8 + 1.3) * 0.35;
	float turb = sin(dot(VERTEX.xz, perp) * wind_freq * 1.9 + TIME * wind_speed * 0.7 + 2.6) * wind_turbulence;
	float push = ((primary + second + turb) * wind_strength + wind_lean * wind_strength) * mask;
	// scale by blade length so short and long blades bend by the same angle
	float len = length(MODEL_MATRIX[1].xyz);
	VERTEX.xz += wd * push * len;
	VERTEX.y -= abs(push) * len * 0.3 * mask;

	blade_n = normalize((VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float g = clamp((blade_h - grad_start) / max(grad_end - grad_start, 0.001), 0.0, 1.0);
	vec3 c = mix(color_bottom.rgb, color_top.rgb, pow(g, grad_power));
	float pt = pow(clamp(blade_patch, 0.0, 1.0), patch_bias);
	c = mix(c, mix(patch_lush.rgb, patch_dry.rgb, pt), patch_strength);
	c *= brightness;
	c = mix(c, ground_color.rgb, ground_blend * (1.0 - smoothstep(0.0, ground_blend_height, blade_h)));
	ALBEDO = c;
	// every blade shades with an up normal so the field does not shimmer as
	// randomly turned blades catch the sun differently (source trick)
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

void light() {
	float att = receive_shadow ? ATTENUATION : 1.0;
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += ndl * att * LIGHT_COLOR / PI;
	// back-lit translucency: brightest looking into the sun through thin tips,
	// for blades seen edge-on to the light; added on top, not tinted by albedo
	float back = pow(max(dot(VIEW, -LIGHT), 0.0), trans_power);
	float thin = mix(1.0, blade_h, trans_tip);
	float edge = 1.0 - abs(dot(blade_n, LIGHT));
	float sh = mix(1.0, att, trans_shadow);
	SPECULAR_LIGHT += trans_color.rgb * trans_strength * back * thin * edge * sh * LIGHT_COLOR / PI;
}
