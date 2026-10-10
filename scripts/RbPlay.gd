class_name RbPlay
extends Node

## Play controller for one level: touch steering (follow-the-finger, GDD 3),
## runs RbSim, mirrors it into the 3D fish views and the marks MultiMesh
## (rings, aim ring, bubbles), the HUD, the onboarding / idle hand, sounds,
## the flash limiter, the clear sequence and the win card. RbMain owns the
## screens; this node only plays.

signal map_requested
signal level_started(level_id: int)

const MAX_STEP: float = 1.0 / 30.0
const GILL_EVERY_S: float = 1.5

var world: RbWorld
var sfx: RbSfx
var music: RbMusic
var sim := RbSim.new()
var flash := RbFlashLimiter.new()
var hud: RbHud
var hand: RbHand
var card: RbWinCard
var dim_rect: ColorRect
var resume_disc: RbDisc
var player_view: RbFishView
var views: Dictionary = {}
var level_id: int = 0
var running: bool = false
var paused: bool = false
var less_motion: bool = false
## Test hook: the bot steers instead of a finger.
var auto_bot: bool = false
## Test hook: forced bobler count for the next level start (-1 = level value).
var force_bobler: int = -1
## Test hook: fixed seed for the next level start (0 = random).
var next_seed: int = 0
var finger_down: bool = false
var touched_once: bool = false
var card_shown_for: int = 0
var _finger: Vector2 = Vector2.ZERO
var _pointer: int = -1
var _aim_alpha: float = 0.0
var _morph: Dictionary = {}
var _idle_t: float = 0.0
var _hint_t: float = -1.0
var _hint_target: Vector2 = Vector2.ZERO
var _onboard_t: float = 0.0
var _onboard: bool = false
var _clear_real_t: float = -1.0
var _gill_t: float = 0.0
var _block_until: int = 0
var _real_t: float = 0.0
var _loop_c: Vector2 = Vector2.ZERO
var _loop_t: float = 0.0


func setup(w: RbWorld, s: RbSfx, m: RbMusic, top_frame: Control, center_frame: Control) -> void:
	world = w
	sfx = s
	music = m
	dim_rect = ColorRect.new()
	dim_rect.color = Color(0.0, 0.03, 0.05, 0.0)
	dim_rect.position = Vector2(-2000, -2000)
	dim_rect.size = Vector2(6000, 6000)
	dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_frame.add_child(dim_rect)
	hand = RbHand.new()
	center_frame.add_child(hand)
	hud = RbHud.new()
	top_frame.add_child(hud)
	hud.visible = false
	card = RbWinCard.new()
	center_frame.add_child(card)
	card.replay_pressed.connect(func() -> void: start_level(level_id))
	card.map_pressed.connect(func() -> void: map_requested.emit())
	card.next_pressed.connect(_on_next)
	resume_disc = RbDisc.new()
	resume_disc.icon = "play"
	resume_disc.disc_radius = 120.0
	resume_disc.size = Vector2(300, 300)
	resume_disc.position = Vector2(540 - 150, 960 - 150)
	resume_disc.visible = false
	resume_disc.tapped.connect(resume)
	center_frame.add_child(resume_disc)
	set_process(false)


# ---------------------------------------------------------------- levels


func start_level(id: int) -> void:
	level_id = id
	card.hide_card()
	card_shown_for = 0
	sim.setup(id, RbGame.easy, next_seed, force_bobler)
	_clear_views()
	player_view = RbFishView.new()
	player_view.less_motion = less_motion
	world.actors.add_child(player_view)
	player_view.setup("player", sim.p_tier, 0.0)
	player_view.face_now(1.0)
	world.show_gameplay(true)
	world.set_kelp_patches(sim.kelp)
	world.show_shell(false)
	world.reset_zoom()
	world.intro_zoom()
	hud.setup(sim.goal, sim.target, sim.bobler)
	hud.less_motion = less_motion
	hud.visible = true
	flash = RbFlashLimiter.new()
	running = true
	paused = false
	resume_disc.visible = false
	dim_rect.color.a = 0.0
	finger_down = false
	touched_once = false
	_pointer = -1
	_aim_alpha = 0.0
	_morph.clear()
	_idle_t = 0.0
	_hint_t = -1.0
	_onboard = bool(sim.level.get("onboarding", false))
	_onboard_t = 0.0
	_clear_real_t = -1.0
	_gill_t = 0.0
	hand.alpha = 0.0
	hand.queue_redraw()
	block_input(RbBalance.HOLDOVER_MS)
	sfx.play("intro")
	sfx.set_ambience(true)
	set_process(true)
	level_started.emit(id)
	_sync_all(0.0)


