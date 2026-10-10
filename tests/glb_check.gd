extends SceneTree

## Dev check: every sculpted fish / kelp GLB loads headless; prints the mesh
## bounds, triangle count, vertex-colour presence and surface materials.
##   godot --headless --audio-driver Dummy -s tests/glb_check.gd


func _init() -> void:
	var fails: int = 0
	for dir: String in ["res://assets/models/fish/", "res://assets/models/kelp/"]:
		var d := DirAccess.open(dir)
		if d == null:
			print("FAIL no folder ", dir)
			fails += 1
			continue
		for f: String in d.get_files():
			if not f.ends_with(".glb"):
				continue
			var sc := load(dir + f) as PackedScene
			if sc == null:
				print("FAIL load ", f)
				fails += 1
				continue
			var inst: Node = sc.instantiate()
			for c: Node in inst.find_children("*", "MeshInstance3D", true, false):
				var mi := c as MeshInstance3D
				var tris: int = 0
				var col: bool = true
				var mats: PackedStringArray = []
				for i: int in mi.mesh.get_surface_count():
					var a: Array = mi.mesh.surface_get_arrays(i)
					var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
					tris += idx.size() / 3
					col = col and a[Mesh.ARRAY_COLOR] != null
					var m: Material = mi.mesh.surface_get_material(i)
					mats.append(m.resource_name if m else "-")
				print(
					(
						"ok %-22s xf=%s aabb=%s tris=%d colour=%s mats=%s"
						% [f, mi.transform.origin, mi.mesh.get_aabb(), tris, col, mats]
					)
				)
			inst.free()
	print("GLB CHECK ", "PASS" if fails == 0 else "FAIL")
	quit(fails)
