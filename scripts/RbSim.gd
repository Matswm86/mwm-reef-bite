class_name RbSim
extends RefCounted

## Pure game logic of one level (GDD 4): player steering, tiers, eat /
## catch / bump, spawning with anti-starve, Vanlig chase and flee, the
## gentle catch (burp bubble, meter loss, bobler, gentle restart), pearls,
## the Bobla shield and kelp hiding places. No nodes, no rendering: RbPlay
## drives it with step(dt) and reads its state; the headless logic test and
## the bot use it the same way. Things that happened in a step are queued in
## `events` (Dictionaries with a "type" key) for sound, particles and HUD.

enum PState { FREE, GULP, BUBBLE }


class Fish:
	var id: int = 0
	var tier: int = 1
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	## Cruise direction: +1 swims right, -1 left.
	var dir: float = 1.0
	var speed: float = 80.0
	var wave_phase: float = 0.0
	var chase_t: float = 0.0
	var chased: bool = false
	var flee_t: float = 0.0
	var flee_cd: float = 0.0
	var bump_v: Vector2 = Vector2.ZERO
	var bump_t: float = 0.0
	var bump_cd: float = 0.0
	## Vanlig ring fade 0..1 (Lett: always 1).
	var ring_alpha: float = 1.0
	var ring_on: bool = true
	## Swimming off to the side (level clear, gentle restart).
	var leaving: bool = false
	var scripted: bool = false
	## A danger fish close to the player opens its mouth (GDD 4.3 cue 4).
	var danger_near: bool = false
	## Big fish gulp animation after a catch, seconds left.
	var gulp_t: float = 0.0
	var facing: float = 1.0


var level_id: int = 1
var level: Dictionary = {}
var easy: bool = true
var goal: String = "grow"
var target: int = 3
var fish_max: int = 7
## -1 = unlimited (world 1 and breathers).
var bobler: int = -1
var bobler_max: int = -1
var world_speed: float = 1.0
var breather: bool = false
var no_big: bool = false
var kelp: Array[Rect2] = []

var time: float = 0.0
var fishes: Array[Fish] = []
var events: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

# Player
var p_pos: Vector2 = Vector2(540, 950)
var p_vel: Vector2 = Vector2.ZERO
var p_tier: int = 2
var p_food: int = 0
var p_aim: Vector2 = Vector2(540, 950)
var p_state: PState = PState.FREE
var p_state_t: float = 0.0
var p_bubble_from: Vector2 = Vector2.ZERO
var p_bubble_to: Vector2 = Vector2.ZERO
var p_immune: float = 0.0
var p_facing: float = 1.0
var p_mouth_target: bool = false
var p_bump_v: Vector2 = Vector2.ZERO
var p_bump_t: float = 0.0
var p_in_kelp: int = -1
var shield_t: float = 0.0
## Index of the fish that caught the player (gulp animation), or -1.
var catcher_id: int = -1

# Goals and pickups
var pearls: int = 0
## "none", "wait", "open" (pearl shows, can be taken)
var pearl_state: String = "wait"
var pearl_t: float = 0.0
var pearl_pos: Vector2 = Vector2.ZERO
var powerup_on: bool = false
var powerup_pos: Vector2 = Vector2.ZERO
var powerup_t: float = 0.0
var powerup_count: int = 0

var cleared: bool = false
var clear_t: float = 0.0
var restarting: bool = false
var restart_t: float = 0.0
var restarts: int = 0
var catches: int = 0
var catch_times: Array[float] = []
var eats: int = 0
var bumps: int = 0
## Gentle-restart dim 0..RESTART_DIM for the view.
var dim: float = 0.0

var _spawn_t: float = 0.0
var _next_id: int = 1
var _scripted_done: bool = false
var _swish_t: float = -99.0