func stop() -> void:
	running = false
	set_process(false)
	card.hide_card()
	hud.visible = false
	hand.alpha = 0.0
	hand.queue_redraw()
	resume_disc.visible = false
	dim_rect.color.a = 0.0
	_clear_views()
	world.show_gameplay(false)
	sfx.set_ambience(false)


func _clear_views() -> void:
	for v: Node in views.values():
		(v as Node).queue_free()
	views.clear()
	if player_view != null:
		player_view.queue_free()
		player_view = null


func _on_next() -> void:
	var nxt: int = RbGame.next_level_after(level_id)
	if nxt > 0:
		start_level(nxt)
	else:
		map_requested.emit()


func card_visible() -> bool:
	return card.visible


func block_input(ms: int) -> void:
	_block_until = Time.get_ticks_msec() + ms
	RbDisc.block_input(ms)


func pause() -> void:
	if running:
		paused = true


func show_resume() -> void:
	if not running or card.visible:
		return
	paused = true
	resume_disc.visible = true
	dim_rect.color.a = 0.5


func resume() -> void:
	paused = false
	resume_disc.visible = false
	dim_rect.color.a = 0.0
	block_input(RbBalance.HOLDOVER_MS)


func set_less_motion(on: bool) -> void:
	less_motion = on
	hud.less_motion = on
	card.less_motion = on
	if player_view != null:
		player_view.less_motion = on
	for v: RbFishView in views.values():
		v.less_motion = on


# ---------------------------------------------------------------- input


## Screen (viewport) position -> design px on the play plane. The camera
## keeps the width, so one factor serves both axes on any aspect.
func to_design(p: Vector2) -> Vector2:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var k: float = RbBalance.DESIGN_W / vs.x
	return Vector2(540.0 + (p.x - vs.x * 0.5) * k, 960.0 + (p.y - vs.y * 0.5) * k)


## Touch-down allowed here? (GDD 3.2: not the home square, not the wrist strip.)
func in_steer_area(screen_p: Vector2) -> bool:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var k: float = RbBalance.DESIGN_W / vs.x
	if screen_p.x * k < RbBalance.HOME_SQUARE and screen_p.y * k < RbBalance.HOME_SQUARE:
		return false
	return (vs.y - screen_p.y) * k > (RbBalance.DESIGN_H - RbBalance.WRIST_Y)


func _input(event: InputEvent) -> void:
	if not running or paused or card.visible or sim.cleared:
		return
	var st := event as InputEventScreenTouch
	if st != null:
		if st.pressed:
			if Time.get_ticks_msec() < _block_until or not in_steer_area(st.position):
				return
			_touch_down(st.index, to_design(st.position))
		elif st.index == _pointer:
			_touch_up()
		return
	var sd := event as InputEventScreenDrag
	if sd != null and sd.index == _pointer and finger_down:
		_finger = to_design(sd.position)
		sim.set_aim(RbBalance.aim_from_finger(_finger))


func _touch_down(index: int, p: Vector2) -> void:
	_pointer = index
	finger_down = true
	_finger = p
	sim.set_aim(RbBalance.aim_from_finger(p))
	if not touched_once:
		touched_once = true
		_onboard = false
	_idle_t = 0.0
	_hint_t = -1.0
	hand.alpha = 0.0
	hand.queue_redraw()
	sfx.play("touch")


func _touch_up() -> void:
	finger_down = false
	_pointer = -1


