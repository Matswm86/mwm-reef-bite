extends Node

## Dev-only screenshot bot. Run under Xvfb with a fresh user dir:
##   XDG_DATA_HOME=<tmp> CAPTURE_DIR=<dir> godot --audio-driver Dummy \
##     --display-driver x11 --resolution 1080x1920 res://tests/capture.tscn
## CAPTURE_PHASE:
##   shots (default) - L1 start on first launch with the hand; a real touch
##                     (aim ring, fish follows); L2 mid-level with rings
##                     (the scripted bigger fish); a catch (burp bubble);
##                     L1 win card; map; settings; L3 Bobla shield; L4
##                     pearls and kelp; Vanlig L2 with forced bobler and the
##                     gentle restart dim; resume disc. Prints draw calls.
##   shell           - inside MWM Play: Engine meta set, set_full_unlock(false),
##                     levels 1-3 on the map, L3 card without "next" emits
##                     free_levels_finished, own home disc and gear hidden
## Env RB_PROXY_FISH=1 forces the proxy fish; RB_QUALITY=low the Lav tier.

var out_dir: String = OS.get_environment("CAPTURE_DIR")
var main: RbMain
var _fails: int = 0
var _free_done: int = 0
var _cards: Array[int] = []


func _ready() -> void:
	if out_dir == "":
		out_dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var phase: String = OS.get_environment("CAPTURE_PHASE")
	if phase == "shell":
		Engine.set_meta(&"mwm_play_shell", true)
		RbGame.set_full_unlock(false)
	RbGame.free_levels_finished.connect(func() -> void: _free_done += 1)
	RbGame.level_card_shown.connect(func(id: int) -> void: _cards.append(id))
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _frames(5)
	var t0: int = Time.get_ticks_msec()
	if phase == "shell":
		await _phase_shell()
	else:
		await _phase_shots()
	print(
		(
			"CAPTURE DONE in %.1f s, checks failed: %d"
			% [(Time.get_ticks_msec() - t0) / 1000.0, _fails]
		)
	)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print(("CHECK ok   " if ok else "CHECK FAIL ") + what)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _wait(s: float) -> void:
	var end: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print(
		(
			"SHOT %s  draws=%d  tris=%dk"
			% [
				name,
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0)
			]
		)
	)


