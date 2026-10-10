class_name RbHand
extends Control

## Onboarding and idle-hint hand (GDD 8.3): a white hand with an ink
## outline whose index fingertip sits at `tip` (design px). `press` 0..1
## squeezes it toward the screen. Not tappable.

const INK := Color(0.078, 0.094, 0.110)
const WHITE := Color(1.0, 1.0, 1.0)

var tip: Vector2 = Vector2(540, 960)
var press: float = 0.0
var alpha: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(RbBalance.DESIGN_W, RbBalance.DESIGN_H)


func _draw() -> void:
	if alpha <= 0.01:
		return
	var s: float = 1.0 - 0.1 * press
	var o: Vector2 = tip
	var xf := Transform2D(deg_to_rad(-18.0), Vector2(s, s), 0.0, o)
	draw_set_transform_matrix(xf)
	var fill := Color(WHITE, alpha)
	var line := Color(INK, alpha)
	# Index finger (pointing up), then the fist below it.
	var finger := Rect2(-20, 0, 40, 120)
	var fist := Rect2(-34, 96, 118, 118)
	var thumb := Rect2(-62, 128, 46, 74)
	for r: Rect2 in [thumb, fist, finger]:
		_round_rect(r, 20.0, fill, line)
	for i: int in 3:
		draw_line(Vector2(22 + i * 22, 100), Vector2(22 + i * 22, 132), line, 4.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if press > 0.5:
		draw_arc(o, 26.0 + 14.0 * press, 0.0, TAU, 32, Color(WHITE, alpha * 0.8), 4.0, true)


func _round_rect(r: Rect2, rad: float, fill: Color, line: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = line
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