## Test hook: a finger at a design position (down, move or up).
func test_touch(p: Vector2, down: bool) -> void:
	if down:
		if not finger_down:
			_touch_down(0, p)
		else:
			_finger = p
			sim.set_aim(RbBalance.aim_from_finger(p))
	else:
		_touch_up()


# ---------------------------------------------------------------- frame


func _process(delta: float) -> void:
	if not running:
		return
	_real_t += delta
	if paused:
		return
	var dt: float = delta
	if sim.cleared:
		if _clear_real_t < 0.0:
			_clear_real_t = 0.0
		_clear_real_t += delta
		if _clear_real_t < RbBalance.CLEAR_SLOWMO_S:
			dt *= RbBalance.CLEAR_SLOWMO
		_happy_loop(delta)
		if _clear_real_t >= RbBalance.CARD_DELAY_S and not card.visible:
			_show_card()
	else:
		_update_hints(delta)
		if auto_bot and not sim.restarting:
			sim.set_aim(RbBot.aim(sim))
		elif finger_down:
			sim.set_aim(RbBalance.aim_from_finger(_finger))
	var left: float = dt
	while left > 0.0:
		var h: float = minf(left, MAX_STEP)
		sim.step(h)
		left -= h
	_handle_events()
	_sync_all(delta)
	if card.visible and player_view != null:
		card.frame_player(player_view.position, player_view.current_len_px() / RbBalance.PX_PER_M)


func _happy_loop(delta: float) -> void:
	# The player swims a slow loop while the other fish leave (GDD 9).
	if _clear_real_t <= delta * 1.5:
		_loop_c = sim.p_pos.clamp(Vector2(260, 520), Vector2(820, 1380))
		_loop_t = 0.0
	if less_motion:
		return
	_loop_t += delta
	var a: float = _loop_t * 1.4
	sim.set_aim(_loop_c + Vector2(cos(a), sin(a) * 0.6) * 150.0)


func _show_card() -> void:
	var nxt: int = RbGame.next_level_after(level_id)
	var free_end: bool = not RbGame.full_unlock and level_id >= RbBalance.FREE_LEVELS
	card.show_card(
		nxt > 0 and not free_end,
		sim.p_tier if sim.goal == "pearls" else sim.target,
		sim.goal == "pearls"
	)
	card.start_tier = RbBalance.PLAYER_START_TIER
	card_shown_for = level_id
	block_input(RbBalance.HOLDOVER_MS)
	sfx.play("star")
	RbGame.level_card_shown.emit(level_id)
	if free_end:
		RbGame.free_levels_finished.emit()


func _update_hints(delta: float) -> void:
	if _onboard and not touched_once:
		_onboard_t += delta
		var t: float = _onboard_t - RbBalance.HINT_FIRST_S
		if t < 0.0:
			return
		var cyc: float = fmod(t, RbBalance.HINT_LOOP_S)
		if cyc < delta * 1.5 or _hint_target == Vector2.ZERO:
			_hint_target = _nearest_food()
		# Press just below the nearest small fish; the fish swims there.
		hand.tip = _hint_target + Vector2(0, RbBalance.FINGER_LIFT)
		hand.alpha = (
			clampf(cyc / 0.3, 0.0, 1.0) * clampf((RbBalance.HINT_LOOP_S - cyc) / 0.3, 0.0, 1.0)
		)
		hand.press = clampf((cyc - 0.4) / 0.2, 0.0, 1.0) if cyc < 1.9 else 0.0
		if less_motion:
			hand.press = 0.0
		if cyc > 0.5 and cyc < 1.9:
			sim.set_aim(_hint_target)
		hand.queue_redraw()
		return
	_idle_t += delta
	var want: bool = _idle_t >= RbBalance.hint_idle(sim.easy)
	if sim.easy and sim.recent_catches() >= RbBalance.HINT_CATCHES and _hint_t < 0.0:
		want = true
		sim.catch_times.clear()
	if want and _hint_t < 0.0:
		_hint_t = 0.0
		_idle_t = 0.0
		_hint_target = sim.hint_target()
		sfx.play("hint")
	if _hint_t >= 0.0:
		_hint_t += delta
		hand.tip = _hint_target
		var k: float = _hint_t / 1.5
		hand.alpha = clampf(_hint_t / 0.25, 0.0, 1.0) * clampf((1.5 - _hint_t) / 0.25, 0.0, 1.0)
		hand.press = 0.0 if less_motion else 0.5 + 0.5 * sin(k * TAU * 2.0)
		hand.queue_redraw()
		if _hint_t >= 1.5:
			_hint_t = -1.0
			hand.alpha = 0.0
			hand.queue_redraw()


