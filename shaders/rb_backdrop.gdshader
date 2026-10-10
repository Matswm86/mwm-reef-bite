// MWM Reef Bite: water behind everything (DESIGN 10): world fog ramp top ->
// mid -> deep by height. Unshaded, no fog. Own work.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never;

uniform vec4 top_color : source_color = vec4(0.2, 0.561, 0.631, 1.0);
uniform vec4 mid_color : source_color = vec4(0.165, 0.408, 0.459, 1.0);
uniform vec4 deep_color : source_color = vec4(0.024, 0.2, 0.278, 1.0);
uniform float top_y = 9.0;
uniform float mid_y = 0.0;
uniform float deep_y = -6.0;

varying float wy;

void vertex() {
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec3 c = mix(mid_color.rgb, top_color.rgb, smoothstep(mid_y, top_y, wy));
	c = mix(c, deep_color.rgb, smoothstep(mid_y, deep_y, wy));
	ALBEDO = c;
}
