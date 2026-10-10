class_name RbWinCard
extends Control

## Win card (GDD 8.4, DESIGN 7, wincard_mock.png): the scene blurred and
## dimmed behind a light card; a picture window where a second camera looks
## at the player swimming its slow loop in the real world; the level's tier
## row (all white, goal gold); one big star landing; three icon discs:
## replay, map, gold next. No text. Never auto-advances.

signal replay_pressed
signal map_pressed
signal next_pressed

const CARD := Color(0.957, 0.973, 0.965)
const CARD_EDGE := Color(0.369, 0.498, 0.525)
const GOLD := Color(0.961, 0.753, 0.0)
const INK := Color(0.078, 0.094, 0.110)
const WHITE := Color(1.0, 1.0, 1.0)
const CARD_RECT := Rect2(100, 330, 880, 1140)
const PIC_RECT := Rect2(150, 380, 780, 560)
const ROW_Y: float = 1040.0
const STAR_C := Vector2(540, 1160)
const DISC_Y: float = 1340.0
const FADE_S: float = 0.25

var less_motion: bool = false
var goal_tier: int = 3
var start_tier: int = 2
var pearl_goal: bool = false
var pic_camera: Camera3D
var _t: float = 0.0
var _replay: RbDisc
var _map: RbDisc
var _next: RbDisc
var _backdrop: ColorRect
var _pic: TextureRect
var _viewport: SubViewport
var _card_box: StyleBoxFlat
var _overlay: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(RbBalance.DESIGN_W, RbBalance.DESIGN_H)
	_backdrop = ColorRect.new()
	_backdrop.position = Vector2(-2000, -2000)
	_backdrop.size = Vector2(6000, 6000)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bm := ShaderMaterial.new()
	bm.shader = load("res://shaders/rb_blur_dim.gdshader")
	bm.set_shader_parameter("dim", 0.47)
	_backdrop.material = bm
	add_child(_backdrop)
	_card_box = StyleBoxFlat.new()
	_card_box.bg_color = CARD
	_card_box.border_color = CARD_EDGE
	_card_box.set_border_width_all(4)
	_card_box.set_corner_radius_all(56)
	_card_box.anti_aliasing = true
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = size
	card.draw.connect(func() -> void: card.draw_style_box(_card_box, CARD_RECT))
	add_child(card)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(PIC_RECT.size.x), int(PIC_RECT.size.y))
	_viewport.own_world_3d = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	pic_camera = Camera3D.new()
	pic_camera.fov = 34.0
	pic_camera.far = 60.0
	_viewport.add_child(pic_camera)
	_pic = TextureRect.new()
	_pic.position = PIC_RECT.position
	_pic.size = PIC_RECT.size
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_SCALE
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.texture = _viewport.get_texture()
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/rb_picture_frame.gdshader")
	pm.set_shader_parameter("size_px", PIC_RECT.size)
	_pic.material = pm
	add_child(_pic)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = size
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_replay = _disc("replay", Vector2(270, DISC_Y), 100.0, RbDisc.WHITE)
	_map = _disc("map", Vector2(540, DISC_Y), 100.0, RbDisc.WHITE)
	_next = _disc("next", Vector2(810, DISC_Y), 120.0, RbDisc.NEXT)
	_replay.tapped.connect(func() -> void: replay_pressed.emit())
	_map.tapped.connect(func() -> void: map_pressed.emit())
	_next.tapped.connect(func() -> void: next_pressed.emit())
	visible = false
	set_process(false)


func _disc(icon_name: String, c: Vector2, r: float, f: Color) -> RbDisc:
	var d := RbDisc.new()
	d.icon = icon_name
	d.disc_radius = r
	d.fill = f
	var hit: float = maxf(r * 2.0 + 20.0, 240.0)
	d.position = c - Vector2(hit, hit) * 0.5
	d.size = Vector2(hit, hit)
	add_child(d)
	return d


func show_card(has_next: bool, goal: int, is_pearls: bool) -> void:
	goal_tier = goal
	pearl_goal = is_pearls
	_next.visible = has_next
	var replay_x: float = 270.0 if has_next else 360.0
	var map_x: float = 540.0 if has_next else 720.0
	_place(_replay, replay_x)
	_place(_map, map_x)
	_place(_next, 810.0)
	_t = 0.0
	visible = true
	modulate.a = 1.0 if less_motion else 0.0
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	set_process(true)


func hide_card() -> void:
	visible = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)


func has_next() -> bool:
	return _next.visible


func _place(d: RbDisc, x: float) -> void:
	d.position.x = x - d.size.x * 0.5
	d.queue_redraw()


## Points the picture camera at the player (world position, length m).
func frame_player(at: Vector3, length_m: float) -> void:
	var dist: float = clampf(length_m * 3.6, 1.6, 6.0)
	pic_camera.position = at + Vector3(0.0, 0.05, dist)
	pic_camera.look_at(at, Vector3.UP)


func _process(delta: float) -> void:
	_t += delta
	if not less_motion:
		modulate.a = clampf(_t / FADE_S, 0.0, 1.0)
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	# Tier row: the level's silhouettes, all white, goal one gold.
	var tiers: Array[int] = []
	if pearl_goal:
		tiers = [goal_tier]
	else:
		for t: int in range(start_tier, goal_tier + 1):
			tiers.append(t)
	var lens: Array[float] = []
	var total: float = 0.0
	for t: int in tiers:
		var l: float = 150.0 / pow(RbBalance.TIER_STEP, float(goal_tier - t))
		lens.append(l)
		total += l * 1.22 + 40.0
	total -= 40.0
	var x: float = 540.0 - total * 0.5
	for i: int in tiers.size():
		var l: float = lens[i]
		var c := Vector2(x + l * 0.61 + l * 0.06, ROW_Y)
		var pts: PackedVector2Array = RbDisc.fish_points(c, l)
		var last: bool = i == tiers.size() - 1
		_overlay.draw_colored_polygon(pts, GOLD if last else WHITE)
		var closed := pts.duplicate()
		closed.append(pts[0])
		_overlay.draw_polyline(closed, INK, 4.0, true)
		_overlay.draw_circle(RbDisc.fish_eye(c, l), maxf(3.0, l * 0.04), INK)
		x += l * 1.22 + 40.0
	# Star lands 0.6 -> 1.08 -> 1.0 in 300 ms (DESIGN 7).
	var k: float = clampf((_t - 0.15) / 0.3, 0.0, 1.0)
	var sc: float = 1.0
	if not less_motion:
		if _t < 0.15:
			return
		sc = lerpf(0.6, 1.08, k / 0.7) if k < 0.7 else lerpf(1.08, 1.0, (k - 0.7) / 0.3)
	var outer: float = 62.0 * sc
	var sp: PackedVector2Array = RbDisc.star_points(STAR_C, outer, outer * 0.46)
	_overlay.draw_colored_polygon(sp, GOLD)
	sp.append(sp[0])
	_overlay.draw_polyline(sp, INK, 8.0, true)
