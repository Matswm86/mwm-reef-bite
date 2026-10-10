# World 1 fish models

Own work (graphic-designer, 2026-10-10), CC0-clean: no third-party meshes or images. Rebuilt by the scripts in `docs/mockups/src/` (`fish_species.py` shape spec, `fish_paint.py` atlas, `fish_build.py` meshes and GLB export).

| File | Tier | Species | Triangles |
|---|---|---|---|
| `golden_trevally.glb` | player, tiers 2-10 | Golden trevally, juvenile (*Gnathanodon speciosus*) | 2,870 |
| `brisling.glb` | 1 | Brisling / European sprat (*Sprattus sprattus*) | 1,120 |
| `gronngylt.glb` | 2 | Grønngylt / corkwing wrasse (*Symphodus melops*) | 1,132 |
| `sei.glb` | 3 | Sei / saithe, young (*Pollachius virens*) | 1,188 |
| `berggylt.glb` | 4 | Berggylt / ballan wrasse (*Labrus bergylta*) | 1,132 |
| `lyr.glb` | 5 | Lyr / pollack (*Pollachius pollachius*) | 1,188 |
| `torsk.glb` | 6 | Torsk / Atlantic cod (*Gadus morhua*) | 2,947 |
| `havabbor.glb` | 7 | Havabbor / European sea bass (*Dicentrarchus labrax*) | 2,846 |

Budgets (DESIGN 11): at most 1,200 triangles below tier 6, at most 3,000 from tier 6 and for the player. All pass.

## Model contract

- **Size and axes:** 1.0 m from nose to tail tip. Nose at +X (x = +0.42), tail tip at x = -0.58, so the bounding-box centre sits 0.08 L behind the origin (the ring offset in DESIGN 5). Up is +Y, the left flank faces +Z. Scale by the tier length in metres (`RbFishCatalog._fit_unit` already does this).
- **Two surfaces per fish:** `fish_w1_body` (opaque, back-face culled) and `fish_w1_fins` (alpha blend, double sided; Godot imports it as depth-prepass alpha). Eyes (domed cornea) and the cod's barbel are on the body surface.
- **One atlas for all eight:** `textures/fish_w1_albedo.png` (RGBA, alpha used by the fins), `textures/fish_w1_normal.png` (OpenGL, +Y up) and `textures/fish_w1_orm.png` (R occlusion, G roughness, B metallic), 2048 x 2048. The GLBs point at these files by relative URI, so Godot imports one texture set that every species shares. Do not re-export with embedded images: that would make 8 copies (about 50 MB more in the APK).
- **Layout:** one 1024 x 512 block per species (2 columns x 4 rows, in the table order). The top 320 rows are the body seen from the side (both flanks share it, so the atlas is symmetric and the 180-degree turn in DESIGN 10 shows the same pattern); the fins, the eye disc and the barbel are packed underneath.
- **Vertex colour (COLOR_0):** R = jaw mask (lower jaw, 0-1), G = fin flare mask (dorsal, anal and pectoral rays, 0 at the base to 1 at the tip), B = swim bend weight (0 at the head, 1 at the tail tip), A = 1. No skeleton, no AnimationPlayer, no `Jaw` node (GDD 11: vertex-shader swim only).

## Swim, jaw and fin flare (vertex shader for the builder)

Not compile-tested here: headless Godot has no shader compiler on this box. It uses the same instance uniforms as `shaders/rb_fish.gdshader`, so it can replace the proxy shader. The local x below is the GLB's own x (nose +0.42).

```glsl
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform float rim_k : hint_range(0.0, 1.0) = 0.0;      // player 0.5 in play, about 0.05 on the win-card portrait
uniform float rim_tint_k : hint_range(0.0, 1.0) = 0.6;

instance uniform float mouth : hint_range(0.0, 1.0) = 0.0;
instance uniform float flare : hint_range(0.0, 1.0) = 0.0;
instance uniform float phase = 0.0;
instance uniform float swim_hz = 2.5;
instance uniform float swim_amp = 1.0;

void vertex() {
	float bend = COLOR.b * COLOR.b;                                   // stiff head, loose tail
	VERTEX.z += sin(TIME * swim_hz * TAU + phase + VERTEX.x * 5.5) * 0.06 * bend * swim_amp;  // wave runs nose to tail
	VERTEX.y -= mouth * COLOR.r * 0.10 * clamp((VERTEX.x - 0.33) / 0.09, 0.0, 1.0);          // lower jaw drops
	VERTEX.y += flare * COLOR.g * 0.025 * sign(VERTEX.y);                                     // fins spread
}

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	ALBEDO = a.rgb * orm.r;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	SPECULAR = 0.6;
	RIM = rim_k;
	RIM_TINT = rim_tint_k;
}
```

Fins: the same vertex() with `render_mode blend_mix, depth_prepass_alpha, cull_disabled`, and in fragment() add `ALPHA = a.a; BACKLIGHT = a.rgb * 0.6;` (light through the fin membrane). Drop the normal map on the Lav tier (DESIGN 10).

Amplitudes are in model units (fraction of body length), so they hold at every tier. Swim speed by tier: 2-4 Hz (DESIGN 10), slower for bigger fish.
