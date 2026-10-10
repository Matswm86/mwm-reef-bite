// MWM Reef Bite: far scenery schools (DESIGN 2 size rule): one MultiMesh of
// tiny silver fish, each wiggling and milling around its slot. Never
// interactive, always >= 7 m behind the play plane. Own work.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_disabled;

uniform vec4 back_color : source_color = vec4(0.25, 0.33, 0.38, 1.0);
uniform vec4 belly_color : source_color = vec4(0.78, 0.82, 0.84, 1.0);
uniform float motion = 1.0;

void vertex() {
	float id = INSTANCE_CUSTOM.x;
	float t = TIME * motion;
	VERTEX.z += sin(t * 9.0 + id * 13.0 - VERTEX.x * 7.0) * 0.12 * smoothstep(0.2, -0.5, VERTEX.x);
	vec3 off = vec3(sin(t * 0.31 + id * 5.1), sin(t * 0.43 + id * 3.7) * 0.5, sin(t * 0.27 + id * 2.3)) * 0.35;
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * off);
}

void fragment() {
	ALBEDO = mix(belly_color.rgb, back_color.rgb, smoothstep(-0.02, 0.05, COLOR.g - 0.5));
	METALLIC = 0.5;
	ROUGHNESS = 0.35;
}
