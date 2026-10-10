// MWM Reef Bite: shared caustic light (DESIGN 10). Two scrolling samples of
// the own tileable caustic texture, min() blended so the bright lines wander
// like real caustics. Period well over 2 s, low contrast (rule 38).
uniform sampler2D caustic_tex : filter_linear_mipmap, repeat_enable;
uniform float caustic_scale = 0.55;
uniform float caustic_speed = 0.035;
// 0 = frozen ("Mindre bevegelse").
uniform float caustic_motion = 1.0;

float rb_caustic(vec2 p, float t) {
	float tt = t * caustic_speed * caustic_motion;
	vec2 a = p * caustic_scale + vec2(tt, tt * 0.6);
	vec2 b = p * caustic_scale * 1.27 + vec2(-tt * 0.8, tt * 0.9) + vec2(0.37, 0.11);
	return min(texture(caustic_tex, a).r, texture(caustic_tex, b).r);
}
