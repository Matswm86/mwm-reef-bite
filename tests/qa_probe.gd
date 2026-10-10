extends Node

## QA probes (game-qa, 2026-10-10). Not part of the game; `tests/*` is not
## exported. Run under Xvfb like tests/capture.tscn, with a fresh user dir:
##   XDG_DATA_HOME=<tmp> CAPTURE_DIR=<dir> QA_PHASE=<phase> godot \
##     --audio-driver Dummy --display-driver x11 --resolution 1080x1920 \
##     res://tests/qa_probe.tscn
## QA_PHASE:
##   draws - draw calls sampled over 90 frames per screen (median / max):
##           L1-L5 in play with the bot, L1 win card, map, settings, resume
##           disc. Add RB_QUALITY=low for the Lav tier.
##   home  - fake 120 px top cutout: two steering touches at (150, 300),
##           inside the pond but inside the lowered home hit rect.
##   look  - L2, L4 and L5 (Lett) with the bot: a shot every 1.5 s and the
##           player's screen position, tier and length, for contrast and
##           clutter measurements outside Godot.
##   kids  - headless-safe: a random "child" finger on L1-L3 Lett, 20 seeds.

const DT: float = 1.0 / 60.0

var out_dir: String = OS.get_environment("CAPTURE_DIR")
var main: RbMain


func _ready() -> void:
	if out_dir == "":
		out_dir = "user://qa"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var phase: String = OS.get_environment("QA_PHASE")
	if phase == "kids":
		_phase_kids()
		get_tree().quit(0)
		return
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _frames(5)
	match phase:
		"home":
			await _phase_home()
		"look":
			await _phase_look()
		_:
			await _phase_draws()
	print("QA PROBE DONE")
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _wait(s: float) -> void:
	var end: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _sample(label: String, n: int = 90) -> void:
	var v: Array[int] = []
	for i: int in n:
		await RenderingServer.frame_post_draw
		v.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	v.sort()
	print(
		(
			"DRAWS %-14s median %3d  max %3d  min %3d  (low=%s)"
			% [label, v[v.size() / 2], v[-1], v[0], RbGame.quality_low]
		)
	)


func _phase_draws() -> void:
	var play: RbPlay = main.play
	for id: int in range(1, 6):
		main.open_level(id)
		play.auto_bot = true
		await _wait(3.0)
		await _sample("L%d play" % id)
		play.auto_bot = false
	main.open_level(1)
	play.auto_bot = true
	var end: int = Time.get_ticks_msec() + 60000
	while not play.card.visible and Time.get_ticks_msec() < end:
		await get_tree().process_frame
	play.auto_bot = false
	await _wait(0.8)
	await _sample("L1 win card")
	main.ui.visible = false
	await _wait(0.2)
	await _sample("card no 2D")
	main.ui.visible = true
	await _wait(0.2)
	main.open_map()
	await _wait(0.6)
	await _sample("map")
	main.ui.visible = false
	await _wait(0.2)
	await _sample("map no 2D")
	main.ui.visible = true
	await _wait(0.2)
	main.map.gear.press()
	await _wait(0.4)
	await _sample("settings")
	main.ui.visible = false
	await _wait(0.2)
	await _sample("settings no 2D")
	main.ui.visible = true
	await _wait(0.2)
	main._close_settings()
	main.open_level(2)
	await _wait(0.5)
	main._notification(NOTIFICATION_APPLICATION_PAUSED)
	main._notification(NOTIFICATION_APPLICATION_RESUMED)
	await _wait(0.4)
	await _sample("resume disc")


