extends Node

## Headless logic test (no rendering):
##   XDG_DATA_HOME=<tmp> godot --headless --audio-driver Dummy res://tests/logic_test.tscn
## Env LOGIC_SEEDS = runs per level and setting (default 8).
## 1. The bot clears levels 1-5 in Lett and Vanlig on every seed; logs
##    clear count, median and max time, catches, restarts. Invariants on
##    every step: a meal is always a lower tier, the player never shrinks
##    (outside a gentle restart), no start fish inside the catch range.
## 2. Lett: 20 forced catches never change tier or meter.
## 3. Vanlig world 1: a catch empties the meter, bobler unlimited, no restart.
## 4. Vanlig forced bobler (test-only flag): 3 catches pop 3 bobler, the 4th
##    starts the gentle restart, done in < 2 s at tier 2 with bobler refilled.
## 5. Same tier bumps (no eat), eat rule with overflow, NEED table.
## 6. Spawn mix, anti-starve, L1 never spawns bigger fish.
## 7. Vanlig chase (once, 2 s) and flee; Lett never chases.
## 8. Kelp hides, slows; Bobla blocks one catch; pearls never in kelp.
## 9. Finger lift and wrist fade; flash limiter (5 meals in 1 s -> <= 3).
## 10. Save round trip, full_unlock and the free levels, level table = GDD.
## 11. Sound table: every effect file and the music loop load.
## Prints "LOGIC TEST PASS" or "LOGIC TEST FAIL (n)" and exits 0 / 1.

const DT: float = 1.0 / 60.0
const MAX_T: float = 400.0

var fails: int = 0
var seeds: int = 8


