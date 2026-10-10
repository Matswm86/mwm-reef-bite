class_name RbMarks
extends MultiMeshInstance3D

## All game marks in one MultiMesh draw call (DESIGN 5, 11): fish rings,
## aim ring, Bobla bubbles, burp bubble, immunity shimmer and every small
## glass bubble (eat, grow ring, gill trail, pops). Small bubbles are a tiny
## CPU particle pool (no GPU emitters needed). Call begin(), add() marks,
## then commit() once per frame.

enum Kind { RING = 0, AIM = 2, BUBBLE = 3, SHIELD = 4, POWERUP = 5, SHIMMER = 6 }

const CAPACITY: int = 320
const MAX_BUBBLES: int = 220
const Z_MARK: float = 0.35

var less_motion: bool = false
var _n: int = 0
var _mm: MultiMesh
var _mat: ShaderMaterial
# Bubble particles: pos (px), vel (px/s), life left, life total, radius px.
var _b_pos: PackedVector2Array = PackedVector2Array()
var _b_vel: PackedVector2Array = PackedVector2Array()
var _b_life: PackedFloat32Array = PackedFloat32Array()
var _b_total: PackedFloat32Array = PackedFloat32Array()
var _b_r: PackedFloat32Array = PackedFloat32Array()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 4242
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	_mm.mesh = q
	_mm.instance_count = CAPACITY
	_mm.visible_instance_count = 0
	multimesh = _mm
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/rb_marks.gdshader")
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sorting_offset = 100.0
	custom_aabb = AABB(Vector3(-20, -20, -5), Vector3(40, 40, 10))


func set_less_motion(on: bool) -> void:
	less_motion = on
	_mat.set_shader_parameter("motion", 0.0 if on else 1.0)


func begin() -> void:
	_n = 0


## kind: Kind; pos in design px; half_px = half the quad size in px;
## morph: ring 0 edible .. 1 danger; body_len: fish length px (rings).
func add(
	kind: int, pos: Vector2, half_px: float, alpha: float, morph: float = 0.0, body_len: float = 0.0
) -> void:
	if _n >= CAPACITY or alpha <= 0.003:
		return
	var s: float = half_px * 2.0 / RbBalance.PX_PER_M
	var xf := Transform3D(
		Basis.IDENTITY.scaled(Vector3(s, s, 1.0)), RbBalance.to_world(pos, Z_MARK)
	)
	_mm.set_instance_transform(_n, xf)
	_mm.set_instance_color(_n, Color(body_len / 1000.0, 0.0, 0.0, 1.0))
	_mm.set_instance_custom_data(_n, Color(float(kind), morph, alpha, half_px))
	_n += 1


## Fish ring: quad big enough for the zigzag at full pulse.
func add_ring(pos: Vector2, body_len: float, morph: float, alpha: float) -> void:
	var half: float = (0.70 * body_len + 30.0) * 1.08 + 10.0
	add(Kind.RING, pos, half, alpha, morph, body_len)


func commit() -> void:
	for i: int in _b_pos.size():
		var life: float = _b_life[i]
		var a: float = clampf(life / 0.25, 0.0, 1.0) * clampf((_b_total[i] - life) / 0.08, 0.0, 1.0)
		add(Kind.BUBBLE, _b_pos[i], _b_r[i] + 2.0, a * 0.9)
	_mm.visible_instance_count = _n


# ---------------------------------------------------------------- bubbles


func step_bubbles(delta: float) -> void:
	var i: int = 0
	while i < _b_pos.size():
		_b_life[i] -= delta
		if _b_life[i] <= 0.0 or _b_pos[i].y < RbBalance.POND.position.y - 120.0:
			_remove_bubble(i)
			continue
		var v: Vector2 = _b_vel[i]
		v.y -= 60.0 * delta
		v.x *= 1.0 - minf(1.0, 2.5 * delta)
		_b_vel[i] = v
		var wob: float = 0.0 if less_motion else sin(_b_life[i] * 9.0 + float(i)) * 14.0
		_b_pos[i] += (v + Vector2(wob, 0.0)) * delta
		i += 1


func _remove_bubble(i: int) -> void:
	var last: int = _b_pos.size() - 1
	_b_pos[i] = _b_pos[last]
	_b_vel[i] = _b_vel[last]
	_b_life[i] = _b_life[last]
	_b_total[i] = _b_total[last]
	_b_r[i] = _b_r[last]
	_b_pos.resize(last)
	_b_vel.resize(last)
	_b_life.resize(last)
	_b_total.resize(last)
	_b_r.resize(last)


func bubble(pos: Vector2, vel: Vector2, life: float, r: float) -> void:
	if _b_pos.size() >= MAX_BUBBLES:
		return
	_b_pos.append(pos)
	_b_vel.append(vel)
	_b_life.append(life)
	_b_total.append(life)
	_b_r.append(r)


## Burst of `n` bubbles out of a point (eat: 6-10, grow ring: 24).
func burst(
	pos: Vector2, n: int, speed: float, r_lo: float, r_hi: float, ring: bool = false
) -> void:
	for i: int in n:
		var a: float = TAU * float(i) / float(n) if ring else _rng.randf() * TAU
		var sp: float = speed * (1.0 if ring else _rng.randf_range(0.35, 1.0))
		var v := Vector2(cos(a), sin(a)) * sp + Vector2(0.0, -40.0)
		bubble(pos, v, _rng.randf_range(0.5, 0.9), _rng.randf_range(r_lo, r_hi))


## Gill trail: a thin column of 6-10 bubbles (DESIGN 4).
func gill_trail(pos: Vector2) -> void:
	var n: int = _rng.randi_range(6, 10)
	for i: int in n:
		bubble(
			pos + Vector2(_rng.randf_range(-4.0, 4.0), float(i) * 9.0),
			Vector2(_rng.randf_range(-8.0, 8.0), -_rng.randf_range(70.0, 110.0)),
			_rng.randf_range(1.0, 1.8),
			_rng.randf_range(2.5, 5.0)
		)


func bubble_count() -> int:
	return _b_pos.size()


func mark_count() -> int:
	return _n