func _touch(screen_p: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = screen_p
	ev.pressed = down
	Input.parse_input_event(ev)


## Design px on the play plane -> screen px (inverse of RbPlay.to_design),
## so the touches land on the same pond spot at 1080x1920 and 1080x2400.
func _screen(design_p: Vector2) -> Vector2:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var k: float = RbBalance.DESIGN_W / vs.x
	return vs * 0.5 + (design_p - Vector2(540.0, 960.0)) / k


## Screen px for a point given in design px from the top-left (home square)
## or from the bottom edge (wrist strip), the way RbPlay.in_steer_area
## measures them.
func _screen_top_left(design_p: Vector2) -> Vector2:
	var k: float = RbBalance.DESIGN_W / get_viewport().get_visible_rect().size.x
	return design_p / k


func _screen_from_bottom(design_x: float, design_up: float) -> Vector2:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var k: float = RbBalance.DESIGN_W / vs.x
	return Vector2(design_x / k, vs.y - design_up / k)


func _drag(screen_p: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = screen_p
	Input.parse_input_event(ev)


## Runs the bot until the level is cleared (or `max_s` passes).
func _bot_until_clear(max_s: float) -> bool:
	var play: RbPlay = main.play
	play.auto_bot = true
	var end: int = Time.get_ticks_msec() + int(max_s * 1000.0)
	while not play.sim.cleared and Time.get_ticks_msec() < end:
		await get_tree().process_frame
	play.auto_bot = false
	return play.sim.cleared


func _phase_shots() -> void:
	var play: RbPlay = main.play
	print("first launch screen=%s level=%d" % [main.screen, play.level_id])
	_check("first launch opens level 1", main.screen == "play" and play.level_id == 1)
	_check("own home disc shown stand-alone", main.home.visible)
	await _wait(1.7)
	await _shot("01_l1_start_hand")
	_check("onboarding hand visible", play.hand.alpha > 0.5)
	# A real touch in the pond: aim ring, fish swims toward the aim (the
	# food magnet's fish, else 60 px above the finger in Lett).
	await _wait(0.4)
	var p0: Vector2 = play.sim.p_pos
	_touch(_screen(Vector2(800, 1250)), true)
	await _wait(0.2)
	_drag(_screen(Vector2(820, 1240)))
	await _wait(0.5)
	var want: Vector2 = play.sim.aim_for_finger(Vector2(820, 1240))
	_check(
		"touch steers through aim_for_finger (%s)" % want, play.sim.p_aim.distance_to(want) < 6.0
	)
	_check("fish swims toward the aim", play.sim.p_pos.distance_to(want) < p0.distance_to(want))
	_check("hand gone after the first touch", play.hand.alpha < 0.01)
	await _shot("02_l1_touch_aim")
	_touch(_screen(Vector2(820, 1240)), false)
	# Wrist strip and home square ignore touch-downs.
	var aim_before: Vector2 = play.sim.p_aim
	_touch(_screen_from_bottom(500.0, 120.0), true)
	await _frames(2)
	_touch(_screen_from_bottom(500.0, 120.0), false)
	_check("wrist strip touch ignored", play.sim.p_aim == aim_before)
	_touch(_screen_top_left(Vector2(100, 100)), true)
	await _frames(2)
	_touch(_screen_top_left(Vector2(100, 100)), false)
	_check("home square touch does not steer", play.sim.p_aim == aim_before)
	# Under a deep camera cutout the lowered home touch area must stay out
	# of the steer area (QA 2026-10-10 finding 4).
	main.fake_safe_top = 120.0
	main.apply_safe_area()
	var steer_top: float = _screen_top_left(Vector2(0, RbBalance.HOME_SQUARE)).y
	_check(
		"cutout: home touch area ends at the steer area (%.0f)" % main.home.get_global_rect().end.y,
		main.home.get_global_rect().end.y <= steer_top + 0.5
	)
	main.fake_safe_top = -1.0
	main.apply_safe_area()
	# Win card.
	_check("L1 cleared by the bot", await _bot_until_clear(60.0))
	var t_card: int = Time.get_ticks_msec() + 5000
	while not play.card.visible and Time.get_ticks_msec() < t_card:
		await get_tree().process_frame
	await _wait(0.6)
	print(
		(
			"  after clear: running=%s paused=%s cleared=%s clear_t=%.2f sim_t=%.1f"
			% [play.running, play.paused, play.sim.cleared, play.sim.clear_t, play.sim.time]
		)
	)
	_check("win card visible", play.card.visible)
	_check("level_card_shown(1)", _cards.has(1))
	await _shot("04_l1_win_card")
	# L2 mid-level with rings: scripted bigger fish arrives at 4 s.
	main.open_level(2)
	play.auto_bot = true
	await _wait(5.5)
	var danger: int = 0
	var edible: int = 0
	for f: RbSim.Fish in play.sim.fishes:
		var k: int = play.sim.ring_kind(f)
		danger += 1 if k == 2 else 0
		edible += 1 if k == 1 else 0
	_check(
		"L2 shows edible and danger fish (%d / %d)" % [edible, danger], edible > 0 and danger > 0
	)
	await _shot("03_l2_mid_rings")
	# A catch: a bigger fish on the player -> burp bubble (Lett).
	play.auto_bot = false
	await _frames(2)
	var tier0: int = play.sim.p_tier
	var food0: int = play.sim.p_food
	play.sim.p_immune = 0.0
	play.sim.shield_t = 0.0
	play.sim.spawn_fish_at(play.sim.p_tier + 1, play.sim.p_pos, -1.0, 0.1)
	var t_end: int = Time.get_ticks_msec() + 2000
	while play.sim.p_state != RbSim.PState.BUBBLE and Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
	await _wait(0.5)
	_check("caught -> burp bubble", play.sim.p_state == RbSim.PState.BUBBLE)
	await _shot("05_l2_catch_bubble")
	_check("Lett catch keeps tier and meter", play.sim.p_tier == tier0 and play.sim.p_food == food0)
	play.auto_bot = false
	# Map and settings.
	main.open_map()
	await _wait(0.6)
	_check("map shows 5 levels stand-alone", _visible_discs() == 5)
	_check("gear visible stand-alone", main.map.gear.visible)
	await _shot("06_map")
	main.map.gear.press()
	await _wait(0.3)
	await _shot("07_settings")
	main._close_settings()
	# L3 Bobla: the bubble appears at 8 s at (540, 700).
	main.open_level(3)
	play.sim.time = 7.9
	play.sim.powerup_t = 0.05
	await _wait(0.3)
	_check(
		"Bobla bubble at (540, 700)",
		play.sim.powerup_on and play.sim.powerup_pos == Vector2(540, 700)
	)
	play.test_touch(Vector2(540, 820), true)
	t_end = Time.get_ticks_msec() + 4000
	while play.sim.shield_t <= 0.0 and Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
	play.test_touch(Vector2(540, 820), false)
	_check("Bobla shield on", play.sim.shield_t > 0.0)
	await _wait(0.4)
	await _shot("08_l3_bobla_shield")
	# L4 pearls among kelp.
	main.open_level(4)
	play.auto_bot = true
	await _wait(3.0)
	await _shot("09_l4_pearls_kelp")
	_check("L4 kelp patches = 3", play.sim.kelp.size() == 3)
	play.auto_bot = false
	t_end = Time.get_ticks_msec() + 4000
	while (
		not (play.sim.pearl_state == "open" and play.sim.pearl_t > 0.6)
		and Time.get_ticks_msec() < t_end
	):
		await get_tree().process_frame
	_check("pearl shell open", play.sim.pearl_state == "open")
	await _shot("09b_l4_pearl_open")
	# Vanlig with forced bobler (test-only) -> gentle restart.
	RbGame.set_difficulty(false)
	play.force_bobler = 3
	main.open_level(2)
	play.force_bobler = -1
	await _wait(0.5)
	_check("Vanlig forced bobler = 3", play.sim.bobler == 3)
	await _shot("10_vanlig_hud_bobler")
	for i: int in 4:
		play.sim.p_immune = 0.0
		play.sim.p_state = RbSim.PState.FREE
		play.sim.spawn_fish_at(play.sim.p_tier + 1, play.sim.p_pos, -1.0, 0.05)
		t_end = Time.get_ticks_msec() + 2500
		while (
			not play.sim.restarting
			and play.sim.p_state == RbSim.PState.FREE
			and Time.get_ticks_msec() < t_end
		):
			await get_tree().process_frame
		if play.sim.restarting:
			break
		await _wait(1.8)
	await _wait(0.7)
	_check("gentle restart after 3 bobler", play.sim.restarting)
	await _shot("11_vanlig_restart_dim")
	await _wait(1.5)
	_check(
		"restart done < 2 s: tier 2, bobler 3",
		not play.sim.restarting and play.sim.p_tier == 2 and play.sim.bobler == 3
	)
	RbGame.set_difficulty(true)
	# Resume disc after the app comes back.
	main._notification(NOTIFICATION_APPLICATION_PAUSED)
	main._notification(NOTIFICATION_APPLICATION_RESUMED)
	await _wait(0.3)
	_check("resume disc after background", play.resume_disc.visible and play.paused)
	await _shot("12_resume_disc")
	play.resume_disc.press()
	await _wait(0.4)
	_check("resumed", not play.paused)
	# Perf: a busy L2 frame.
	main.open_level(2)
	play.auto_bot = true
	await _wait(6.0)
	await _shot("13_l2_busy_perf")
	# Draw-call split: the same frame without the 2D layer.
	main.ui.visible = false
	await _shot("14_l2_busy_no_ui")
	main.ui.visible = true
	play.auto_bot = false


func _visible_discs() -> int:
	var n: int = 0
	for d: RbLevelDisc in main.map.discs:
		n += 1 if d.visible else 0
	return n


func _phase_shell() -> void:
	var play: RbPlay = main.play
	_check("shell: own home disc hidden", not main.home.visible)
	main.open_map()
	await _wait(0.5)
	_check("shell: map shows levels 1-3 only", _visible_discs() == 3)
	_check("shell: gear hidden", not main.map.gear.visible)
	await _shot("20_shell_map")
	main.open_level(3)
	_check("shell: home disc hidden in play", not main.home.visible)
	_check("shell: L3 cleared by the bot", await _bot_until_clear(90.0))
	var t_card: int = Time.get_ticks_msec() + 5000
	while not play.card.visible and Time.get_ticks_msec() < t_card:
		await get_tree().process_frame
	await _wait(0.6)
	_check("shell: L3 card has no next", play.card.visible and not play.card.has_next())
	_check("shell: free_levels_finished emitted", _free_done == 1)
	await _shot("21_shell_l3_card")
	RbGame.save_game()
	_check("shell: save file written", FileAccess.file_exists(RbState.SAVE_PATH))