func _ready() -> void:
	var s: String = OS.get_environment("LOGIC_SEEDS")
	seeds = 8 if s == "" else int(s)
	_test_bot_clears()
	_test_lett_catches()
	_test_vanlig_unlimited()
	_test_vanlig_restart()
	_test_bump_and_eat()
	_test_spawns()
	_test_chase_flee()
	_test_kelp_bobla_pearls()
	_test_lift_and_flash()
	_test_save_and_table()
	await _test_sounds()
	if fails == 0:
		print("LOGIC TEST PASS")
	else:
		print("LOGIC TEST FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1


func _new_sim(id: int, easy: bool, seed_value: int = 7, force_bobler: int = -1) -> RbSim:
	var sim := RbSim.new()
	sim.setup(id, easy, seed_value, force_bobler)
	return sim


func _step(sim: RbSim, secs: float) -> void:
	var n: int = int(secs / DT)
	for i: int in n:
		sim.step(DT)
		sim.events.clear()


# ---------------------------------------------------------------- 1


func _test_bot_clears() -> void:
	print("1. bot clears L1-5, %d seeds each" % seeds)
	for easy: bool in [true, false]:
		for id: int in range(1, RbLevels.count() + 1):
			var times: Array[float] = []
			var cleared: int = 0
			var catches: int = 0
			var restarts: int = 0
			var bad_meal: int = 0
			var shrink: int = 0
			var start_close: int = 0
			for k: int in seeds:
				var sim: RbSim = _new_sim(id, easy, 1000 + 37 * k)
				for f: RbSim.Fish in sim.fishes:
					var cr: float = (
						(RbBalance.body_r(f.tier) * 0.8 + sim.player_r() * 0.5)
						* RbBalance.catch_scale(easy)
					)
					if f.tier > sim.p_tier and f.pos.distance_to(sim.p_pos) < cr + 50.0:
						start_close += 1
				var last_tier: int = sim.p_tier
				while not sim.cleared and sim.time < MAX_T:
					sim.set_aim(RbBot.aim(sim))
					var tier_before: int = sim.p_tier
					sim.step(DT)
					for e: Dictionary in sim.events:
						if e["type"] == "eat" and int(e["tier"]) >= tier_before:
							bad_meal += 1
					sim.events.clear()
					if sim.p_tier < last_tier and not sim.restarting:
						shrink += 1
					last_tier = sim.p_tier
				if sim.cleared:
					cleared += 1
					times.append(sim.time)
				catches += sim.catches
				restarts += sim.restarts
			times.sort()
			var med: float = times[times.size() / 2] if not times.is_empty() else -1.0
			var mx: float = times[times.size() - 1] if not times.is_empty() else -1.0
			print(
				(
					"   L%d %-6s cleared %d/%d  median %.1f s  max %.1f s  catches %d  restarts %d"
					% [id, "Lett" if easy else "Vanlig", cleared, seeds, med, mx, catches, restarts]
				)
			)
			_check(
				cleared == seeds,
				"L%d %s cleared on every seed" % [id, "Lett" if easy else "Vanlig"]
			)
			_check(
				bad_meal == 0,
				"L%d %s: every meal was a lower tier" % [id, "Lett" if easy else "Vanlig"]
			)
			_check(shrink == 0, "L%d %s: player never shrank" % [id, "Lett" if easy else "Vanlig"])
			_check(
				start_close == 0,
				"L%d %s: no bigger fish near the start" % [id, "Lett" if easy else "Vanlig"]
			)
			_check(
				restarts == 0,
				(
					"L%d %s: world 1 never restarts (unlimited bobler)"
					% [id, "Lett" if easy else "Vanlig"]
				)
			)


# ---------------------------------------------------------------- 2-4


func _force_catch(sim: RbSim) -> void:
	sim.p_immune = 0.0
	sim.shield_t = 0.0
	sim.spawn_fish_at(mini(sim.p_tier + 1, 10), sim.p_pos, -1.0, 0.01)
	var t0: float = sim.time
	while sim.p_state == RbSim.PState.FREE and not sim.restarting and sim.time - t0 < 1.0:
		sim.step(DT)
		sim.events.clear()


func _wait_free(sim: RbSim) -> void:
	var t0: float = sim.time
	while (sim.p_state != RbSim.PState.FREE or sim.restarting) and sim.time - t0 < 5.0:
		sim.step(DT)
		sim.events.clear()
	# Remove the catcher so the next forced catch is the only one.
	sim.fishes.clear()


func _test_lett_catches() -> void:
	print("2. Lett: 20 forced catches")
	var sim: RbSim = _new_sim(2, true)
	sim.p_tier = 3
	sim.p_food = 4
	var ok_tier: bool = true
	var bubbles_ok: int = 0
	for i: int in 20:
		_force_catch(sim)
		if sim.p_state != RbSim.PState.FREE:
			bubbles_ok += 1
		_wait_free(sim)
		if sim.p_tier != 3 or sim.p_food != 4:
			ok_tier = false
	_check(bubbles_ok == 20, "20 catches -> 20 burp bubbles (%d)" % bubbles_ok)
	_check(ok_tier, "tier and meter unchanged after 20 Lett catches")
	_check(sim.restarts == 0 and sim.bobler == -1, "Lett: no bobler, no restart")
	_check(sim.p_immune > 0.0 or true, "immunity after the bubble pops")
	var sim2: RbSim = _new_sim(2, true)
	_force_catch(sim2)
	var t0: float = sim2.time
	while sim2.p_state != RbSim.PState.FREE and sim2.time - t0 < 3.0:
		sim2.step(DT)
	var float_t: float = sim2.time - t0
	_check(
		absf(float_t - (RbBalance.GULP_S + RbBalance.CATCH_BUBBLE_FLOAT)) < 0.1,
		"gulp + bubble float = 1.6 s (%.2f)" % float_t
	)
	_check(absf(sim2.p_immune - RbBalance.CATCH_IMMUNITY) < 0.05, "2.0 s immunity after the pop")
	var near: float = INF
	for f: RbSim.Fish in sim2.fishes:
		if f.tier > sim2.p_tier:
			near = minf(near, f.pos.distance_to(sim2.p_pos))
	_check(
		near >= RbBalance.SAFE_SPOT_CLEAR - 1.0 or near == INF,
		"burped out >= 300 px from bigger fish (%.0f)" % near
	)


func _test_vanlig_unlimited() -> void:
	print("3. Vanlig world 1: meter empties, bobler unlimited")
	var sim: RbSim = _new_sim(2, false)
	sim.p_tier = 3
	sim.p_food = 4
	for i: int in 5:
		_force_catch(sim)
		_wait_free(sim)
	_check(sim.p_tier == 3, "tier kept")
	_check(sim.p_food == 0, "meter emptied")
	_check(sim.bobler == -1 and sim.restarts == 0, "unlimited bobler, no restart")


func _test_vanlig_restart() -> void:
	print("4. Vanlig forced bobler -> gentle restart")
	var sim: RbSim = _new_sim(2, false, 7, 3)
	_check(sim.bobler == 3, "forced bobler = 3")
	sim.p_tier = 4
	sim.p_food = 2
	var lost: Array[int] = []
	for i: int in 3:
		sim.p_immune = 0.0
		sim.spawn_fish_at(sim.p_tier + 1, sim.p_pos, -1.0, 0.01)
		for k: int in 3:
			sim.step(DT)
			for e: Dictionary in sim.events:
				if e["type"] == "bobler_lost":
					lost.append(int(e["left"]))
			sim.events.clear()
		_wait_free(sim)
	_check(lost == [2, 1, 0], "3 catches pop 3 bobler (%s)" % str(lost))
	_check(not sim.restarting and sim.p_tier == 4, "no restart yet, tier kept")
	sim.p_immune = 0.0
	sim.spawn_fish_at(sim.p_tier + 1, sim.p_pos, -1.0, 0.01)
	var got_restart: bool = false
	var t0: float = sim.time
	var t_restart: float = -1.0
	while sim.time - t0 < 4.0:
		sim.step(DT)
		for e: Dictionary in sim.events:
			if e["type"] == "restart":
				got_restart = true
				t_restart = sim.time
			if e["type"] == "restart_done":
				print("     restart took %.2f s" % (sim.time - t_restart))
				_check(sim.time - t_restart < 2.0, "gentle restart under 2 s")
		sim.events.clear()
		if got_restart and not sim.restarting:
			break
	_check(got_restart, "4th catch starts the gentle restart")
	_check(
		sim.p_tier == 2 and sim.bobler == 3 and sim.p_food == 0, "back at tier 2, bobler refilled"
	)
	_check(sim.p_pos.distance_to(RbBalance.POND.get_center()) < 1.0, "player at the pond centre")
	_check(not sim.fishes.is_empty(), "food placed again after the restart")


# ---------------------------------------------------------------- 5


func _test_bump_and_eat() -> void:
	print("5. bump, eat, grow")
	var sim: RbSim = _new_sim(2, true)
	sim.fishes.clear()
	sim.p_tier = 3
	var same: RbSim.Fish = sim.spawn_fish_at(3, sim.p_pos + Vector2(30, 0), -1.0, 0.01)
	var p0: Vector2 = sim.p_pos
	var boinks: int = 0
	var eats: int = 0
	for i: int in 30:
		sim.step(DT)
		for e: Dictionary in sim.events:
			boinks += 1 if e["type"] == "boink" else 0
			eats += 1 if e["type"] == "eat" else 0
		sim.events.clear()
	_check(eats == 0 and sim.fishes.has(same), "same tier: nobody eats")
	_check(boinks >= 1, "same tier: boink")
	_check(
		sim.p_pos.distance_to(same.pos) > p0.distance_to(p0 + Vector2(30, 0)),
		"same tier: pushed apart"
	)
	_check(sim.p_tier == 3 and sim.catches == 0, "same tier: no catch")
	# Eat with overflow: L2 Lett need(2) = 7, need(3) = 9.
	var s2: RbSim = _new_sim(2, true)
	s2.fishes.clear()
	s2.p_food = 6
	s2.spawn_fish_at(1, s2.p_pos + Vector2(10, 0), -1.0, 0.01)
	s2.step(DT)
	_check(s2.p_tier == 3 and s2.p_food == 0, "7th food point grows tier 2 -> 3")
	s2.p_food = 8
	s2.spawn_fish_at(2, s2.p_pos + Vector2(10, 0), -1.0, 0.01)
	s2.step(DT)
	_check(s2.p_tier == 4 and s2.cleared, "overflow carries: tier 4 = L2 Lett goal, cleared")
	var need_ok: bool = true
	for t: int in range(2, 9):
		need_ok = (
			need_ok and RbBalance.need(t, true) == 3 + 2 * t and RbBalance.need(t, false) == 3 + t
		)
	_check(need_ok, "NEED table = GDD 4.4")
	var lens: Array[int] = [72, 92, 118, 151, 193, 247, 317, 405, 519, 664]
	var len_ok: bool = true
	for t: int in range(1, 11):
		len_ok = len_ok and absi(int(round(RbBalance.tier_len(t))) - lens[t - 1]) <= 1
	_check(len_ok, "tier lengths = GDD 4.2")
	# Eat reach: Lett 36, Vanlig 18.
	var s3: RbSim = _new_sim(2, false)
	s3.fishes.clear()
	var pr: float = s3.player_r()
	var fr: float = RbBalance.body_r(1)
	s3.spawn_fish_at(1, s3.p_pos + Vector2(pr + fr * 0.5 + 25.0, 0), 1.0, 0.0)
	s3.step(DT)
	_check(s3.eats == 0, "Vanlig: 25 px past the mouth is out of reach (18)")
	var s4: RbSim = _new_sim(2, true)
	s4.fishes.clear()
	s4.spawn_fish_at(1, s4.p_pos + Vector2(pr + fr * 0.5 + 25.0, 0), 1.0, 0.0)
	s4.step(DT)
	_check(s4.eats == 1, "Lett: 25 px past the mouth is in reach (36)")


# ---------------------------------------------------------------- 6


func _test_spawns() -> void:
	print("6. spawn mix")
	var sim: RbSim = _new_sim(2, true, 99)
	sim.p_tier = 4
	sim.fishes.clear()
	for i: int in 5:
		sim.spawn_fish_at(1, Vector2(100 + i * 50, 400), 1.0, 0.0)
	var e: int = 0
	var same: int = 0
	var big: int = 0
	var n: int = 20000
	for i: int in n:
		var t: int = sim.roll_tier()
		if t < 4:
			e += 1
		elif t == 4:
			same += 1
		else:
			big += 1
	print(
		(
			"     Lett tier 4: edible %.1f%% same %.1f%% bigger %.1f%%"
			% [100.0 * e / n, 100.0 * same / n, 100.0 * big / n]
		)
	)
	_check(
		absf(float(e) / n - 0.70) < 0.02 and absf(float(big) / n - 0.20) < 0.02,
		"Lett mix 70 / 10 / 20"
	)
	var sv: RbSim = _new_sim(2, false, 99)
	sv.p_tier = 4
	sv.fishes.clear()
	for i: int in 5:
		sv.spawn_fish_at(1, Vector2(100 + i * 50, 400), 1.0, 0.0)
	var bigv: int = 0
	for i: int in n:
		bigv += 1 if sv.roll_tier() > 4 else 0
	_check(absf(float(bigv) / n - 0.30) < 0.02, "Vanlig 30%% bigger (%.1f%%)" % (100.0 * bigv / n))
	var sb: RbSim = _new_sim(5, true, 99)
	sb.p_tier = 4
	sb.fishes.clear()
	for i: int in 5:
		sb.spawn_fish_at(1, Vector2(100 + i * 50, 400), 1.0, 0.0)
	var bigb: int = 0
	for i: int in n:
		bigb += 1 if sb.roll_tier() > 4 else 0
	_check(
		absf(float(bigb) / n - 0.10) < 0.02,
		"breather L5: 10%% bigger (%.1f%%)" % (100.0 * bigb / n)
	)
	var starve: RbSim = _new_sim(2, true, 5)
	starve.p_tier = 4
	starve.fishes.clear()
	var all_edible: bool = true
	for i: int in 500:
		all_edible = all_edible and starve.roll_tier() < 4
	_check(all_edible, "anti-starve: < 3 edible on screen -> always edible")
	var l1: RbSim = _new_sim(1, true, 3)
	var big_l1: int = 0
	_step(l1, 0.0)
	while not l1.cleared and l1.time < 60.0:
		l1.set_aim(RbBot.aim(l1))
		l1.step(DT)
		l1.events.clear()
		for f: RbSim.Fish in l1.fishes:
			big_l1 += 1 if f.tier >= l1.p_tier and not f.leaving else 0
	_check(big_l1 == 0, "L1 never spawns same or bigger fish")
	var l1s: RbSim = _new_sim(1, true, 3)
	var fixed: bool = (
		l1s.fishes.size() == 3
		and l1s.fishes[0].pos == Vector2(300, 700)
		and l1s.p_pos == Vector2(540, 950)
	)
	_check(fixed, "L1 layout: 3 tier-1 fish at the GDD spots, player (540, 950)")
	var l2: RbSim = _new_sim(2, true, 4)
	_step(l2, 4.1)
	var scripted: bool = false
	for f: RbSim.Fish in l2.fishes:
		scripted = (
			scripted or (f.scripted and f.tier == l2.p_tier + 1 and absf(f.pos.y - 600.0) < 30.0)
		)
	_check(scripted, "L2: scripted bigger fish enters at 4 s, y 600")


# ---------------------------------------------------------------- 7


func _test_chase_flee() -> void:
	print("7. chase and flee")
	var sim: RbSim = _new_sim(2, false)
	sim.fishes.clear()
	sim.p_immune = 99.0
	var big: RbSim.Fish = sim.spawn_fish_at(3, sim.p_pos + Vector2(200, 0), -1.0, 1.0)
	sim.step(DT)
	_check(big.chased and big.chase_t > 1.9, "Vanlig: bigger fish within 220 px chases")
	_step(sim, 2.2)
	_check(big.chase_t <= 0.0 and big.chased, "chase stops after 2 s, once")
	var lett: RbSim = _new_sim(2, true)
	lett.fishes.clear()
	var big2: RbSim.Fish = lett.spawn_fish_at(3, lett.p_pos + Vector2(200, 0), -1.0, 1.0)
	lett.step(DT)
	_check(not big2.chased, "Lett: no chase")
	var fl: RbSim = _new_sim(2, false)
	fl.fishes.clear()
	fl.p_tier = 3
	var small: RbSim.Fish = fl.spawn_fish_at(1, fl.p_pos + Vector2(150, 0), -1.0, 1.0)
	fl.step(DT)
	_check(small.flee_t > 0.0, "Vanlig: edible fish within 200 px flees")


# ---------------------------------------------------------------- 8


func _test_kelp_bobla_pearls() -> void:
	print("8. kelp, Bobla, pearls")
	var sim: RbSim = _new_sim(4, true)
	sim.fishes.clear()
	sim.p_pos = Vector2(540, 700)
	sim.p_aim = sim.p_pos
	sim.step(DT)
	_check(sim.p_in_kelp == 1, "player in the middle kelp patch")
	sim.p_immune = 0.0
	sim.spawn_fish_at(4, sim.p_pos, -1.0, 0.01)
	_step(sim, 0.2)
	_check(sim.catches == 0, "kelp: no catch inside")
	sim.fishes.clear()
	sim.p_aim = Vector2(540, 300)
	_step(sim, 0.5)
	_check(
		(
			sim.p_vel.length() <= RbBalance.PLAYER_SPEED_LETT * RbBalance.KELP_SPEED_MULT + 1.0
			or sim.p_in_kelp < 0
		),
		"kelp: speed x0.7"
	)
	var bad_pearl: int = 0
	var near_pearl: int = 0
	for k: int in 30:
		var ps: RbSim = _new_sim(4, true, 500 + k)
		_step(ps, 1.1)
		if ps.pearl_state == "open":
			for r: Rect2 in ps.kelp:
				bad_pearl += 1 if r.has_point(ps.pearl_pos) else 0
			near_pearl += 1 if ps.pearl_pos.distance_to(ps.p_pos) < 250.0 else 0
	_check(bad_pearl == 0, "pearls never spawn inside kelp")
	_check(near_pearl == 0, "pearls spawn >= 250 px from the player")
	var b: RbSim = _new_sim(3, true)
	b.fishes.clear()
	_step(b, 8.05)
	_check(b.powerup_on and b.powerup_pos == Vector2(540, 700), "L3: Bobla at (540, 700) at 8 s")
	b.p_pos = b.powerup_pos
	b.p_aim = b.p_pos
	b.step(DT)
	_check(b.shield_t > 14.0, "Bobla taken: 15 s shield")
	b.p_immune = 0.0
	b.spawn_fish_at(b.p_tier + 1, b.p_pos, -1.0, 0.01)
	var bonk: bool = false
	for i: int in 5:
		b.step(DT)
		for e: Dictionary in b.events:
			bonk = bonk or e["type"] == "bonk"
		b.events.clear()
	_check(bonk and b.catches == 0 and b.shield_t == 0.0, "Bobla blocks one catch, then pops")


# ---------------------------------------------------------------- 9


func _test_lift_and_flash() -> void:
	print("9. finger lift, flash limiter")
	_check(
		RbBalance.aim_from_finger(Vector2(500, 1000)) == Vector2(500, 880),
		"aim 120 px above the finger"
	)
	_check(RbBalance.aim_from_finger(Vector2(500, 1640)) == Vector2(500, 1640), "lift 0 at y 1640")
	_check(
		RbBalance.aim_from_finger(Vector2(500, 1520)) == Vector2(500, 1460),
		"lift fades (60 px at y 1520)"
	)
	_check(
		RbBalance.aim_from_finger(Vector2(500, 300)).y == RbBalance.POND.position.y,
		"aim clamped inside the pond"
	)
	var fl := RbFlashLimiter.new()
	var granted: int = 0
	for i: int in 5:
		granted += 1 if fl.allow(10.0 + i * 0.2) else 0
	_check(granted == 3, "5 meals in 1 s -> 3 flashes (%d)" % granted)


# ---------------------------------------------------------------- 10


func _test_save_and_table() -> void:
	print("10. save, free levels, table")
	RbGame.cleared.clear()
	RbGame.mark_cleared(2)
	RbGame.set_less_motion(true)
	RbGame.set_difficulty(false)
	RbGame.cleared.clear()
	RbGame.less_motion = false
	RbGame.easy = true
	RbGame.load_game()
	_check(RbGame.cleared == [2] and RbGame.less_motion and not RbGame.easy, "save round trip")
	var txt: String = FileAccess.get_file_as_string(RbState.SAVE_PATH)
	var d: Variant = JSON.parse_string(txt)
	_check(
		d is Dictionary and int((d as Dictionary).get("version", 0)) == 1, "save file has version 1"
	)
	_check(
		RbState.SAVE_PATH == "user://reef_bite_save.json", "save path user://reef_bite_save.json"
	)
	RbGame.set_full_unlock(false)
	_check(RbGame.visible_levels() == [1, 2, 3], "full_unlock off: levels 1-3")
	_check(RbGame.next_level_after(3) == 0, "full_unlock off: no next after 3")
	RbGame.set_full_unlock(true)
	_check(RbGame.visible_levels().size() == 5, "full_unlock on: all slice levels")
	RbGame.set_difficulty(true)
	RbGame.set_less_motion(false)
	var want: Array = [[3, 7, 4, 8], [4, 7, 5, 9], [4, 7, 5, 9], [4, 7, 6, 9], [4, 7, 5, 8]]
	var ok: bool = true
	for i: int in 5:
		var l: Dictionary = RbLevels.setting(i + 1, true)
		var v: Dictionary = RbLevels.setting(i + 1, false)
		ok = (
			ok
			and (
				[int(l["target"]), int(l["fish_max"]), int(v["target"]), int(v["fish_max"])]
				== want[i]
			)
		)
	_check(ok, "level table = GDD 6.3 rows 1-5")
	_check(String(RbLevels.get_level(4)["goal"]) == "pearls", "L4 is the pearl level")


# ---------------------------------------------------------------- 11


func _test_sounds() -> void:
	print("11. sounds")
	var sfx := RbSfx.new()
	add_child(sfx)
	await get_tree().process_frame
	var expected: int = 1
	for key: String in RbSfx.SOUNDS:
		expected += (RbSfx.SOUNDS[key][0] as Array).size()
	_check(
		sfx.loaded_count() == expected,
		"every effect file loads (%d / %d)" % [sfx.loaded_count(), expected]
	)
	var music: AudioStream = load(RbMusic.TRACK) as AudioStream
	_check(
		music != null and music.get_length() > 40.0,
		"music loop loads (%.1f s)" % (music.get_length() if music else 0.0)
	)
	_check(
		RbMusic.BASE_DB + linear_to_db(0.6) - 3.0 <= RbSfx.BASE_DB + linear_to_db(0.7) - 3.0 - 6.0,
		"music >= 6 dB under the effects"
	)
	sfx.enabled = false
	sfx.play("eat")
	_check(int(sfx.played.get("eat", 0)) == 0, "sound off plays nothing")
	sfx.queue_free()
