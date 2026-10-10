# MWM Reef Bite shaders

`rb_*.gdshader` and `rb_caustics.gdshaderinc` are own work, except the three files below, which come from the studio templates (`game-studio/templates/shaders/`, ported from [stylized-components](https://github.com/cortiz2894/stylized-components) by Christian Ortiz, MIT, commit `1cece0a`). Their header comments are kept and `LICENSE-stylized-components.txt` sits next to them.

| File | Source | Changed vs the studio copy, and why |
|---|---|---|
| `rb_kelp.gdshader` | `stylized_grass.gdshader` | Kelp palette defaults (`kelp_dark` -> `kelp_light`, golden translucency), slow current sway (strength 0.06, speed 0.4, lean 0.3), real blade normals (the flattened up-normal made side-on kelp flat), a `sway_scale` uniform for "Mindre bevegelse" and a `shimmer` band for the on-plane kelp patch "safe" cue (DESIGN 10) |
| `rb_seagrass.gdshader` | `stylized_grass.gdshader` | Unchanged; the realistic seagrass colours are set on the material in `RbWorld.gd` |
| `rb_surface.gdshader` | `stylized_water.gdshader` | `cull_front`, because the surface is seen from underneath; depth foam stays off (it forces a depth copy per frame on Mobile); sparkles and ripples are switched off from the material |
