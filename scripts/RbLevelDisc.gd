class_name RbLevelDisc
extends RbDisc

## Map level disc (GDD 8.1): white glass disc with an ink ring; inside, the
## level's place in the world as ink pips (1-5, a shape cue, no digits) and
## a small fish or pearl showing the goal; cleared = gold star at the
## top-right; the suggested level gets a gold ring pulsing at 1 Hz between
## 60% and 100% (never a flash).

## A baked disc draws nothing itself: RbMap paints it into its cached
## layer (one texture, QA 2026-10-10 finding 6) and draws the pulse ring
## live. look_changed asks the map to re-render the layer.
signal look_changed

const GOLD := Color(0.961, 0.753, 0.0)

var level_id: int = 1
var cleared: bool = false
var suggested: bool = false
var less_motion: bool = false
var baked: bool = false
var _pulse_t: float = 0.0
var _shown_pressed: bool = false


func _ready() -> void:
	super._ready()
	set_process(not baked)


func _process(delta: float) -> void:
	_press_t += delta
	_pulse_t += delta
	if not baked:
		queue_redraw()
		return
	var pressed: bool = _down or _press_t < 0.1
	if pressed != _shown_pressed:
		_shown_pressed = pressed
		look_changed.emit()
	if not pressed and not _down:
		set_process(false)


func _draw() -> void:
	if not baked:
		paint(self, Vector2.ZERO, true)


## Gold ring of the suggested level, pulsing at 1 Hz (60-100%).
func paint_pulse(ci: CanvasItem, origin: Vector2, t: float) -> void:
	if not suggested:
		return
	var a: float = 0.8 if less_motion else 0.8 + 0.2 * sin(t * TAU)
	ci.draw_arc(origin + center(), disc_radius + 12.0, 0.0, TAU, 64, Color(GOLD, a), 12.0, true)


## Draws the disc onto `ci` with its control origin at `origin`.
func paint(ci: CanvasItem, origin: Vector2, with_pulse: bool) -> void:
	var pressed: bool = _down or _press_t < 0.1
	var k: float = 0.94 if pressed else 1.0
	var c: Vector2 = origin + center()
	var r: float = disc_radius * k
	ci.draw_circle(c, r + 12.0, Color(1, 1, 1, 0.16))
	ci.draw_circle(c, r, GREEN_SOFT if pressed else WHITE)
	if with_pulse:
		paint_pulse(ci, origin, _pulse_t)
	ci.draw_arc(c, r - 3.0, 0.0, TAU, 64, INK, 6.0, true)
	var lv: Dictionary = RbLevels.get_level(level_id)
	if String(lv.get("goal", "grow")) == "pearls":
		var pc: Vector2 = c + Vector2(0, -18)
		ci.draw_circle(pc, 30.0, Color(0.93, 0.93, 0.95))
		ci.draw_arc(pc, 30.0, 0.0, TAU, 40, INK, 5.0, true)
		ci.draw_circle(pc + Vector2(-10, -10), 7.0, WHITE)
	else:
		var fp: PackedVector2Array = RbDisc.fish_points(c + Vector2(4, -18), 100.0)
		ci.draw_colored_polygon(fp, GOLD)
		fp.append(fp[0])
		ci.draw_polyline(fp, INK, 5.0, true)
		ci.draw_circle(RbDisc.fish_eye(c + Vector2(4, -18), 100.0), 5.0, INK)
	var n: int = level_id
	var gap: float = 26.0
	var x0: float = c.x - gap * float(n - 1) * 0.5
	for i: int in n:
		ci.draw_circle(Vector2(x0 + gap * float(i), c.y + 48.0), 9.0, INK)
	if cleared:
		var sc: Vector2 = c + Vector2(r * 0.72, -r * 0.72)
		var pts: PackedVector2Array = RbDisc.star_points(sc, 44.0, 20.0)
		ci.draw_colored_polygon(pts, GOLD)
		pts.append(pts[0])
		ci.draw_polyline(pts, INK, 5.0, true)
