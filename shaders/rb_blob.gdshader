// MWM Reef Bite: soft blob shadows under the fish (DESIGN 10: no shadow
// maps). One MultiMesh of flat quads on the floor; INSTANCE_CUSTOM.x = alpha.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

varying float a;

void vertex() {
	a = INSTANCE_CUSTOM.x;
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	ALBEDO = vec3(0.02, 0.08, 0.1);
	ALPHA = smoothstep(1.0, 0.2, d) * a;
}
