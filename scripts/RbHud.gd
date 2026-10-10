class_name RbHud
extends Control

## Goal meter (GDD 8.2, DESIGN 6): x 256-1044, y 40-224, not tappable, no
## text. Vokse: one player silhouette per tier from 2 to the goal, each at
## its relative size; reached = white, current = glass with gold filling
## tail to nose, future = hollow, goal = gold star. Perler: N pearl slots and
## a small current-tier dot row. Vanlig with limited bobler: 3 bubble icons
## at the right end.

const INK := Color(0.078, 0.094, 0.110)
const WHITE := Color(1.0, 1.0, 1.0)
const GOLD := Color(0.961, 0.753, 0.0)
const HUD_GLASS := Color(0.031, 0.149, 0.180, 0.78)
const HUD_EDGE := Color(0.886, 0.941, 0.933)
const PANEL := Rect2(256, 52, 788, 152)
const ROW_Y: float = 128.0
const GOAL_LEN: float = 150.0
const GAP: float = 34.0

var goal: String = "grow"
var start_tier: int = 2
var goal_tier: int = 3
var tier: int = 2
var meter_target: float = 0.0
var pearls_total: int = 0
var pearls: int = 0
## -1 = unlimited (no icons).
var bobler: int = -1
var bobler_max: int = -1
var less_motion: bool = false
var _meter: float = 0.0
var _shimmer_tier: int = -1
var _shimmer_t: float = 99.0
var _pop_t: float = 99.0
var _box: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(RbBalance.DESIGN_W, 260.0)
	_box = StyleBoxFlat.new()
	_box.bg_color = HUD_GLASS
	_box.border_color = HUD_EDGE
	_box.set_border_width_all(4)
	_box.set_corner_radius_all(76)
	_box.anti_aliasing = true


func setup(goal_kind: String, target: int, bob: int) -> void:
	goal = goal_kind
	start_tier = RbBalance.PLAYER_START_TIER
	goal_tier = target if goal_kind == "grow" else start_tier
	pearls_total = target if goal_kind == "pearls" else 0
	pearls = 0
	bobler = bob
	bobler_max = bob
	tier = start_tier
	_meter = 0.0
	meter_target = 0.0
	_shimmer_t = 99.0
	queue_redraw()


func set_state(new_tier: int, meter: float, pearl_n: int, bob: int) -> void:
	if new_tier > tier:
		_shimmer_tier = tier
		_shimmer_t = 0.0
		_meter = 0.0
	elif new_tier < tier:
		_meter = 0.0
	tier = new_tier
	meter_target = meter
	pearls = pearl_n
	if bob < bobler and bob >= 0:
		_pop_t = 0.0
	bobler = bob


func _process(delta: float) -> void:
	if less_motion:
		_meter = meter_target
	else:
		_meter = move_toward(_meter, meter_target, delta / 0.2)
	_shimmer_t += delta
	_pop_t += delta
	queue_redraw()


func _draw() -> void:
	draw_style_box(_box, PANEL)
	var limited: bool = bobler_max > 0
	var x0: float = 280.0 if limited else PANEL.position.x + 30.0
	var x1: float = 880.0 if limited else PANEL.end.x - 30.0
	if goal == "pearls":
		_draw_pearls(x0, x1)
	else:
		_draw_row(x0, x1)
	if limited:
		_draw_bobler()


func _len_for(t: int) -> float:
	return GOAL_LEN / pow(RbBalance.TIER_STEP, float(goal_tier - t))


func _draw_row(x0: float, x1: float) -> void:
	var total: float = 0.0
	for t: int in range(start_tier, goal_tier + 1):
		total += _len_for(t) * 1.22
	total += GAP * float(goal_tier - start_tier)
	var scale_k: float = minf(1.0, (x1 - x0) / total)
	var x: float = (x0 + x1) * 0.5 - total * scale_k * 0.5
	for t: int in range(start_tier, goal_tier + 1):
		var l: float = _len_for(t) * scale_k
		var w: float = l * 1.22
		var c := Vector2(x + w * 0.5 + l * 0.06, ROW_Y)
		_draw_silhouette(c, l, t)
		if t == goal_tier:
			var sc: Vector2 = c + Vector2(l * 0.42, -l * 0.36)
			var sp: PackedVector2Array = RbDisc.star_points(sc, 28.0, 12.0)
			draw_colored_polygon(sp, GOLD)
			sp.append(sp[0])
			draw_polyline(sp, INK, 5.0, true)
		x += w + GAP * scale_k


