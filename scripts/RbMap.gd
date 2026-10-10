class_name RbMap
extends Control

## World map page (GDD 8.1): world 1 "Tareskogen" behind (the 3D scene with
## the gameplay layer hidden), 5 level discs (diameter 200, hit area 240) on
## a path of bubbles between y 400 and 1500, never in the top-left 232
## square or below y 1664. Cleared = gold star; the lowest uncleared level
## pulses at 1 Hz (never a flash). No text, nothing locked: with
## full_unlock off only levels 1-3 are drawn. Stand-alone only: gear disc
## top-right opens settings.

signal level_chosen(level_id: int)
signal settings_pressed

const SPOTS: Array[Vector2] = [
	Vector2(300, 1420), Vector2(730, 1220), Vector2(330, 980), Vector2(740, 740), Vector2(420, 500)
]
const GEAR_HIT: float = 216.0

var less_motion: bool = false
var gear: RbDisc
var discs: Array[RbLevelDisc] = []
var _t: float = 0.0


func _ready() -> void:
	size = Vector2(RbBalance.DESIGN_W, RbBalance.DESIGN_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in RbLevels.count():
		var d := RbLevelDisc.new()
		d.level_id = i + 1
		d.disc_radius = 100.0
		d.size = Vector2(240, 240)
		d.position = SPOTS[i] - d.size * 0.5
		var id: int = i + 1
		d.tapped.connect(func() -> void: level_chosen.emit(id))
		add_child(d)
		discs.append(d)
	gear = RbDisc.new()
	gear.icon = "gear"
	gear.disc_radius = 60.0
	gear.ring_px = 5.0
	gear.size = Vector2(GEAR_HIT, GEAR_HIT)
	gear.position = Vector2(RbBalance.DESIGN_W - GEAR_HIT, 0.0)
	gear.disc_center = Vector2(GEAR_HIT - 104.0, 104.0)
	gear.tapped.connect(func() -> void: settings_pressed.emit())
	add_child(gear)


func refresh() -> void:
	var visible_ids: Array[int] = RbGame.visible_levels()
	var sug: int = RbGame.suggested_level()
	for d: RbLevelDisc in discs:
		d.visible = visible_ids.has(d.level_id)
		d.cleared = RbGame.is_cleared(d.level_id)
		d.suggested = d.level_id == sug
		d.less_motion = less_motion
		d.queue_redraw()
	queue_redraw()


## Camera cutout: the gear moves down with the home disc; its touch area
## still reaches the screen corner.
func set_safe_dy(dy: float) -> void:
	gear.size = Vector2(GEAR_HIT, GEAR_HIT + dy)
	gear.disc_center = Vector2(GEAR_HIT - 104.0, 104.0 + dy)
	gear.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if visible and not less_motion:
		queue_redraw()


func _draw() -> void:
	# Bubble path between the visible discs.
	var pts: Array[Vector2] = []
	for d: RbLevelDisc in discs:
		if d.visible:
			pts.append(SPOTS[d.level_id - 1])
	for i: int in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n: int = 7
		for k: int in range(1, n):
			var f: float = float(k) / float(n)
			var p: Vector2 = (
				a.lerp(b, f) + Vector2(sin(f * PI) * 40.0 * (1.0 if i % 2 == 0 else -1.0), 0.0)
			)
			var bob: float = 0.0 if less_motion else sin(_t * 1.6 + float(k + i * 3)) * 3.0
			var r: float = 9.0 + 4.0 * sin(f * PI)
			p.y += bob
			draw_arc(p, r, 0.0, TAU, 16, Color(1, 1, 1, 0.85), 3.0, true)
