class_name RbKelpPatch
extends RefCounted

## On-plane kelp patches (GDD 5.2, QA 2026-10-10 finding 3): sculpted
## strands, leaves drawn inside the 160 px safe rect plus this margin, all
## behind the play plane (fish bodies sit within +-0.15 m, DESIGN 2), so no
## leaf covers a fish.
const MESHES: Array[String] = ["kelp_giant_a", "kelp_giant_b", "kelp_giant_c"]
const MARGIN_PX: float = 8.0
const STRANDS_PER_MESH: int = 2
const Z: float = -0.32
const DEPTH_HALF: float = 0.12
const SWAY: float = 0.015
const BRIGHTNESS: float = 0.75
const COOL_MIX: float = 0.45


## Strand transform that fits `mesh` (turned by `turn` around Y) into the
## safe rect drawn on the play plane, at depth z behind it. Everything is
## scaled by (CAM_DIST - z) / CAM_DIST so the strand, seen in perspective
## from the camera, covers the same screen px as the rect on the plane.
static func fit_strand(
	mesh_v: PackedVector3Array, h: float, turn: float, rect: Rect2, z: float
) -> Transform3D:
	var rot := Basis(Vector3.UP, turn)
	var ext_x: float = 0.01
	var ext_z: float = 0.01
	for v: Vector3 in mesh_v:
		var r: Vector3 = rot * v
		ext_x = maxf(ext_x, absf(r.x))
		ext_z = maxf(ext_z, absf(r.z))
	var f: float = (RbWorld.CAM_DIST - z) / RbWorld.CAM_DIST
	var half_w: float = (rect.size.x * 0.5 + MARGIN_PX) / RbBalance.PX_PER_M * f
	var top: Vector3 = RbBalance.to_world(Vector2(rect.get_center().x, rect.position.y)) * f
	var bot: Vector3 = RbBalance.to_world(rect.end) * f
	var sx: float = half_w / ext_x
	var sy: float = (top.y - bot.y) / h
	var sz: float = DEPTH_HALF / ext_z
	return Transform3D(Basis.from_scale(Vector3(sx, sy, sz)) * rot, Vector3(top.x, bot.y, z))


## Thin kelp stipe, base y 0 to top y 1, two crossed ribbons.
static func stipe_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: float = 0.012
	for axis: Vector3 in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
		var a: Vector3 = -axis * w
		var b: Vector3 = axis * w
		for v: Vector3 in [a, b, b + Vector3.UP, a, b + Vector3.UP, a + Vector3.UP]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()