func _draw_silhouette(c: Vector2, l: float, t: int) -> void:
	var pts: PackedVector2Array = RbDisc.fish_points(c, l)
	var closed := pts.duplicate()
	closed.append(pts[0])
	if t < tier or (t == tier and t == goal_tier and tier >= goal_tier):
		draw_colored_polygon(pts, WHITE)
		if t == _shimmer_tier and _shimmer_t < 0.3 and not less_motion:
			var k: float = _shimmer_t / 0.3
			draw_colored_polygon(pts, Color(GOLD, 0.5 * (1.0 - k)))
		draw_polyline(closed, INK, 4.0, true)
		draw_circle(RbDisc.fish_eye(c, l), maxf(2.5, l * 0.04), INK)
	elif t == tier:
		draw_colored_polygon(pts, HUD_GLASS)
		if _meter > 0.001:
			var tail_x: float = c.x - l * 0.5 - l * 0.22
			var fill_x: float = tail_x + (l * 1.22) * _meter
			var rect := PackedVector2Array(
				[
					Vector2(tail_x - 4.0, c.y - l),
					Vector2(fill_x, c.y - l),
					Vector2(fill_x, c.y + l),
					Vector2(tail_x - 4.0, c.y + l)
				]
			)
			for poly: PackedVector2Array in Geometry2D.intersect_polygons(pts, rect):
				draw_colored_polygon(poly, GOLD)
				var pc := poly.duplicate()
				pc.append(poly[0])
				draw_polyline(pc, INK, 3.0, true)
		# hud_edge outline: the hollow part must read on the dark panel.
		draw_polyline(closed, HUD_EDGE, 4.0, true)
		draw_circle(RbDisc.fish_eye(c, l), maxf(2.5, l * 0.04), HUD_EDGE if _meter < 0.8 else INK)
	else:
		draw_colored_polygon(pts, HUD_GLASS)
		draw_polyline(closed, HUD_EDGE, 4.0, true)


func _draw_pearls(x0: float, x1: float) -> void:
	var n: int = maxi(pearls_total, 1)
	var r: float = minf(34.0, (x1 - x0) / float(n) * 0.36)
	var step: float = (x1 - x0) / float(n)
	for i: int in n:
		var c := Vector2(x0 + step * (float(i) + 0.5), 112.0)
		if i < pearls:
			draw_circle(c, r, WHITE)
			draw_arc(c, r, 0.0, TAU, 40, INK, 4.0, true)
			draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.22, Color(1, 1, 1))
			draw_arc(c, r * 0.72, PI * 0.9, PI * 1.4, 12, Color(0.75, 0.78, 0.8), 3.0, true)
		else:
			draw_circle(c, r, HUD_GLASS)
			draw_arc(c, r - 2.0, 0.0, TAU, 40, HUD_EDGE, 4.0, true)
	# Current tier as a dot row under the slots (tiers 2..cap).
	var cap: int = RbBalance.PEARL_LEVEL_TIER_CAP
	var dots: int = cap - start_tier + 1
	var dx: float = 30.0
	var sx: float = (x0 + x1) * 0.5 - dx * float(dots - 1) * 0.5
	for i: int in dots:
		var t: int = start_tier + i
		var c2 := Vector2(sx + dx * float(i), 176.0)
		if t <= tier:
			draw_circle(c2, 9.0, GOLD if t == tier else WHITE)
			draw_arc(c2, 9.0, 0.0, TAU, 20, INK, 2.5, true)
		else:
			draw_arc(c2, 8.0, 0.0, TAU, 20, HUD_EDGE, 3.0, true)


func _draw_bobler() -> void:
	for i: int in bobler_max:
		var c := Vector2(922.0 + float(i) * 48.0, 188.0)
		if i < bobler:
			draw_circle(c, 20.0, Color(1, 1, 1, 0.22))
			draw_arc(c, 20.0, 0.0, TAU, 32, WHITE, 3.5, true)
			draw_arc(c, 22.5, 0.0, TAU, 32, Color(INK, 0.35), 2.0, true)
			draw_circle(c + Vector2(-7, -7), 4.0, WHITE)
		elif i == bobler and _pop_t < 0.3 and not less_motion:
			# One burst when a bubble pops (single, not a strobe).
			var k: float = _pop_t / 0.3
			for j: int in 8:
				var a: float = TAU * float(j) / 8.0
				draw_circle(c + Vector2(cos(a), sin(a)) * (12.0 + 18.0 * k), 3.0 * (1.0 - k), WHITE)
		else:
			draw_arc(c, 18.0, 0.0, TAU, 32, Color(HUD_EDGE, 0.4), 2.0, true)
