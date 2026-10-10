class_name RbFishView
extends Node3D

## One fish on the play plane (DESIGN 2, 4): model scaled to its tier
## length, turns by rotating 180 degrees around Y over 120 ms (the player:
## eased over 250 ms; never a negative scale), tilts with its vertical
## speed (max 25 degrees), opens the mouth for the cue (GDD 4.3), pops on
## growth (GDD 4.4) and squashes on a meal (GDD 9). Works with the proxy
## mesh and with a dropped-in GLB.

var key: Variant = 1
var tier: int = 1
var model: Node3D
var is_proxy: bool = true
var less_motion: bool = false
var facing: float = 1.0
var mouth: float = 0.0
var mouth_target: float = 0.0
var flare: float = 0.0
var flare_target: float = 0.0
var flash: float = 0.0
var dim_k: float = 0.0
## Sun rim strength (DESIGN 4: the player 0.5+, other fish low). Set before setup().
var rim: float = 0.15
## Player only: the turn-around eases in and out over PLAYER_TURN_S instead
## of the plain 120 ms rotation (owner phone test 2026-10-10).
var smooth_turn: bool = false
var _yaw: float = 0.0
var _yaw_from: float = 0.0
var _yaw_to: float = 0.0
var _turn_k: float = 1.0
var _tilt: float = 0.0
var _len_now: float = 72.0
var _len_from: float = 72.0
var _len_to: float = 72.0
var _grow_t: float = 99.0
var _squash_t: float = 99.0
var _geoms: Array[GeometryInstance3D] = []
var _phase: float = 0.0


func setup(species_key: Variant, start_tier: int, phase: float) -> void:
	key = species_key
	tier = start_tier
	_phase = phase
	var made: Array = RbFishCatalog.make_model(species_key)
	model = made[0]
	is_proxy = made[1]
	add_child(model)
	if is_proxy:
		_geoms.append(model as GeometryInstance3D)
	else:
		for c: Node in model.find_children("*", "GeometryInstance3D", true, false):
			_geoms.append(c as GeometryInstance3D)
	_len_now = RbBalance.tier_len(tier)
	_len_from = _len_now
	_len_to = _len_now
	_apply_scale()
	for g: GeometryInstance3D in _geoms:
		g.set_instance_shader_parameter(&"phase", phase)
		g.set_instance_shader_parameter(&"swim_hz", lerpf(3.4, 1.8, float(tier - 1) / 9.0))
		g.set_instance_shader_parameter(&"rim", rim)


## Snap to a new tier with the growth pop (0.35 s, 6% overshoot).
func grow_to(new_tier: int) -> void:
	tier = new_tier
	_len_from = _len_now
	_len_to = RbBalance.tier_len(new_tier)
	_grow_t = 0.0
	if less_motion:
		_grow_t = 0.0


func set_tier_now(new_tier: int) -> void:
	tier = new_tier
	_len_now = RbBalance.tier_len(new_tier)
	_len_to = _len_now
	_grow_t = 99.0
	_apply_scale()


func squash() -> void:
	if not less_motion:
		_squash_t = 0.0


func face_now(f: float) -> void:
	facing = f
	_yaw = 0.0 if f > 0.0 else PI
	_yaw_from = _yaw
	_yaw_to = _yaw
	_turn_k = 1.0
	rotation.y = _yaw


## Per-frame update from the logic: position (design px), velocity (px/s).
func sync(pos: Vector2, vel: Vector2, want_facing: float, delta: float) -> void:
	position = RbBalance.to_world(pos)
	facing = want_facing
	var target_yaw: float = 0.0 if facing > 0.0 else PI
	if less_motion:
		_yaw = target_yaw
	elif smooth_turn:
		if target_yaw != _yaw_to:
			_yaw_from = _yaw
			_yaw_to = target_yaw
			_turn_k = 0.0
		_turn_k = minf(1.0, _turn_k + delta / RbBalance.PLAYER_TURN_S)
		_yaw = lerpf(_yaw_from, _yaw_to, smoothstep(0.0, 1.0, _turn_k))
	else:
		_yaw = move_toward(_yaw, target_yaw, PI * delta / RbBalance.FLIP_S)
	var speed: float = maxf(absf(vel.x), 40.0)
	var tilt_want: float = clampf(atan2(-vel.y, speed), -1.0, 1.0)
	tilt_want = clampf(
		tilt_want, -deg_to_rad(RbBalance.TILT_MAX_DEG), deg_to_rad(RbBalance.TILT_MAX_DEG)
	)
	_tilt = lerpf(_tilt, tilt_want, 1.0 - exp(-delta * 8.0))
	# Tilt in the fish's own frame so it reads the same facing left or right.
	rotation = Vector3(0.0, _yaw, _tilt)
	mouth = move_toward(mouth, mouth_target, delta / RbBalance.MOUTH_OPEN_S)
	flare = move_toward(flare, flare_target, delta / 0.15)
	flash = maxf(0.0, flash - delta * 3.0)
	if _grow_t < RbBalance.GROW_POP_S:
		_grow_t += delta
		var k: float = clampf(_grow_t / RbBalance.GROW_POP_S, 0.0, 1.0)
		if less_motion:
			k = clampf(_grow_t / 0.2, 0.0, 1.0)
			_len_now = lerpf(_len_from, _len_to, k)
		else:
			# Ease-out with a 6% overshoot (GDD 4.4).
			var e: float = 1.0 - pow(1.0 - k, 3.0)
			var over: float = sin(k * PI) * RbBalance.GROW_OVERSHOOT
			_len_now = lerpf(_len_from, _len_to, e) * (1.0 + over)
	else:
		_len_now = _len_to
	_squash_t += delta
	_apply_scale()
	for g: GeometryInstance3D in _geoms:
		g.set_instance_shader_parameter(&"mouth", maxf(mouth, flare * 0.6))
		g.set_instance_shader_parameter(&"flare", flare)
		g.set_instance_shader_parameter(&"flash", flash)
		g.set_instance_shader_parameter(&"tint_dim", dim_k)
		g.set_instance_shader_parameter(&"swim_amp", 0.5 if less_motion else 1.0)


func _apply_scale() -> void:
	var m: float = _len_now / RbBalance.PX_PER_M
	var sq: float = 1.0
	if _squash_t < 0.08:
		sq = 1.0 - 0.08 * sin(_squash_t / 0.08 * PI)
	scale = Vector3(m * (2.0 - sq), m * sq, m)


func current_len_px() -> float:
	return _len_now
