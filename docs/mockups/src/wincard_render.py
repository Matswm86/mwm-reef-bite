"""Close portrait of the player fish for the win card, from the saved world-1 scene.

Run:  blender -b <out_dir>/world1_mock.blend -P wincard_render.py -- <out_dir> [samples]
Writes <out_dir>/w1_portrait.png (780x560).
"""

import math
import sys
from pathlib import Path

import bpy

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = Path(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 96
sc = bpy.context.scene
sc.cycles.samples = SAMPLES
sc.render.resolution_x, sc.render.resolution_y = 780, 560
sc.render.resolution_percentage = 100
sc.view_settings.exposure = (
    -0.1
)  # close-up: no fog between camera and fish, so less lift than the play view
try:
    sc.view_settings.look = "AgX - High Contrast"
except TypeError:
    pass
cam = sc.camera
cam.data.sensor_fit = "AUTO"
cam.data.lens = 70
player = bpy.data.objects["player"]
# the sun-catch rim is a play-view readability aid (DESIGN 4); the close portrait keeps only a trace of it
pm = bpy.data.materials.get("fish_w1_body_player")
if pm:
    for nd in pm.node_tree.nodes:
        if (
            nd.type == "MATH"
            and nd.operation == "MULTIPLY"
            and abs(nd.inputs[1].default_value - 2.5) < 1e-3
        ):
            nd.inputs[1].default_value = 0.25
L = player.scale.x  # GLB is 1 m nose to tail, scaled to the tier length
cx = (
    player.location.x - 0.08 * L
)  # bounding-box centre sits 0.08 L behind the origin (fish faces +X)
cam.location = (cx + 0.02, -1.05, player.location.z + 0.05)
cam.rotation_euler = (math.radians(87), 0, math.radians(1.5))
# drop the mask writer so the gameplay masks are not overwritten
for nd in list(sc.node_tree.nodes):
    if nd.bl_idname == "CompositorNodeOutputFile":
        sc.node_tree.nodes.remove(nd)
sc.render.filepath = str(OUT / "w1_portrait.png")
bpy.ops.render.render(write_still=True)
print("DONE portrait")
