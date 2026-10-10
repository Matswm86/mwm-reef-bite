class_name RbSettings
extends Control

## Stand-alone settings panel (GDD 10.2), adult-facing, opened from the gear
## on the map: Lett / Vanlig, sound on/off + volume, music
## (note icon) on/off + volume, "Mindre bevegelse". Fredoka (SIL OFL), ink on
## card. Difficulty takes effect from the next level start.

signal closed
## The effects slider was let go: the host plays one sample at the new level.
signal sfx_preview

const CARD := Color(0.957, 0.973, 0.965)
const CARD_EDGE := Color(0.369, 0.498, 0.525)
const INK := Color(0.078, 0.094, 0.110)
const ON := Color(0.961, 0.753, 0.000)
const OFF := Color(1.0, 1.0, 1.0)
const DIM := Color(0.0, 0.0, 0.0, 0.55)
const PANEL := Rect2(90, 380, 900, 1240)
const MUSIC_ICON_AT := Vector2(205, 1120)
const TRACK := Color(0.800, 0.870, 0.860)
const KNOB_PX: int = 84

var _lett: Button
var _vanlig: Button
var _sound: Button
var _music: Button
var _motion: Button
var _sfx_slider: HSlider
var _music_slider: HSlider


func _ready() -> void:
	size = Vector2(RbBalance.DESIGN_W, RbBalance.DESIGN_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var th := Theme.new()
	th.default_font = load("res://assets/fonts/Fredoka.ttf")
	th.default_font_size = 44
	theme = th
	_heading("Innstillinger", Vector2(150, 420))
	var close := RbDisc.new()
	close.icon = "close"
	close.disc_radius = 60.0
	close.size = Vector2(160, 160)
	close.position = Vector2(PANEL.end.x - 170, PANEL.position.y + 10)
	close.tapped.connect(func() -> void: closed.emit())
	add_child(close)
	_label("Vanskelighet", Vector2(150, 560))
	_lett = _button("Lett", Rect2(150, 620, 360, 140))
	_vanlig = _button("Vanlig", Rect2(570, 620, 360, 140))
	_lett.pressed.connect(func() -> void: _set_easy(true))
	_vanlig.pressed.connect(func() -> void: _set_easy(false))
	_label("Lyd", Vector2(150, 820))
	_sound = _button("", Rect2(570, 780, 360, 140))
	_sound.pressed.connect(
		func() -> void:
			RbGame.set_sfx_on(not RbGame.sfx_on)
			refresh()
	)
	# Music row: a note icon instead of a word (drawn in _draw).
	_sfx_slider = _slider(Rect2(150, 930, 780, 100))
	_sfx_slider.value_changed.connect(func(v: float) -> void: RbGame.set_sfx_volume(v, false))
	_sfx_slider.drag_ended.connect(
		func(_changed: bool) -> void:
			RbGame.save_game()
			sfx_preview.emit()
	)
	_music = _button("", Rect2(570, 1050, 360, 140))
	_music.pressed.connect(
		func() -> void:
			RbGame.set_music_on(not RbGame.music_on)
			refresh()
	)
	_music_slider = _slider(Rect2(150, 1200, 780, 100))
	_music_slider.value_changed.connect(func(v: float) -> void: RbGame.set_music_volume(v, false))
	_music_slider.drag_ended.connect(func(_changed: bool) -> void: RbGame.save_game())
	_label("Mindre bevegelse", Vector2(150, 1380))
	_motion = _button("", Rect2(570, 1340, 360, 140))
	_motion.pressed.connect(
		func() -> void:
			RbGame.set_less_motion(not RbGame.less_motion)
			refresh()
	)
	var note := Label.new()
	note.text = "Vanskelighet gjelder fra neste bane."
	note.add_theme_font_size_override("font_size", 40)
	note.add_theme_color_override("font_color", INK)
	note.position = Vector2(150, 1515)
	add_child(note)
	visible = false


func open() -> void:
	refresh()
	visible = true


func refresh() -> void:
	_style(_lett, RbGame.easy)
	_style(_vanlig, not RbGame.easy)
	_sound.text = "På" if RbGame.sfx_on else "Av"
	_style(_sound, RbGame.sfx_on)
	_music.text = "På" if RbGame.music_on else "Av"
	_style(_music, RbGame.music_on)
	_motion.text = "På" if RbGame.less_motion else "Av"
	_style(_motion, RbGame.less_motion)
	_sfx_slider.set_value_no_signal(RbGame.sfx_volume)
	_music_slider.set_value_no_signal(RbGame.music_volume)


func _set_easy(on: bool) -> void:
	RbGame.set_difficulty(on)
	refresh()


func _heading(t: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 56)
	l.add_theme_color_override("font_color", INK)
	l.position = at
	add_child(l)


func _label(t: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", INK)
	l.position = at
	add_child(l)


func _button(t: String, r: Rect2) -> Button:
	var b := Button.new()
	b.text = t
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	add_child(b)
	return b


## Volume slider 0..1: thick track, gold fill, a large round knob so a
## thumb can grab it.
func _slider(r: Rect2) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.position = r.position
	s.size = r.size
	s.focus_mode = Control.FOCUS_NONE
	var track := StyleBoxFlat.new()
	track.bg_color = TRACK
	track.set_corner_radius_all(14)
	track.content_margin_top = 14.0
	track.content_margin_bottom = 14.0
	s.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ON
	fill.set_corner_radius_all(14)
	fill.content_margin_top = 14.0
	fill.content_margin_bottom = 14.0
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob: Texture2D = _knob()
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	add_child(s)
	return s


func _knob() -> Texture2D:
	var img := Image.create(KNOB_PX, KNOB_PX, false, Image.FORMAT_RGBA8)
	var c: float = KNOB_PX * 0.5
	for y: int in KNOB_PX:
		for x: int in KNOB_PX:
			var d: float = Vector2(x + 0.5 - c, y + 0.5 - c).length()
			var col: Color = Color(0, 0, 0, 0)
			if d <= c - 1.0:
				col = INK if d > c - 7.0 else OFF
			elif d <= c:
				col = Color(INK, c - d)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _style(b: Button, on: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = ON if on else OFF
		sb.border_color = INK
		sb.set_border_width_all(5)
		sb.set_corner_radius_all(70)
		sb.anti_aliasing = true
		b.add_theme_stylebox_override(state, sb)
	for c: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"
	]:
		b.add_theme_color_override(c, INK)


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), DIM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = CARD_EDGE
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(56)
	sb.anti_aliasing = true
	draw_style_box(sb, PANEL)
	RbDisc.draw_icon(self, "music", MUSIC_ICON_AT, 56.0, INK)
