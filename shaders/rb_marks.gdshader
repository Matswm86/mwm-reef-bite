// MWM Reef Bite: every game mark in one MultiMesh draw (DESIGN 5): edible
// bubble ring, danger zigzag ring (morphing between them), aim ring, glass
// bubbles, the Bobla shield and power-up bubble, the immunity shimmer.
// White + ink only, so the shapes read in greyscale (rule 36). Drawn on top
// of the fish, under the HUD. Own work.
// INSTANCE_CUSTOM: x = kind, y = morph (danger 1 .. edible 0) or seed,
// z = alpha, w = half size of the quad in design px.
// Kinds: 0 ring (edible/danger by morph), 2 aim, 3 bubble, 4 shield,
// 5 power-up, 6 shimmer.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 ink : source_color = vec4(0.078, 0.094, 0.110, 1.0);
uniform float motion = 1.0;

varying flat vec4 cd;
varying flat float body_len;

void vertex() {
	cd = INSTANCE_CUSTOM;
	body_len = COLOR.r * 1000.0;
}

// Over-blend a stroke: c = colour, a = coverage.
vec4 over(vec4 dst, vec3 c, float a) {
	float oa = a + dst.a * (1.0 - a);
	vec3 oc = (c * a + dst.rgb * dst.a * (1.0 - a)) / max(oa, 1e-4);
	return vec4(oc, oa);
}

float band(float d, float w) {
	// 1 inside a stroke of width w centred on d = 0, 1 px antialias.
	return clamp(w * 0.5 - abs(d) + 0.5, 0.0, 1.0);
}

vec4 bubble_ring(vec2 p, float L, float t) {
	float a = 0.62 * L + 16.0;
	float b = a * 0.82;
	vec4 o = vec4(0.0);
	float ang = atan(p.y / 0.82, p.x);
	float rot = t * 0.25 * 6.2831 * motion;
	float seg = 6.2831 / 12.0;
	float k = round((ang - rot) / seg);
	for (int j = -1; j <= 1; j++) {
		float th = (k + float(j)) * seg + rot;
		float bob = sin(t * 2.0 + (k + float(j)) * 1.7) * 2.0 * motion;
		vec2 c = vec2(cos(th) * a, sin(th) * b + bob);
		float d = length(p - c);
		float r = 8.0;
		o = over(o, ink.rgb, band(d - (r + 1.5), 3.0) * 0.5);
		o = over(o, vec3(1.0), clamp(r - 1.0 - d + 0.5, 0.0, 1.0) * 0.27);
		o = over(o, vec3(1.0), band(d - (r - 1.5), 3.0));
		o = over(o, vec3(1.0), clamp(2.2 - length(p - c - vec2(-2.6, -2.6)) + 0.5, 0.0, 1.0));
	}
	return o;
}

vec4 zigzag(vec2 p, float L, float t) {
	float pulse = 1.0 + 0.06 * (0.5 + 0.5 * sin(t * 6.2831 * motion));
	float ro = (0.70 * L + 30.0) * pulse;
	float ri = (0.56 * L + 14.0) * pulse;
	vec2 q = vec2(p.x, p.y / 0.80);
	float ang = atan(q.y, q.x);
	float seg = 6.2831 / 8.0;
	float f = mod(ang + seg * 0.5, seg) - seg * 0.5;
	f = abs(f);
	float rr = length(q);
	vec2 pq = vec2(cos(f), sin(f)) * rr;
	vec2 A = vec2(ro, 0.0);
	vec2 B = vec2(cos(seg * 0.5), sin(seg * 0.5)) * ri;
	vec2 ab = B - A;
	float h = clamp(dot(pq - A, ab) / dot(ab, ab), 0.0, 1.0);
	float d = length(pq - A - ab * h);
	vec4 o = vec4(0.0);
	o = over(o, ink.rgb, band(d, 11.0) * 0.63);
	o = over(o, vec3(1.0), band(d, 4.0));
	return o;
}

vec4 glass(vec2 p, float R, float wob, float t, bool shine) {
	float ang = atan(p.y, p.x);
	float r = R * (1.0 + wob * 0.04 * sin(ang * 3.0 + t * 4.0) * motion);
	float d = length(p);
	vec4 o = vec4(0.0);
	float inside = clamp(r - d + 0.5, 0.0, 1.0);
	float fres = pow(clamp(d / r, 0.0, 1.0), 4.0);
	o = over(o, vec3(1.0), inside * (0.08 + 0.55 * fres));
	o = over(o, ink.rgb, band(d - r - 1.5, 2.5) * 0.35);
	o = over(o, vec3(1.0), band(d - r + 1.0, max(2.0, R * 0.08)));
	vec2 hp = p - vec2(-0.38, -0.42) * r;
	o = over(o, vec3(1.0), clamp(r * 0.13 - length(hp) + 0.5, 0.0, 1.0) * 0.9);
	if (shine) {
		// Bobla icon: a curved shine mark on the upper left.
		float da = abs(d - r * 0.62);
		float arc = step(2.3, ang + 3.1416) * step(ang + 3.1416, 3.7);
		o = over(o, vec3(1.0), clamp(r * 0.06 - da + 0.5, 0.0, 1.0) * arc);
	}
	return o;
}

void fragment() {
	float kind = cd.x;
	float half_px = cd.w;
	vec2 p = (UV * 2.0 - 1.0) * half_px;
	float t = TIME;
	vec4 o = vec4(0.0);
	if (kind < 1.0) {
		float m = cd.y;
		if (m < 0.999) {
			vec4 e = bubble_ring(p, body_len, t);
			o = over(o, e.rgb, e.a * (1.0 - m));
		}
		if (m > 0.001) {
			vec4 z = zigzag(p * mix(1.25, 1.0, m), body_len, t);
			o = over(o, z.rgb, z.a * m);
		}
	} else if (kind < 2.5) {
		float d = length(p) - 32.0;
		o = over(o, ink.rgb, band(d, 8.0) * 0.43);
		o = over(o, vec3(1.0), band(d, 4.0));
	} else if (kind < 3.5) {
		o = glass(p, half_px - 2.0, 0.0, t, false);
	} else if (kind < 4.5) {
		o = glass(p, half_px - 4.0, 1.0, t, false);
	} else if (kind < 5.5) {
		o = glass(p, half_px - 4.0, 0.5, t, true);
	} else {
		float d = length(p) - (half_px - 6.0);
		float ang = atan(p.y, p.x) + t * 0.8 * motion;
		float dash = 0.5 + 0.5 * sin(ang * 10.0);
		o = over(o, vec3(1.0), band(d, 3.0) * (0.25 + 0.2 * dash));
	}
	ALBEDO = o.rgb;
	ALPHA = o.a * cd.z;
}