func _touch(p: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = p
	ev.pressed = down
	Input.parse_input_event(ev)


func _phase_home() -> void:
	var play: RbPlay = main.play
	main.fake_safe_top = 120.0
	main.apply_safe_area()
	main.open_level(1)
	await _wait(1.0)
	print("home hit rect %s  disc centre %s" % [main.home.get_global_rect(), main.home.disc_center])
	# Control: two taps on the disc itself must leave the level.
	await _two_taps(Vector2(104, 188), "control tap on the disc")
	main.open_level(1)
	await _wait(1.0)
	# Pond touch inside the lowered home rect.
	var p := Vector2(150, 285)
	print("touch at %s in_steer_area=%s" % [p, play.in_steer_area(p)])
	await _two_taps(p, "steer touch in the pond")


func _two_taps(p: Vector2, label: String) -> void:
	var play: RbPlay = main.play
	_touch(p, true)
	await _wait(0.15)
	print("  %s down: finger_down=%s aim=%s" % [label, play.finger_down, play.sim.p_aim])
	_touch(p, false)
	await _wait(0.1)
	print(
		"  %s release 1: home guarding=%s screen=%s" % [label, main.home.is_guarding(), main.screen]
	)
	await _wait(0.6)
	_touch(p, true)
	await _wait(0.15)
	_touch(p, false)
	await _wait(0.4)
	print("  %s release 2 (0.85 s later): screen=%s" % [label, main.screen])


func _phase_look() -> void:
	var play: RbPlay = main.play
	for id: int in [2, 4, 5]:
		main.open_level(id)
		play.auto_bot = true
		await _wait(1.0)
		for k: int in 10:
			await _wait(1.5)
			var name: String = "look_l%d_%02d" % [id, k]
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png(out_dir.path_join(name + ".png"))
			var in_kelp: bool = false
			for r: Rect2 in play.sim.kelp:
				in_kelp = in_kelp or r.has_point(play.sim.p_pos)
			print(
				(
					"LOOK %s p=(%.0f, %.0f) tier=%d len=%.0f in_kelp=%s face=%.0f"
					% [
						name,
						play.sim.p_pos.x,
						play.sim.p_pos.y,
						play.sim.p_tier,
						RbBalance.TIER_BASE_LEN * pow(RbBalance.TIER_STEP, play.sim.p_tier - 1),
						in_kelp,
						play.sim.p_facing
					]
				)
			)
		if id == 4:
			for r: Rect2 in play.sim.kelp:
				print("KELP RECT %s" % r)
		play.auto_bot = false


## QA_EASY=0 runs the kids sims in Vanlig (default Lett).
func _kids_easy() -> bool:
	return OS.get_environment("QA_EASY") != "0"


## A child who puts the finger right ON the nearest food fish (not below it)
## and follows it, re-picking every 1.5 s. The aim goes through the game's
## own RbSim.aim_for_finger (food magnet, then the finger lift), so this
## shows whether "touch what you want" works.
func _kids_touch_food(id: int) -> void:
	var times: Array[float] = []
	var cleared: int = 0
	for s: int in 20:
		var sim := RbSim.new()
		sim.setup(id, _kids_easy(), 500 + s)
		var t: float = 0.0
		var target: RbSim.Fish = null
		var repick: float = 0.0
		while t < 240.0 and not sim.cleared:
			repick -= DT
			if repick <= 0.0 or target == null or not sim.fishes.has(target):
				target = null
				var best: float = INF
				for f: RbSim.Fish in sim.fishes:
					var d: float = f.pos.distance_to(sim.p_pos)
					if sim.ring_kind(f) == 1 and d < best:
						best = d
						target = f
				repick = 1.5
			if target != null:
				var fp: Vector2 = target.pos.clamp(Vector2(20, 260), Vector2(1060, 1660))
				# QA_NO_LIFT=1: what-if, the aim goes to the finger itself.
				var no_lift: bool = OS.get_environment("QA_NO_LIFT") == "1"
				sim.set_aim(fp if no_lift else sim.aim_for_finger(fp))
			sim.step(DT)
			sim.events.clear()
			t += DT
		if sim.cleared:
			cleared += 1
			times.append(t)
	times.sort()
	print(
		(
			"KIDS L%d finger ON the food: cleared %d/20 median %.0f s max %.0f s"
			% [
				id,
				cleared,
				times[times.size() / 2] if times.size() > 0 else -1.0,
				times[-1] if times.size() > 0 else -1.0
			]
		)
	)


## A non-reading child: puts a finger down at a random spot in the pond,
## holds it 1-4 s (sometimes dragging), lifts it for 0-2 s, repeats.
func _phase_kids() -> void:
	for id: int in [1, 2, 3]:
		_kids_touch_food(id)
	for id: int in [1, 2, 3]:
		var times: Array[float] = []
		var cleared: int = 0
		var catches: Array[int] = []
		for s: int in 20:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + s
			var sim := RbSim.new()
			sim.setup(id, _kids_easy(), 500 + s)
			var t: float = 0.0
			var hold: float = 0.0
			var gap: float = 0.0
			var finger := Vector2(-1, -1)
			while t < 240.0 and not sim.cleared:
				if hold > 0.0:
					hold -= DT
					if rng.randf() < 0.01:
						finger += Vector2(rng.randf_range(-150, 150), rng.randf_range(-150, 150))
						finger = finger.clamp(Vector2(20, 260), Vector2(1060, 1660))
					sim.set_aim(sim.aim_for_finger(finger))
					if hold <= 0.0:
						gap = rng.randf_range(0.0, 2.0)
				elif gap > 0.0:
					gap -= DT
				else:
					finger = Vector2(rng.randf_range(20, 1060), rng.randf_range(260, 1660))
					hold = rng.randf_range(1.0, 4.0)
				sim.step(DT)
				sim.events.clear()
				t += DT
			if sim.cleared:
				cleared += 1
				times.append(t)
			catches.append(sim.catches)
		times.sort()
		catches.sort()
		print(
			(
				"KIDS L%d random: cleared %d/20 median %.0f s max %.0f s catches %d max %d"
				% [
					id,
					cleared,
					times[times.size() / 2] if times.size() > 0 else -1.0,
					times[-1] if times.size() > 0 else -1.0,
					catches[catches.size() / 2],
					catches[-1]
				]
			)
		)
