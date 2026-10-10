class_name RbMain
extends Node

## Root of MWM Reef Bite: the 3D world, the UI layer, the world 1 map and
## the play controller. First ever launch opens level 1 directly (GDD 8.3);
## later launches open the map. Inside MWM Play (Engine meta
## "mwm_play_shell") the own home disc, gear and back handling are left to
## the shell. Three frames hold the UI: the HUD is top-anchored, cards and
## the map are centred.

const TOP_ROW_CLEAR: float = 36.0
const HOME_HIT: float = 216.0

## Test hook: a fake top safe-area inset in window px; < 0 = ask the display.
var fake_safe_top: float = -1.0
var screen: String = ""

var world: RbWorld
var sfx: RbSfx
var music: RbMusic
var ui: CanvasLayer
var screen_root: Control
var top_frame: Control
var center_frame: Control
var map: RbMap
var settings: RbSettings
var play: RbPlay
var home: RbHomeDisc


func _ready() -> void:
	world = RbWorld.new()
	add_child(world)
	sfx = RbSfx.new()
	add_child(sfx)
	music = RbMusic.new()
	add_child(music)
	sfx.stinger_started.connect(music.duck)
	RbDisc.tap_sound = func() -> void: sfx.play("tap")
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	screen_root = Control.new()
	screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(screen_root)
	center_frame = _frame()
	top_frame = _frame()
	map = RbMap.new()
	center_frame.add_child(map)
	map.level_chosen.connect(open_level)
	map.settings_pressed.connect(_open_settings)
	play = RbPlay.new()
	add_child(play)
	play.setup(world, sfx, music, top_frame, center_frame)
	play.map_requested.connect(open_map)
	play.level_started.connect(music.play_level)
	settings = RbSettings.new()
	center_frame.add_child(settings)
	settings.closed.connect(_close_settings)
	settings.sfx_preview.connect(func() -> void: sfx.play("pearl"))
	home = RbHomeDisc.new()
	home.icon = "home"
	home.disc_radius = 68.0
	home.ring_px = 5.0
	home.confirmed.connect(open_map)
	screen_root.add_child(home)
	RbGame.settings_changed.connect(_apply_settings)
	get_viewport().size_changed.connect(_layout)
	_apply_settings()
	_layout()
	if RbGame.first_launch:
		open_level(1)
	else:
		open_map()


## The static disc tap hook holds a lambda bound to this node; drop it before
## the node goes, or Godot frees it twice at exit.
func _exit_tree() -> void:
	RbDisc.tap_sound = Callable()
	RbFishCatalog.clear_cache()


func _frame() -> Control:
	var c := Control.new()
	c.size = Vector2(RbBalance.DESIGN_W, RbBalance.DESIGN_H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(c)
	return c


func _apply_settings() -> void:
	sfx.enabled = RbGame.sfx_on or RbGame.in_shell()
	sfx.volume = RbGame.sfx_volume
	music.set_enabled(RbGame.music_on)
	music.set_volume(RbGame.music_volume)
	world.set_less_motion(RbGame.less_motion)
	play.set_less_motion(RbGame.less_motion)
	map.less_motion = RbGame.less_motion
	var shell: bool = RbGame.in_shell()
	home.visible = screen == "play" and not shell
	map.gear.visible = not shell
	if screen == "play":
		sfx.set_ambience(true)


func _layout() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var x0: float = (vs.x - RbBalance.DESIGN_W) * 0.5
	top_frame.position = Vector2(x0, 0.0)
	center_frame.position = Vector2(x0, (vs.y - RbBalance.DESIGN_H) * 0.5)
	apply_safe_area()


## Home disc and gear move below a camera cutout; their touch areas still run
## to the screen corner (copied from ball-connect 7ad7d50 via Orb Fence).
func apply_safe_area() -> void:
	var dy: float = maxf(0.0, safe_top_inset() - TOP_ROW_CLEAR)
	home.position = Vector2.ZERO
	home.size = Vector2(HOME_HIT, HOME_HIT + dy)
	home.disc_center = Vector2(104.0, 104.0 + dy)
	home.queue_redraw()
	var vs: Vector2 = get_viewport().get_visible_rect().size
	top_frame.position = Vector2((vs.x - RbBalance.DESIGN_W) * 0.5, dy)
	map.set_safe_dy(dy)


## Depth of the top screen cutout in viewport px (0 on desktop and on phones
## without a cutout in the drawn area).
func safe_top_inset() -> float:
	var top_px: float = fake_safe_top
	if top_px < 0.0:
		if not OS.has_feature("mobile"):
			return 0.0
		top_px = float(DisplayServer.get_display_safe_area().position.y)
	var win: Vector2i = DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	return maxf(0.0, top_px * get_viewport().get_visible_rect().size.y / float(win.y))


func open_level(id: int) -> void:
	screen = "play"
	settings.visible = false
	map.visible = false
	play.start_level(id)
	_apply_settings()


func open_map() -> void:
	screen = "map"
	play.stop()
	world.show_gameplay(false)
	world.reset_zoom()
	music.play_map()
	map.refresh()
	map.visible = true
	settings.visible = false
	play.block_input(RbBalance.HOLDOVER_MS)
	_apply_settings()
	RbGame.save_game()


func _open_settings() -> void:
	if screen == "play":
		play.pause()
	settings.open()


## In a level, closing settings shows the big resume disc.
func _close_settings() -> void:
	settings.visible = false
	if screen == "play":
		play.show_resume()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			RbGame.save_game()
			if play:
				play.pause()
		NOTIFICATION_APPLICATION_RESUMED:
			if play:
				play.show_resume()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()


func _on_back() -> void:
	if RbGame.in_shell():
		return
	if settings.visible:
		_close_settings()
	elif screen == "play":
		if play.card_visible():
			open_map()
		else:
			home.press()
	else:
		RbGame.save_game()
		get_tree().quit()