## Starts a level. force_bobler >= 0 overrides the level's bobler count
## (test-only: world 1 is unlimited, GDD 13 asks to cover the restart).
func setup(id: int, is_easy: bool, seed_value: int = 0, force_bobler: int = -1) -> void:
	level_id = id
	level = RbLevels.get_level(id)
	easy = is_easy
	var s: Dictionary = RbLevels.setting(id, is_easy)
	goal = String(level.get("goal", "grow"))
	target = int(s["target"])
	fish_max = int(s["fish_max"])
	var b: int = int(s["bobler"])
	if force_bobler >= 0:
		b = force_bobler
	bobler = b if b > 0 else -1
	bobler_max = bobler
	world_speed = float(level.get("world_speed", 1.0))
	breather = bool(level.get("breather", false))
	no_big = bool(level.get("no_big", false))
	kelp.clear()
	for c: Vector2 in level.get("kelp", []):
		kelp.append(Rect2(c - RbBalance.KELP_SIZE * 0.5, RbBalance.KELP_SIZE))
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	time = 0.0
	fishes.clear()
	events.clear()
	p_pos = level.get("player_start", Vector2(540, 950))
	p_vel = Vector2.ZERO
	p_tier = RbBalance.PLAYER_START_TIER
	p_food = 0
	p_aim = p_pos
	p_state = PState.FREE
	p_immune = 0.0
	p_facing = 1.0
	p_bump_t = 0.0
	p_in_kelp = -1
	shield_t = 0.0
	catcher_id = -1
	pearls = 0
	pearl_state = "wait" if goal == "pearls" else "none"
	pearl_t = RbBalance.PEARL_FIRST
	powerup_on = false
	powerup_count = 0
	powerup_t = RbBalance.POWERUP_FIRST
	cleared = false
	clear_t = 0.0
	restarting = false
	restart_t = 0.0
	restarts = 0
	catches = 0
	catch_times.clear()
	eats = 0
	bumps = 0
	dim = 0.0
	_spawn_t = 0.0
	_scripted_done = false
	_place_start_fish()


# ---------------------------------------------------------------- queries


func player_r() -> float:
	return RbBalance.body_r(p_tier)


func need_now() -> int:
	return RbBalance.need(p_tier, easy)


## Meter of the current tier 0..1 (HUD).
func meter() -> float:
	return clampf(float(p_food) / float(need_now()), 0.0, 1.0)


## Tier the player can grow to in this level.
func tier_cap() -> int:
	return target if goal == "grow" else RbBalance.PEARL_LEVEL_TIER_CAP


func ring_kind(f: Fish) -> int:
	## 1 = edible (smooth bubble ring), 2 = danger (zigzag), 0 = same tier.
	if f.tier < p_tier:
		return 1
	if f.tier > p_tier:
		return 2
	return 0


func kelp_index(p: Vector2) -> int:
	for i: int in kelp.size():
		if kelp[i].has_point(p):
			return i
	return -1


func edible_count() -> int:
	var n: int = 0
	for f: Fish in fishes:
		if f.tier < p_tier and not f.leaving:
			n += 1
	return n


func find_fish(id: int) -> Fish:
	for f: Fish in fishes:
		if f.id == id:
			return f
	return null


