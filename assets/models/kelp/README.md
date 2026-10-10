# World 1 kelp and seagrass models

Own work (graphic-designer, 2026-10-10), CC0-clean: no third-party meshes or images. Rebuilt by `docs/mockups/src/kelp_paint.py` (atlas) and `docs/mockups/src/kelp_build.py` (meshes and GLB export).

| File | Use | Real size | Triangles |
|---|---|---|---|
| `kelp_giant_a.glb` | near kelp strand (stipe + 32 blades with gas bladders) | 6.9 m tall | 602 |
| `kelp_giant_b.glb` | near kelp strand, 27 blades | 5.7 m | 512 |
| `kelp_giant_c.glb` | near kelp strand, 22 blades | 5.1 m | 422 |
| `kelp_giant_far.glb` | far chunk (z -10 to -30), 18 blades, 2 segments each | 6.6 m | 168 |
| `kelp_sugar.glb` | clump of 3 sugar-kelp plants (*Saccharina latissima*), ruffled blades lying over in the current | 1.0 m high, 1.2 m long | 312 |
| `seagrass_tuft.glb` | 9 eelgrass blades (*Zostera marina*), for MultiMesh tufts on sand | 0.25-0.6 m | 90 |

- **Axes:** root at the origin on the floor, up +Y, current pushes toward +X (DESIGN 10: sway direction +X). Real metres; scale per instance 0.85-1.2.
- **Material:** one, `kelp_w1`: alpha scissor 0.5, double sided. The GLBs point at `textures/kelp_w1_albedo.png` (RGBA), `kelp_w1_normal.png` (OpenGL) and `kelp_w1_orm.png` (R occlusion, G roughness, B metallic) by relative URI, so all six share one imported texture set.
- **Look:** blade outlines (toothed edges, eroded tips, holes, bladders) come from the alpha, not the mesh, so each blade is a cheap 2 x 4 quad strip folded along its midline. Light through the blades (the gold back-glow in the mock) is `BACKLIGHT`, not transparency.
- **Vertex colour (COLOR_0):** R = sway weight (0 at the root, 1 at the top), G = per-blade phase 0-1, B = blade flutter weight (0 at the blade base, 1 at its tip), A = 1.

## Current sway (vertex shader for the builder)

Not compile-tested here (no shader compiler in headless Godot on this box). Works per MultiMesh instance because `MODEL_MATRIX` is the instance transform in vertex().

```glsl
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform float strength = 0.06;     // DESIGN 10: 0.06, x0.5 under "Mindre bevegelse"
uniform float speed = 0.4;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float ph = root.x * 0.7 + root.z * 0.45;
	float h = COLOR.r * COLOR.r;
	VERTEX.x += h * strength * 6.0 * (0.6 + 0.4 * sin(TIME * speed * TAU + ph));
	VERTEX.z += h * strength * 3.0 * sin(TIME * speed * 0.7 * TAU + ph * 1.3);
	VERTEX += NORMAL * COLOR.b * 0.04 * sin(TIME * 1.7 + COLOR.g * TAU + VERTEX.y * 2.0);   // blade flutter
}

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	ALBEDO = a.rgb;
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = orm.g;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	BACKLIGHT = a.rgb * vec3(1.1, 0.95, 0.65);   // warm light through the blades
}
```
