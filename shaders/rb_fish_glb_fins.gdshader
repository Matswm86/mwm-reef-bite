// MWM Reef Bite: fin surface of the sculpted fish (alpha blend, double sided,
// light through the membrane). Same code as rb_fish_glb.gdshader. Vertex code from the graphic
// designer's assets/models/fish/README.md (COLOR_0: R jaw, G fin flare,
// B swim bend), compile-tested and fixed here; plus the game's caustics,
// growth flash and gentle-restart dim. `rim` is per instance so the player
// gets a stronger sun rim than the other fish (DESIGN 4).
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;
#define FINS

#include "res://shaders/rb_caustics.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform bool use_normal_map = true;
uniform float rim_tint_k : hint_range(0.0, 1.0) = 0.6;
uniform float caustic_on_fish : hint_range(0.0, 0.5) = 0.25;

instance uniform float mouth : hint_range(0.0, 1.0) = 0.0;
instance uniform float flare : hint_range(0.0, 1.0) = 0.0;
instance uniform float phase = 0.0;
instance uniform float swim_hz = 2.5;
instance uniform float swim_amp = 1.0;
instance uniform float flash : hint_range(0.0, 1.0) = 0.0;
instance uniform float tint_dim : hint_range(0.0, 1.0) = 0.0;
instance uniform float rim : hint_range(0.0, 1.0) = 0.15;

varying vec3 world_pos;
varying float world_up;

void vertex() {
	float bend = COLOR.b * COLOR.b;
	VERTEX.z += sin(TIME * swim_hz * TAU + phase + VERTEX.x * 5.5) * 0.06 * bend * swim_amp;
	VERTEX.y -= mouth * COLOR.r * 0.10 * clamp((VERTEX.x - 0.33) / 0.09, 0.0, 1.0);
	VERTEX.y += flare * COLOR.g * 0.025 * (VERTEX.y >= 0.0 ? 1.0 : -1.0);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	vec3 c = a.rgb * orm.r;
	float ca = rb_caustic(world_pos.xz * 1.6 + vec2(world_pos.y * 0.3, 0.0), TIME);
	c *= 1.0 + ca * caustic_on_fish * clamp(world_up, 0.0, 1.0);
	c *= 1.0 - tint_dim * 0.6;
	ALBEDO = c;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	if (use_normal_map) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	SPECULAR = 0.6;
	RIM = rim;
	RIM_TINT = rim_tint_k;
	EMISSION = c * flash * 0.55;
#ifdef FINS
	ALPHA = a.a;
	BACKLIGHT = a.rgb * 0.6;
#endif
#ifdef SCISSOR
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
#endif
}
