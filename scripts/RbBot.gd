class_name RbBot
extends RefCounted

## Test and demo bot: picks an aim point the way a careful player would.
## Keeps clear of bigger fish (steers away when one is close), otherwise
## swims to the hint target (pearl, Bobla bubble or the nearest edible fish
## on a safe path). Used by the headless logic test and the capture bot.

## Extra distance on top of a big fish's catch radius that makes the bot turn away.
const KEEP_OFF: float = 150.0


static func aim(sim: RbSim) -> Vector2:
	var p: Vector2 = sim.p_pos
	var away := Vector2.ZERO
	if sim.p_in_kelp < 0 and sim.shield_t <= 0.0:
		var pr: float = sim.player_r()
		for f: RbSim.Fish in sim.fishes:
			if f.tier <= sim.p_tier or f.leaving:
				continue
			var fr: float = RbBalance.body_r(f.tier)
			var lim: float = (fr * 0.8 + pr * 0.5) + KEEP_OFF
			var d: float = p.distance_to(f.pos)
			if d < lim and d > 0.1:
				away += (p - f.pos) / d * (lim - d) / lim
	if away.length() > 0.25 and sim.p_immune < 0.4:
		var a: Vector2 = p + away.normalized() * 260.0
		# Bounce off the pond walls instead of pinning against them.
		var pond: Rect2 = RbBalance.POND.grow(-80.0)
		if not pond.has_point(a):
			a = p + Vector2(away.y, -away.x).normalized() * 260.0
			if not pond.has_point(a):
				a = pond.get_center()
		return a
	return sim.hint_target()