func _nearest_food() -> Vector2:
	var best := RbBalance.POND.get_center()
	var bd: float = INF
	for f: RbSim.Fish in sim.fishes:
		if f.tier < sim.p_tier and RbBalance.POND.grow(-60.0).has_point(f.pos):
			var d: float = f.pos.distance_to(sim.p_pos)
			if d < bd:
				bd = d
				best = f.pos
	return best


func _handle_events() -> void:
	for e: Dictionary in sim.events:
		var type: String = e["type"]
		match type:
			"eat":
				sfx.eat()
				world.marks.burst(e["pos"], randi_range(6, 10), 140.0, 3.0, 6.0)
				if player_view != null:
					player_view.squash()
					var fx: float = (e["pos"] as Vector2).x - sim.p_pos.x
					if absf(fx) > 4.0:
						player_view.face_now(1.0 if fx > 0.0 else -1.0)
					if flash.allow(_real_t):
						player_view.flash = 0.6
			"grow":
				sfx.grow(int(e["tier"]))
				if player_view != null:
					player_view.grow_to(int(e["tier"]))
				if not less_motion:
					world.marks.burst(sim.p_pos, 24, 260.0, 4.0, 7.0, true)
				if flash.allow(_real_t) and player_view != null:
					player_view.flash = 1.0
			"tink":
				sfx.play("tink")
			"boink":
				sfx.play("boink")
			"swish":
				sfx.play("swish")
			"caught":
				sfx.play("gulp")
			"burp":
				sfx.play("burp")
			"bubble_pop":
				sfx.play("bubble_pop")
				world.marks.burst(e["pos"], 12, 180.0, 2.5, 5.0, true)
			"bobler_lost":
				sfx.play("bobler")
			"restart":
				sfx.play("rewind")
			"restart_done":
				if player_view != null:
					player_view.set_tier_now(sim.p_tier)
			"pearl_open":
				sfx.play("shell")
			"pearl_taken":
				sfx.pearl(int(e["n"]))
				world.marks.burst(e["pos"], 10, 160.0, 3.0, 6.0)
				if flash.allow(_real_t) and player_view != null:
					player_view.flash = 0.7
			"bobla_on":
				sfx.play("bobla_on")
				world.marks.burst(e["pos"], 14, 200.0, 3.0, 7.0, true)
			"bonk":
				sfx.play("bonk")
				world.marks.burst(e["pos"], 10, 200.0, 3.0, 6.0)
			"kelp_enter":
				sfx.play("kelp")
				world.kelp_shimmer()
			"clear":
				_on_clear()
	sim.events.clear()


func _on_clear() -> void:
	sfx.play("win")
	world.push_in()
	finger_down = false
	hand.alpha = 0.0
	hand.queue_redraw()
	RbGame.mark_cleared(level_id)


# ---------------------------------------------------------------- sync