## Player position drawn this frame: inside the burp bubble it floats from
## the catch point to the safe spot (ease in-out).
func player_draw_pos() -> Vector2:
	if p_state == PState.BUBBLE:
		var k: float = clampf(p_state_t / RbBalance.CATCH_BUBBLE_FLOAT, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		return p_bubble_from.lerp(p_bubble_to, k)
	return p_pos


# ---------------------------------------------------------------- input


func set_aim(aim: Vector2) -> void:
	p_aim = Vector2(
		clampf(aim.x, RbBalance.POND.position.x, RbBalance.POND.end.x),
		clampf(aim.y, RbBalance.POND.position.y, RbBalance.POND.end.y)
	)


# ---------------------------------------------------------------- step


func step(dt: float) -> void:
	time += dt
	if cleared:
		clear_t += dt
		_step_fish(dt)
		_step_player(dt)
		_remove_gone()
		return
	if restarting:
		_step_restart(dt)
		return
	_step_spawns(dt)
	_step_scripted()
	_step_pickups(dt)
	_step_player(dt)
	_step_fish(dt)
	_interact()
	_remove_gone()
	_update_cues(dt)


func _emit(type: String, data: Dictionary = {}) -> void:
	data["type"] = type
	events.append(data)


func _step_player(dt: float) -> void:
	p_immune = maxf(0.0, p_immune - dt)
	shield_t = maxf(0.0, shield_t - dt)
	match p_state:
		PState.GULP:
			p_state_t += dt
			if p_state_t >= RbBalance.GULP_S:
				p_state = PState.BUBBLE
				p_state_t = 0.0
				p_bubble_from = p_pos
				p_bubble_to = safe_spot()
				_emit("burp", {"from": p_bubble_from, "to": p_bubble_to})
			return
		PState.BUBBLE:
			p_state_t += dt
			if p_state_t >= RbBalance.CATCH_BUBBLE_FLOAT:
				p_pos = p_bubble_to
				p_state = PState.FREE
				p_state_t = 0.0
				p_vel = Vector2.ZERO
				p_aim = p_pos
				p_immune = RbBalance.CATCH_IMMUNITY
				catcher_id = -1
				_emit("bubble_pop", {"pos": p_pos})
			return
	var max_v: float = RbBalance.player_speed(easy)
	if p_in_kelp >= 0:
		max_v *= RbBalance.KELP_SPEED_MULT
	var to_aim: Vector2 = p_aim - p_pos
	var dist: float = to_aim.length()
	var want := Vector2.ZERO
	if dist > 0.5:
		want = to_aim / dist * minf(max_v, dist * RbBalance.ARRIVE_GAIN)
	var k: float = 1.0 - exp(-dt / RbBalance.steer_tau(easy))
	p_vel += (want - p_vel) * k
	p_pos += p_vel * dt
	if p_bump_t > 0.0:
		p_bump_t -= dt
		p_pos += p_bump_v * dt
	var r: float = player_r()
	var pond: Rect2 = RbBalance.POND
	p_pos.x = clampf(p_pos.x, pond.position.x + r, pond.end.x - r)
	p_pos.y = clampf(p_pos.y, pond.position.y + r, pond.end.y - r)
	if absf(p_vel.x) > RbBalance.FACE_DEADBAND:
		p_facing = 1.0 if p_vel.x > 0.0 else -1.0
	var ki: int = kelp_index(p_pos)
	if ki >= 0 and ki != p_in_kelp:
		_emit("kelp_enter", {"index": ki})
	p_in_kelp = ki


func _step_fish(dt: float) -> void:
	var pond: Rect2 = RbBalance.POND
	var chase_v: float = RbBalance.CHASE_SPEED_K * RbBalance.player_speed(easy)
	for f: Fish in fishes:
		f.gulp_t = maxf(0.0, f.gulp_t - dt)
		f.bump_cd = maxf(0.0, f.bump_cd - dt)
		f.flee_cd = maxf(0.0, f.flee_cd - dt)
		var v := Vector2(f.dir * f.speed, 0.0)
		v.y = RbBalance.FISH_WAVE_V * sin(f.wave_phase + time * TAU / RbBalance.FISH_WAVE_PERIOD)
		if f.leaving:
			v = Vector2(f.dir * maxf(f.speed * 2.5, 420.0), 0.0)
		elif f.chase_t > 0.0:
			f.chase_t -= dt
			var to_p: Vector2 = p_pos - f.pos
			if p_in_kelp >= 0 or p_state != PState.FREE:
				f.chase_t = 0.0
			elif to_p.length() > 1.0:
				v = to_p.normalized() * chase_v
		elif f.flee_t > 0.0:
			f.flee_t -= dt
			var away: Vector2 = f.pos - p_pos
			if away.length() > 1.0:
				v = away.normalized() * f.speed * RbBalance.FLEE_MULT
		f.vel = v
		f.pos += v * dt
		if f.bump_t > 0.0:
			f.bump_t -= dt
			f.pos += f.bump_v * dt
		var fr: float = RbBalance.body_r(f.tier)
		f.pos.y = clampf(
			f.pos.y, pond.position.y + RbBalance.SPAWN_MARGIN_Y * 0.5, pond.end.y - fr * 0.5
		)
		if absf(v.x) > RbBalance.FACE_DEADBAND * 0.5:
			f.facing = 1.0 if v.x > 0.0 else -1.0


func _remove_gone() -> void:
	var keep: Array[Fish] = []
	for f: Fish in fishes:
		var l: float = RbBalance.tier_len(f.tier)
		var gone_r: bool = f.pos.x > RbBalance.DESIGN_W + l and f.vel.x > 0.0
		var gone_l: bool = f.pos.x < -l and f.vel.x < 0.0
		if not (gone_r or gone_l):
			keep.append(f)
	fishes = keep


func _interact() -> void:
	if p_state != PState.FREE:
		return
	var pr: float = player_r()
	var reach: float = RbBalance.eat_reach(easy)
	var eaten: Array[Fish] = []
	for f: Fish in fishes:
		if f.leaving:
			continue
		var fr: float = RbBalance.body_r(f.tier)
		var d: float = p_pos.distance_to(f.pos)
		if f.tier < p_tier:
			if d < pr + fr * 0.5 + reach:
				eaten.append(f)
		elif f.tier > p_tier:
			var catch_d: float = (fr * 0.8 + pr * 0.5) * RbBalance.catch_scale(easy)
			if d < catch_d and p_immune <= 0.0 and p_in_kelp < 0:
				if shield_t > 0.0:
					_shield_block(f)
				else:
					_caught(f)
					return
		else:
			if d < pr + fr and f.bump_cd <= 0.0:
				_bump(f, d)
	for f: Fish in eaten:
		_eat(f)


func _eat(f: Fish) -> void:
	fishes.erase(f)
	eats += 1
	p_food += f.tier
	_emit("eat", {"tier": f.tier, "pos": f.pos, "fish_id": f.id})
	while p_food >= need_now() and p_tier < tier_cap():
		p_food -= need_now()
		var had_danger: bool = false
		for o: Fish in fishes:
			if o.tier == p_tier + 1:
				had_danger = true
		p_tier += 1
		p_immune = maxf(p_immune, RbBalance.GROW_IMMUNITY)
		_emit("grow", {"tier": p_tier})
		if had_danger:
			_emit("tink")
	if p_tier >= tier_cap():
		p_food = mini(p_food, need_now())
	if goal == "grow" and p_tier >= target:
		_clear()


func _bump(f: Fish, d: float) -> void:
	var n: Vector2 = (f.pos - p_pos) / d if d > 0.01 else Vector2(p_facing, 0.0)
	var v: float = (RbBalance.SAME_TIER_PUSH * 0.5) / RbBalance.SAME_TIER_PUSH_S
	f.bump_v = n * v
	f.bump_t = RbBalance.SAME_TIER_PUSH_S
	f.bump_cd = RbBalance.BUMP_COOLDOWN_S
	p_bump_v = -n * v
	p_bump_t = RbBalance.SAME_TIER_PUSH_S
	bumps += 1
	_emit("boink", {"pos": (f.pos + p_pos) * 0.5})


func _shield_block(f: Fish) -> void:
	shield_t = 0.0
	p_immune = RbBalance.GROW_IMMUNITY
	var n: Vector2 = (f.pos - p_pos).normalized()
	f.bump_v = n * 600.0
	f.bump_t = 0.2
	f.chase_t = 0.0
	_emit("bonk", {"pos": (f.pos + p_pos) * 0.5})


func _caught(f: Fish) -> void:
	catches += 1
	catch_times.append(time)
	catcher_id = f.id
	f.gulp_t = 0.3
	f.chase_t = 0.0
	p_vel = Vector2.ZERO
	p_bump_t = 0.0
	_emit("caught", {"pos": p_pos, "fish_id": f.id})
	if easy:
		_start_gulp()
		return
	p_food = 0
	if bobler < 0:
		_start_gulp()
	elif bobler > 0:
		bobler -= 1
		_emit("bobler_lost", {"left": bobler})
		_start_gulp()
	else:
		_start_restart()


func _start_gulp() -> void:
	p_state = PState.GULP
	p_state_t = 0.0


## Hint trigger in Lett: HINT_CATCHES catches within HINT_CATCH_WINDOW s.
func recent_catches() -> int:
	var n: int = 0
	for t: float in catch_times:
		if time - t <= RbBalance.HINT_CATCH_WINDOW:
			n += 1
	return n


func _start_restart() -> void:
	restarting = true
	restart_t = 0.0
	restarts += 1
	catcher_id = -1
	_emit("restart")


func _step_restart(dt: float) -> void:
	restart_t += dt
	var t_dim: float = RbBalance.RESTART_DIM_S
	var t_off: float = t_dim + RbBalance.RESTART_SWIM_OFF_S
	var t_end: float = t_off + RbBalance.RESTART_LIFT_S
	if restart_t < t_dim:
		dim = RbBalance.RESTART_DIM * restart_t / t_dim
	elif restart_t < t_off:
		dim = RbBalance.RESTART_DIM
		for f: Fish in fishes:
			if not f.leaving:
				f.leaving = true
				f.dir = -1.0 if f.pos.x < RbBalance.DESIGN_W * 0.5 else 1.0
		var k: float = (restart_t - t_dim) / RbBalance.RESTART_SWIM_OFF_S
		p_pos = p_pos.lerp(_pond_center(), clampf(k * 2.0, 0.0, 1.0))
		if p_tier != RbBalance.PLAYER_START_TIER:
			p_tier = RbBalance.PLAYER_START_TIER
			p_food = 0
	else:
		dim = (
			RbBalance.RESTART_DIM * maxf(0.0, 1.0 - (restart_t - t_off) / RbBalance.RESTART_LIFT_S)
		)
	_step_fish(dt)
	_remove_gone()
	if restart_t >= t_end:
		restarting = false
		dim = 0.0
		fishes.clear()
		p_pos = _pond_center()
		p_aim = p_pos
		p_vel = Vector2.ZERO
		p_tier = RbBalance.PLAYER_START_TIER
		p_food = 0
		p_state = PState.FREE
		p_immune = RbBalance.CATCH_IMMUNITY
		bobler = bobler_max
		_spawn_t = 0.0
		_place_start_fish()
		_emit("restart_done")


func _pond_center() -> Vector2:
	return RbBalance.POND.get_center()


func _clear() -> void:
	if cleared:
		return
	cleared = true
	clear_t = 0.0
	for f: Fish in fishes:
		f.leaving = true
		f.chase_t = 0.0
		f.dir = -1.0 if f.pos.x < p_pos.x else 1.0
	_emit("clear")


# ---------------------------------------------------------------- spawning


func _place_start_fish() -> void:
	var fixed: Array = level.get("start_fish", [])
	if restarts == 0 and not fixed.is_empty():
		for p: Vector2 in fixed:
			spawn_fish_at(1, p, -1.0 if rng.randf() < 0.5 else 1.0)
		return
	var n: int = fish_max / 2
	for i: int in n:
		var p := Vector2.ZERO
		for attempt: int in 30:
			p = Vector2(
				rng.randf_range(80.0, RbBalance.DESIGN_W - 80.0),
				rng.randf_range(
					RbBalance.POND.position.y + RbBalance.SPAWN_MARGIN_Y,
					RbBalance.POND.end.y - RbBalance.SPAWN_MARGIN_Y
				)
			)
			if p.distance_to(p_pos) >= RbBalance.START_CLEAR_R:
				break
		spawn_fish_at(1, p, -1.0 if rng.randf() < 0.5 else 1.0)


## Adds a fish (also used for scripted fish and by the tests).
func spawn_fish_at(tier: int, pos: Vector2, dir: float, speed_k: float = 1.0) -> Fish:
	var f := Fish.new()
	f.id = _next_id
	_next_id += 1
	f.tier = clampi(tier, RbBalance.TIER_MIN, RbBalance.TIER_MAX)
	f.pos = pos
	f.dir = dir
	f.facing = dir
	var base: float = RbBalance.FISH_BASE_SPEED + RbBalance.FISH_SPEED_PER_TIER * float(f.tier)
	f.speed = (
		base
		* rng.randf_range(RbBalance.FISH_SPEED_RAND_LO, RbBalance.FISH_SPEED_RAND_HI)
		* RbBalance.fish_speed_mult(easy)
		* world_speed
		* speed_k
	)
	f.wave_phase = rng.randf() * TAU
	f.vel = Vector2(dir * f.speed, 0.0)
	f.ring_on = easy
	f.ring_alpha = 1.0 if easy else 0.0
	fishes.append(f)
	return f


func _step_spawns(dt: float) -> void:
	if fishes.size() >= fish_max:
		_spawn_t = 0.0
		return
	_spawn_t += dt
	if _spawn_t < RbBalance.SPAWN_INTERVAL:
		return
	_spawn_t = 0.0
	var tier: int = roll_tier()
	var from_left: bool = rng.randf() < 0.5
	var l: float = RbBalance.tier_len(tier)
	var x: float = -l * 0.6 if from_left else RbBalance.DESIGN_W + l * 0.6
	var y: float = rng.randf_range(
		RbBalance.POND.position.y + RbBalance.SPAWN_MARGIN_Y,
		RbBalance.POND.end.y - RbBalance.SPAWN_MARGIN_Y
	)
	spawn_fish_at(tier, Vector2(x, y), 1.0 if from_left else -1.0)


## Tier roll for a new fish relative to the player's tier (GDD 4.5).
func roll_tier() -> int:
	var p: int = p_tier
	if no_big or edible_count() < RbBalance.ANTI_STARVE_MIN_EDIBLE:
		return _roll_edible(p)
	var e: float = RbBalance.SPAWN_EDIBLE_LETT if easy else RbBalance.SPAWN_EDIBLE_VANLIG
	var s: float = RbBalance.SPAWN_SAME_LETT if easy else RbBalance.SPAWN_SAME_VANLIG
	if breather:
		e += RbBalance.BREATHER_EDIBLE_BONUS
	var r: float = rng.randf()
	if r < e:
		return _roll_edible(p)
	if r < e + s:
		return p
	var step: int = 2 if rng.randf() < RbBalance.BIG_STEP2_CHANCE else 1
	return mini(p + step, RbBalance.TIER_MAX)


func _roll_edible(p: int) -> int:
	var tiers: Array[int] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for i: int in 3:
		var t: int = p - 3 + i
		if t >= RbBalance.TIER_MIN:
			tiers.append(t)
			weights.append(RbBalance.EDIBLE_TIER_WEIGHTS[i])
			total += RbBalance.EDIBLE_TIER_WEIGHTS[i]
	if tiers.is_empty():
		return RbBalance.TIER_MIN
	var r: float = rng.randf() * total
	for i: int in tiers.size():
		r -= weights[i]
		if r <= 0.0:
			return tiers[i]
	return tiers[tiers.size() - 1]


func _step_scripted() -> void:
	var sb: Variant = level.get("scripted_big", null)
	if _scripted_done or not sb is Dictionary:
		return
	var d: Dictionary = sb
	if time < float(d["t"]):
		return
	_scripted_done = true
	var tier: int = mini(p_tier + 1, RbBalance.TIER_MAX)
	var l: float = RbBalance.tier_len(tier)
	var f: Fish = spawn_fish_at(
		tier, Vector2(RbBalance.DESIGN_W + l * 0.6, float(d["y"])), -1.0, float(d["speed_k"])
	)
	f.scripted = true


func _step_pickups(dt: float) -> void:
	if goal == "pearls":
		match pearl_state:
			"wait":
				pearl_t -= dt
				if pearl_t <= 0.0:
					pearl_pos = _free_spot(RbBalance.PEARL_MIN_FROM_PLAYER, true)
					pearl_state = "open"
					pearl_t = 0.0
					_emit("pearl_open", {"pos": pearl_pos})
			"open":
				pearl_t += dt
				var take: float = player_r() + RbBalance.PEARL_TAKE_EXTRA
				if (
					p_state == PState.FREE
					and pearl_t >= RbBalance.PEARL_OPEN_S
					and p_pos.distance_to(pearl_pos) < take
				):
					pearls += 1
					pearl_state = "wait"
					pearl_t = RbBalance.PEARL_DELAY
					_emit("pearl_taken", {"n": pearls, "pos": pearl_pos})
					if pearls >= target:
						pearl_state = "none"
						_clear()
	var spots: Array = level.get("bobla_at", [])
	if spots.is_empty():
		return
	if powerup_on:
		if (
			p_state == PState.FREE
			and p_pos.distance_to(powerup_pos) < player_r() + RbBalance.POWERUP_BUBBLE_PX * 0.5
		):
			powerup_on = false
			shield_t = RbBalance.BOBLA_MAX_S
			powerup_t = RbBalance.POWERUP_EVERY
			_emit("bobla_on", {"pos": powerup_pos})
		return
	powerup_t -= dt
	if powerup_t <= 0.0:
		powerup_on = true
		powerup_pos = spots[0] if powerup_count == 0 else _free_spot(250.0, true)
		powerup_count += 1
		_emit("bobla_spawn", {"pos": powerup_pos})


## Random pond spot at least `min_d` from the player, outside kelp.
func _free_spot(min_d: float, avoid_kelp: bool) -> Vector2:
	var pond: Rect2 = RbBalance.POND.grow(-90.0)
	var best := pond.get_center()
	var best_d: float = -1.0
	for attempt: int in 40:
		var p := Vector2(
			rng.randf_range(pond.position.x, pond.end.x),
			rng.randf_range(pond.position.y, pond.end.y)
		)
		if avoid_kelp:
			var in_kelp: bool = false
			for r: Rect2 in kelp:
				if r.grow(40.0).has_point(p):
					in_kelp = true
			if in_kelp:
				continue
		var d: float = p.distance_to(p_pos)
		if d >= min_d:
			return p
		if d > best_d:
			best_d = d
			best = p
	return best


## Point nearest the pond centre that is at least SAFE_SPOT_CLEAR from every
## bigger fish (GDD 4.7); if none, the point farthest from them.
func safe_spot() -> Vector2:
	var pond: Rect2 = RbBalance.POND.grow(-100.0)
	var c: Vector2 = pond.get_center()
	var best := c
	var best_cd: float = INF
	var fallback := c
	var fallback_d: float = -1.0
	for iy: int in 13:
		for ix: int in 9:
			var p := Vector2(
				pond.position.x + pond.size.x * float(ix) / 8.0,
				pond.position.y + pond.size.y * float(iy) / 12.0
			)
			var near: float = INF
			for f: Fish in fishes:
				if f.tier > p_tier and not f.leaving:
					near = minf(near, p.distance_to(f.pos))
			if near >= RbBalance.SAFE_SPOT_CLEAR:
				var cd: float = p.distance_to(c)
				if cd < best_cd:
					best_cd = cd
					best = p
			if near > fallback_d:
				fallback_d = near
				fallback = p
	return best if best_cd < INF else fallback


# ---------------------------------------------------------------- cues


func _update_cues(dt: float) -> void:
	var cone: float = cos(deg_to_rad(RbBalance.MOUTH_OPEN_CONE_DEG))
	var mouth: bool = false
	var fwd := Vector2(p_facing, 0.0)
	for f: Fish in fishes:
		var d: float = p_pos.distance_to(f.pos)
		var kind: int = ring_kind(f)
		if kind == 1 and d < RbBalance.MOUTH_OPEN_RANGE and d > 0.1:
			if fwd.dot((f.pos - p_pos) / d) >= cone:
				mouth = true
		f.danger_near = kind == 2 and d < RbBalance.DANGER_FACE_RANGE and p_state == PState.FREE
		if easy:
			f.ring_on = true
			f.ring_alpha = 1.0
		else:
			if f.ring_on and d > RbBalance.RING_FADE_OUT:
				f.ring_on = false
			elif not f.ring_on and d < RbBalance.RING_FADE_IN:
				f.ring_on = true
			var tgt: float = 1.0 if f.ring_on else 0.0
			f.ring_alpha = move_toward(f.ring_alpha, tgt, dt / RbBalance.RING_FADE_S)
			_vanlig_behaviour(f, d, kind)
	p_mouth_target = mouth and p_state == PState.FREE


func _vanlig_behaviour(f: Fish, d: float, kind: int) -> void:
	if f.leaving or p_state != PState.FREE:
		return
	if kind == 2 and not f.chased and d < RbBalance.CHASE_RADIUS and p_in_kelp < 0:
		f.chased = true
		f.chase_t = RbBalance.CHASE_TIME
		if time - _swish_t >= 2.0:
			_swish_t = time
			_emit("swish", {"fish_id": f.id})
	elif kind == 1 and f.flee_t <= 0.0 and f.flee_cd <= 0.0 and d < RbBalance.FLEE_RADIUS:
		f.flee_t = RbBalance.FLEE_TIME
		f.flee_cd = RbBalance.FLEE_TIME + RbBalance.FLEE_COOLDOWN


# ---------------------------------------------------------------- hint


## Best hint target (GDD 8.3): nearest edible fish (or the pearl) whose
## straight path from the player stays HINT_SAFE_PATH from every bigger
## fish; else the nearest kelp; else the pond centre.
func hint_target() -> Vector2:
	var cands: Array[Vector2] = []
	if pearl_state == "open":
		cands.append(pearl_pos)
	if powerup_on:
		cands.append(powerup_pos)
	for f: Fish in fishes:
		if f.tier < p_tier and not f.leaving and RbBalance.POND.has_point(f.pos):
			cands.append(f.pos)
	var best := Vector2.ZERO
	var best_d: float = INF
	for c: Vector2 in cands:
		if not _path_safe(p_pos, c):
			continue
		var d: float = p_pos.distance_to(c)
		if d < best_d:
			best_d = d
			best = c
	if best_d < INF:
		return best
	var kd: float = INF
	for r: Rect2 in kelp:
		var d2: float = p_pos.distance_to(r.get_center())
		if d2 < kd:
			kd = d2
			best = r.get_center()
	return best if kd < INF else _pond_center()


func _path_safe(a: Vector2, b: Vector2) -> bool:
	for f: Fish in fishes:
		if f.tier <= p_tier or f.leaving:
			continue
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(f.pos, a, b)
		if q.distance_to(f.pos) < RbBalance.HINT_SAFE_PATH:
			return false
	return true
