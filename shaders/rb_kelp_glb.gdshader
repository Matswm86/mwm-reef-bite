// MWM Reef Bite: material for the sculpted kelp and seagrass GLBs. Vertex
// code from the graphic designer's assets/models/kelp/README.md (COLOR_0:
// R sway weight, G blade phase, B flutter weight), compile-tested here.
// Alpha scissor (opaque pipeline), light through the blades as BACKLIGHT.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform bool use_normal_map = true;
uniform float strength = 0.06;
uniform float speed = 0.4;
uniform float brightness = 1.0;
uniform float shimmer : hint_range(0.0, 1.0) = 0.0;
// Light through the blades. QA 2026-10-10: the old warm tint (1.1, 0.95,
// 0.65) turned the forest into golden walls that camouflaged the gold
// player (DESIGN 3: the player's gold is the only saturated warm yellow).
uniform vec3 backlight_tint = vec3(0.45, 0.6, 0.55);
// Pull the blade colour toward a cool teal-olive before lighting (0 = the
// atlas colour as painted).
uniform vec4 cool_color : source_color = vec4(0.25, 0.32, 0.26, 1.0);
uniform float cool_mix : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float ph = root.x * 0.7 + root.z * 0.45;
	float h = COLOR.r * COLOR.r;
	VERTEX.x += h * strength * 6.0 * (0.6 + 0.4 * sin(TIME * speed * TAU + ph));
	VERTEX.z += h * strength * 3.0 * sin(TIME * speed * 0.7 * TAU + ph * 1.3);
	VERTEX += NORMAL * COLOR.b * 0.04 * sin(TIME * 1.7 + COLOR.g * TAU + VERTEX.y * 2.0) * (strength / 0.06);
}

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	vec3 base = mix(a.rgb, cool_color.rgb * dot(a.rgb, vec3(0.3, 0.59, 0.11)) * 2.0, cool_mix);
	ALBEDO = base * brightness * orm.r;
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = orm.g;
	if (use_normal_map) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	BACKLIGHT = base * backlight_tint * brightness;
	ALBEDO += vec3(0.25, 0.22, 0.08) * shimmer;
}