func _sync_all(delta: float) -> void:
	var seen: Dictionary = {}
	var blobs: Array[Vector3] = []
	world.marks.begin()
	for f: RbSim.Fish in sim.fishes:
		seen[f.id] = true
		var v: RbFishView = views.get(f.id, null)
		if v == null:
			v = RbFishView.new()
			v.less_motion = less_motion
			world.actors.add_child(v)
			v.setup(f.tier, f.tier, randf() * TAU)
			v.face_now(f.facing)
			views[f.id] = v
		v.mouth_target = 1.0 if f.danger_near or f.gulp_t > 0.0 else 0.0
		v.flare_target = 1.0 if f.danger_near else 0.0
		v.dim_k = sim.dim
		v.sync(f.pos, f.vel, f.facing, delta)
		blobs.append(Vector3(f.pos.x, f.pos.y, RbBalance.tier_len(f.tier)))
		_ring_for(f, delta)
	for id: Variant in views.keys():
		if not seen.has(id):
			(views[id] as Node).queue_free()
			views.erase(id)
			_morph.erase(id)
	_sync_player(delta, blobs)
	if sim.powerup_on:
		var bob: float = 0.0 if less_motion else sin(_real_t * 2.0) * 10.0
		world.marks.add(
			RbMarks.Kind.POWERUP,
			sim.powerup_pos + Vector2(0, bob),
			RbBalance.POWERUP_BUBBLE_PX * 0.5 + 4.0,
			1.0
		)
	_sync_aim(delta)
	world.marks.step_bubbles(delta)
	world.marks.commit()
	world.set_blobs(blobs)
	if sim.pearl_state == "open":
		world.show_shell(
			true, sim.pearl_pos, clampf(sim.pearl_t / RbBalance.PEARL_OPEN_S, 0.0, 1.0)
		)
	else:
		world.show_shell(false)
	hud.set_state(sim.p_tier, sim.meter(), sim.pearls, sim.bobler)
	if not paused:
		dim_rect.color.a = sim.dim


func _ring_for(f: RbSim.Fish, delta: float) -> void:
	var kind: int = sim.ring_kind(f)
	var m: float = _morph.get(f.id, 1.0 if kind == 2 else 0.0)
	var want: float = 1.0 if kind == 2 else 0.0
	if less_motion:
		m = want
	else:
		m = move_toward(m, want, delta / RbBalance.RING_MORPH_S)
	_morph[f.id] = m
	if kind == 0 or f.leaving or sim.cleared:
		return
	world.marks.add_ring(f.pos, RbBalance.tier_len(f.tier), m, f.ring_alpha)


func _sync_player(delta: float, blobs: Array[Vector3]) -> void:
	if player_view == null:
		return
	var pos: Vector2 = sim.player_draw_pos()
	var gulping: bool = sim.p_state == RbSim.PState.GULP
	player_view.visible = not gulping
	player_view.mouth_target = 1.0 if sim.p_mouth_target else 0.0
	player_view.dim_k = sim.dim
	if player_view.tier != sim.p_tier and sim.restarting:
		player_view.set_tier_now(sim.p_tier)
	player_view.sync(pos, sim.p_vel, sim.p_facing, delta)
	var l: float = player_view.current_len_px()
	blobs.append(Vector3(pos.x, pos.y, l))
	var r: float = l * 0.62
	if sim.p_state == RbSim.PState.BUBBLE:
		world.marks.add(RbMarks.Kind.SHIELD, pos, r + 16.0, 1.0)
	elif sim.shield_t > 0.0:
		var a: float = clampf(sim.shield_t / 1.0, 0.35, 1.0)
		world.marks.add(RbMarks.Kind.SHIELD, pos, r + 22.0, a)
	if (
		sim.p_immune > 0.0
		and sim.p_state == RbSim.PState.FREE
		and sim.p_immune > RbBalance.GROW_IMMUNITY
	):
		world.marks.add(RbMarks.Kind.SHIMMER, pos, r + 10.0, clampf(sim.p_immune / 0.4, 0.0, 1.0))
	_gill_t += delta
	if _gill_t >= GILL_EVERY_S and sim.p_vel.length() > 60.0 and sim.p_state == RbSim.PState.FREE:
		_gill_t = 0.0
		world.marks.gill_trail(pos + Vector2(sim.p_facing * l * 0.22, -l * 0.05))


func _sync_aim(delta: float) -> void:
	if finger_down and not sim.cleared:
		_aim_alpha = minf(1.0, _aim_alpha + delta / RbBalance.AIM_FADE_IN_S)
	else:
		_aim_alpha = maxf(0.0, _aim_alpha - delta / RbBalance.AIM_FADE_OUT_S)
	if _aim_alpha > 0.0:
		world.marks.add(RbMarks.Kind.AIM, sim.p_aim, RbBalance.AIM_RING_PX * 0.5 + 10.0, _aim_alpha)
